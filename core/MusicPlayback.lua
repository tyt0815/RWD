local MusicPlayback = {}
MusicPlayback.__index = MusicPlayback

local DRIFT_CHECK_INTERVAL_SECONDS = 1
local MAX_DRIFT_SECONDS = 0.05

local function failureMessage(errorMessage)
    return nil, "Music playback failed: " .. tostring(errorMessage)
end

local function callSource(source, methodName, ...)
    return pcall(source[methodName], source, ...)
end

function MusicPlayback.new(options)
    options = options or {}

    return setmetatable({
        sourceFactory = options.sourceFactory or function(path, sourceType)
            return love.audio.newSource(path, sourceType)
        end,
        source = nil,
        duration = nil,
        driftElapsed = 0,
        driftExpectedAnchor = nil,
        driftReportedAnchor = nil,
        started = false,
    }, MusicPlayback)
end

function MusicPlayback:clearState()
    self.source = nil
    self.duration = nil
    self.driftElapsed = 0
    self.driftExpectedAnchor = nil
    self.driftReportedAnchor = nil
    self.started = false
end

function MusicPlayback:fail(errorMessage)
    local source = self.source
    self:clearState()

    if source then
        pcall(source.stop, source)
    end

    return failureMessage(errorMessage)
end

function MusicPlayback:prepare(path, volume)
    local stopped, stopError = self:stop()
    if not stopped then
        return nil, stopError
    end

    if path == nil then
        return true, nil
    end

    local created, sourceOrError = pcall(self.sourceFactory, path, "stream")
    if not created then
        return self:fail(sourceOrError)
    end

    self.source = sourceOrError

    local volumeSet, volumeError = callSource(self.source, "setVolume", volume)
    if not volumeSet then
        return self:fail(volumeError)
    end

    local durationRead, durationOrError = callSource(self.source, "getDuration")
    if not durationRead then
        return self:fail(durationOrError)
    end

    self.duration = durationOrError
    return true, nil
end

function MusicPlayback:play(positionSeconds, playbackRate)
    if not self.source then
        return true, nil
    end

    if positionSeconds < 0 or positionSeconds >= self.duration then
        local stopped, stopError = callSource(self.source, "stop")
        if not stopped then
            return self:fail(stopError)
        end

        self.started = false
        self.driftElapsed = 0
        self.driftExpectedAnchor = nil
        self.driftReportedAnchor = nil
        return true, nil
    end

    local sought, seekError = callSource(self.source, "seek", positionSeconds)
    if not sought then
        return self:fail(seekError)
    end

    local pitchSet, pitchError = callSource(self.source, "setPitch", playbackRate)
    if not pitchSet then
        return self:fail(pitchError)
    end

    local played, playError = callSource(self.source, "play")
    if not played then
        return self:fail(playError)
    end

    self.started = true
    self.driftElapsed = 0
    self.driftExpectedAnchor = nil
    self.driftReportedAnchor = nil
    return true, nil
end

function MusicPlayback:update(expectedSeconds, playbackRate, deltaTime)
    if not self.source or not self.started then
        return true, nil
    end

    if expectedSeconds >= self.duration then
        local stopped, stopError = callSource(self.source, "stop")
        if not stopped then
            return self:fail(stopError)
        end

        self.started = false
        self.driftElapsed = 0
        self.driftExpectedAnchor = nil
        self.driftReportedAnchor = nil
        return true, nil
    end

    local pitchSet, pitchError = callSource(self.source, "setPitch", playbackRate)
    if not pitchSet then
        return self:fail(pitchError)
    end

    self.driftElapsed = self.driftElapsed + deltaTime
    if self.driftElapsed < DRIFT_CHECK_INTERVAL_SECONDS then
        return true, nil
    end

    self.driftElapsed = self.driftElapsed % DRIFT_CHECK_INTERVAL_SECONDS
    local told, positionOrError = callSource(self.source, "tell")
    if not told then
        return self:fail(positionOrError)
    end

    if self.driftExpectedAnchor == nil then
        self.driftExpectedAnchor = expectedSeconds
        self.driftReportedAnchor = positionOrError
        return true, nil
    end

    local expectedElapsed = expectedSeconds - self.driftExpectedAnchor
    local reportedElapsed = positionOrError - self.driftReportedAnchor
    if math.abs(reportedElapsed - expectedElapsed) > MAX_DRIFT_SECONDS then
        local sought, seekError = callSource(self.source, "seek", expectedSeconds)
        if not sought then
            return self:fail(seekError)
        end
        self.driftExpectedAnchor = nil
        self.driftReportedAnchor = nil
    end

    return true, nil
end

function MusicPlayback:pause()
    if not self.source then
        return true, nil
    end

    local paused, pauseError = callSource(self.source, "pause")
    if not paused then
        return self:fail(pauseError)
    end

    self.started = false
    return true, nil
end

function MusicPlayback:stop()
    local source = self.source
    self:clearState()

    if not source then
        return true, nil
    end

    local stopped, stopError = callSource(source, "stop")
    if not stopped then
        return failureMessage(stopError)
    end

    return true, nil
end

return MusicPlayback
