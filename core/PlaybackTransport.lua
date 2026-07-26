local TempoMap = require("core.TempoMap")

local PlaybackTransport = {}
PlaybackTransport.__index = PlaybackTransport

local DEFAULT_MIXTAPE = {
    volume = 1,
    beat0Offset = 0,
}

local function isPlaybackRate(value)
    return type(value) == "number"
        and value == value
        and value >= 0.25
        and value <= 4
end

function PlaybackTransport.new(options)
    options = options or {}
    if type(options.musicPlayback) ~= "table" then
        return nil, "Music playback is required."
    end

    local tempoMap, errorMessage = TempoMap.new(options.bpm)
    if not tempoMap then return nil, errorMessage end

    return setmetatable({
        tempoMap = tempoMap,
        musicPlayback = options.musicPlayback,
        mixtape = DEFAULT_MIXTAPE,
        resolvedMusicPath = nil,
        timelineSeconds = 0,
        playbackRate = 1,
        playing = false,
        musicStarted = false,
        musicFinished = false,
    }, PlaybackTransport), nil
end

function PlaybackTransport:configureMixtape(settings, resolvedMusicPath)
    if self.playing then
        return nil, "Cannot configure mixtape while playback is running."
    end

    self.mixtape = settings or DEFAULT_MIXTAPE
    self.resolvedMusicPath = resolvedMusicPath
    self.musicStarted = false
    self.musicFinished = false
    return true, nil
end

function PlaybackTransport:setBpm(bpm)
    local savedBeat = self:getBeat()
    local tempoMap, errorMessage = TempoMap.new(bpm)
    if not tempoMap then return nil, errorMessage end

    local timelineSeconds, secondsError = tempoMap:beatToSeconds(savedBeat)
    if not timelineSeconds then return nil, secondsError end

    self.tempoMap = tempoMap
    self.timelineSeconds = timelineSeconds

    if not self.playing then return true, nil end

    local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset
    if musicSeconds >= 0 then
        local started, startError, finished, duration = self.musicPlayback:play(
            musicSeconds,
            self.playbackRate
        )
        if not started then
            self:pause()
            return nil, startError
        end
        self.musicStarted = not finished
        self.musicFinished = finished == true
        if finished and duration then
            self.timelineSeconds = math.max(0, duration - self.mixtape.beat0Offset)
        end
    else
        self.musicStarted = false
        local paused, pauseError = self.musicPlayback:pause()
        if not paused then
            self.playing = false
            return nil, pauseError
        end
    end

    return true, nil
end

function PlaybackTransport:play(playbackRate)
    playbackRate = playbackRate or 1
    if not isPlaybackRate(playbackRate) then
        return nil, "Playback rate must be between 0.25 and 4."
    end

    local prepared, prepareError = self.musicPlayback:prepare(
        self.resolvedMusicPath,
        self.mixtape.volume
    )
    if not prepared then
        self:pause()
        return nil, prepareError
    end

    self.playbackRate = playbackRate
    self.musicStarted = false
    self.musicFinished = false
    local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset
    if musicSeconds >= 0 then
        local started, startError, finished, duration = self.musicPlayback:play(
            musicSeconds,
            playbackRate
        )
        if not started then
            self:pause()
            return nil, startError
        end
        self.musicStarted = not finished
        self.musicFinished = finished == true
        if finished and duration then
            self.timelineSeconds = math.max(0, duration - self.mixtape.beat0Offset)
        end
    end

    self.playing = true
    return true, nil
end

function PlaybackTransport:pause()
    self.playing = false
    self.musicStarted = false
    return self.musicPlayback:pause()
end

function PlaybackTransport:seekBeat(beat)
    if self.playing then
        return nil, "Cannot seek while playback is running."
    end

    local timelineSeconds, errorMessage = self.tempoMap:beatToSeconds(beat)
    if not timelineSeconds then return nil, errorMessage end

    self.timelineSeconds = timelineSeconds
    self.musicStarted = false
    self.musicFinished = false
    return true, nil
end

function PlaybackTransport:update(deltaTime)
    if not self.playing then return true, nil end

    local previousTimelineSeconds = self.timelineSeconds
    self.timelineSeconds = self.timelineSeconds + deltaTime * self.playbackRate
    local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset

    if not self.musicStarted and not self.musicFinished and musicSeconds >= 0 then
        local started, startError, finished, duration = self.musicPlayback:play(
            musicSeconds,
            self.playbackRate
        )
        if not started then
            self.timelineSeconds = previousTimelineSeconds
            self:pause()
            return nil, startError
        end
        self.musicStarted = not finished
        self.musicFinished = finished == true
        if finished and duration then
            self.timelineSeconds = math.max(0, duration - self.mixtape.beat0Offset)
        end
    elseif self.musicStarted then
        local updated, updateError, finished, duration = self.musicPlayback:update(
            musicSeconds,
            self.playbackRate,
            deltaTime
        )
        if not updated then
            self.timelineSeconds = previousTimelineSeconds
            self:pause()
            return nil, updateError
        end
        if finished then
            self.musicStarted = false
            self.musicFinished = true
            if duration then
                self.timelineSeconds = math.max(
                    0,
                    duration - self.mixtape.beat0Offset
                )
            end
        end
    end

    return true, nil
end

function PlaybackTransport:getBeat()
    return self.tempoMap:secondsToBeat(self.timelineSeconds)
end

function PlaybackTransport:getTimelineSeconds()
    return self.timelineSeconds
end

function PlaybackTransport:isPlaying()
    return self.playing
end

function PlaybackTransport:isMusicFinished()
    return self.resolvedMusicPath ~= nil and self.musicFinished
end

function PlaybackTransport:getPlaybackRate()
    return self.playbackRate
end

return PlaybackTransport
