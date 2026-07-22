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
    }, PlaybackTransport), nil
end

function PlaybackTransport:configureMixtape(settings, resolvedMusicPath)
    self.mixtape = settings or DEFAULT_MIXTAPE
    self.resolvedMusicPath = resolvedMusicPath
    self.musicStarted = false
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
        local started, startError = self.musicPlayback:play(musicSeconds, self.playbackRate)
        if not started then
            self:pause()
            return nil, startError
        end
        self.musicStarted = true
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
    local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset
    if musicSeconds >= 0 then
        local started, startError = self.musicPlayback:play(musicSeconds, playbackRate)
        if not started then
            self:pause()
            return nil, startError
        end
        self.musicStarted = true
    end

    self.playing = true
    return true, nil
end

function PlaybackTransport:pause()
    self.playing = false
    self.musicStarted = false
    return self.musicPlayback:pause()
end

function PlaybackTransport:update(deltaTime)
    if not self.playing then return true, nil end

    self.timelineSeconds = self.timelineSeconds + deltaTime * self.playbackRate
    local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset

    if not self.musicStarted and musicSeconds >= 0 then
        local started, startError = self.musicPlayback:play(musicSeconds, self.playbackRate)
        if not started then
            self:pause()
            return nil, startError
        end
        self.musicStarted = true
    elseif self.musicStarted then
        local updated, updateError = self.musicPlayback:update(
            musicSeconds,
            self.playbackRate,
            deltaTime
        )
        if not updated then
            self:pause()
            return nil, updateError
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

function PlaybackTransport:getPlaybackRate()
    return self.playbackRate
end

return PlaybackTransport
