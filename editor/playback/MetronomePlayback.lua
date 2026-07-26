local MetronomePlayback = {}
MetronomePlayback.__index = MetronomePlayback

local SAMPLE_RATE = 44100
local CLICK_SECONDS = 0.012
local ACCENT_FREQUENCY = 1760
local NORMAL_FREQUENCY = 880
local AMPLITUDE = 0.35

local function failureMessage(errorMessage)
    return nil, "Metronome playback failed: " .. tostring(errorMessage)
end

local function callSource(source, methodName, ...)
    local methodRead, method = pcall(function()
        return source[methodName]
    end)
    if not methodRead or type(method) ~= "function" then
        return false, "Source does not implement " .. methodName .. "."
    end
    return pcall(method, source, ...)
end

local function defaultSoundDataFactory(sampleCount, sampleRate)
    return love.sound.newSoundData(sampleCount, sampleRate, 16, 1)
end

local function defaultSourceFactory(soundData, sourceType)
    return love.audio.newSource(soundData, sourceType)
end

local function createClickSoundData(self, frequency)
    local sampleCount = math.floor(CLICK_SECONDS * SAMPLE_RATE)
    local soundData = self.soundDataFactory(sampleCount, SAMPLE_RATE)

    for offset = 0, sampleCount - 1 do
        local time = offset / SAMPLE_RATE
        local envelope = 1 - time / CLICK_SECONDS
        local sample = AMPLITUDE
            * envelope
            * math.sin(2 * math.pi * frequency * time)
        soundData:setSample(offset, sample)
    end

    return soundData
end

local function clear(metronome)
    metronome.accentSource = nil
    metronome.normalSource = nil
    metronome.period = nil
    metronome.lastProcessedBeat = nil
end

local function callBoth(metronome, methodName, ...)
    local firstError = nil
    if metronome.accentSource then
        local called, errorMessage = callSource(
            metronome.accentSource,
            methodName,
            ...
        )
        if not called then firstError = errorMessage end
    end
    if metronome.normalSource then
        local called, errorMessage = callSource(
            metronome.normalSource,
            methodName,
            ...
        )
        if not called and not firstError then firstError = errorMessage end
    end
    return firstError == nil, firstError
end

local function fail(metronome, errorMessage)
    callBoth(metronome, "stop")
    clear(metronome)
    return failureMessage(errorMessage)
end

function MetronomePlayback.new(options)
    options = options or {}
    return setmetatable({
        soundDataFactory = options.soundDataFactory or defaultSoundDataFactory,
        sourceFactory = options.sourceFactory or defaultSourceFactory,
        accentSource = nil,
        normalSource = nil,
        period = nil,
        lastProcessedBeat = nil,
    }, MetronomePlayback)
end

local function playBeat(metronome, beatIndex)
    local source = beatIndex % metronome.period == 0
        and metronome.accentSource or metronome.normalSource
    local played, playError = callSource(source, "play")
    if not played then return fail(metronome, playError) end
    return true, nil
end

function MetronomePlayback:play(bpm, period, beat, playbackRate)
    local stopped, stopError = self:stop()
    if not stopped then return nil, stopError end

    local soundCreated, accentData, normalData = pcall(function()
        return createClickSoundData(self, ACCENT_FREQUENCY),
            createClickSoundData(self, NORMAL_FREQUENCY)
    end)
    if not soundCreated then return failureMessage(accentData) end

    local accentCreated, accentSource = pcall(
        self.sourceFactory,
        accentData,
        "static"
    )
    if not accentCreated then return failureMessage(accentSource) end
    self.accentSource = accentSource

    local normalCreated, normalSource = pcall(
        self.sourceFactory,
        normalData,
        "static"
    )
    if not normalCreated then return fail(self, normalSource) end
    self.normalSource = normalSource

    local loopSet, loopError = callBoth(self, "setLooping", false)
    if not loopSet then return fail(self, loopError) end
    local pitchSet, pitchError = callBoth(self, "setPitch", playbackRate)
    if not pitchSet then return fail(self, pitchError) end

    self.period = period
    self.lastProcessedBeat = math.floor(beat)
    if beat == self.lastProcessedBeat then
        return playBeat(self, self.lastProcessedBeat)
    end
    return true, nil
end

function MetronomePlayback:update(beat)
    if not self.accentSource or not self.normalSource then return true, nil end

    local currentBeat = math.floor(beat)
    for beatIndex = self.lastProcessedBeat + 1, currentBeat do
        local played, playError = playBeat(self, beatIndex)
        if not played then return nil, playError end
        self.lastProcessedBeat = beatIndex
    end
    return true, nil
end

function MetronomePlayback:pause()
    local paused, pauseError = callBoth(self, "pause")
    if not paused then return fail(self, pauseError) end
    return true, nil
end

function MetronomePlayback:stop()
    local stopped, stopError = callBoth(self, "stop")
    clear(self)
    if not stopped then return failureMessage(stopError) end
    return true, nil
end

return MetronomePlayback
