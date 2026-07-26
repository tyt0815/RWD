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

local function createSoundData(self, bpm, period)
    local beatDuration = 60 / bpm
    local loopDuration = beatDuration * period
    local sampleCount = math.floor(loopDuration * SAMPLE_RATE + 0.5)
    local clickSampleCount = math.floor(CLICK_SECONDS * SAMPLE_RATE)
    local soundData = self.soundDataFactory(sampleCount, SAMPLE_RATE)

    for beatIndex = 0, period - 1 do
        local frequency = beatIndex == 0 and ACCENT_FREQUENCY or NORMAL_FREQUENCY
        local startSample = math.floor(beatIndex * beatDuration * SAMPLE_RATE)
        for offset = 0, clickSampleCount - 1 do
            local sampleIndex = startSample + offset
            if sampleIndex >= sampleCount then break end
            local time = offset / SAMPLE_RATE
            local envelope = 1 - time / CLICK_SECONDS
            local sample = AMPLITUDE
                * envelope
                * math.sin(2 * math.pi * frequency * time)
            soundData:setSample(sampleIndex, sample)
        end
    end

    return soundData, loopDuration, beatDuration
end

function MetronomePlayback.new(options)
    options = options or {}
    return setmetatable({
        soundDataFactory = options.soundDataFactory or defaultSoundDataFactory,
        sourceFactory = options.sourceFactory or defaultSourceFactory,
        source = nil,
    }, MetronomePlayback)
end

local function fail(metronome, source, errorMessage)
    metronome.source = nil
    if source then callSource(source, "stop") end
    return failureMessage(errorMessage)
end

function MetronomePlayback:play(bpm, period, beat, playbackRate)
    local stopped, stopError = self:stop()
    if not stopped then return nil, stopError end

    local soundCreated, soundData, loopDuration, beatDuration = pcall(
        createSoundData,
        self,
        bpm,
        period
    )
    if not soundCreated then return failureMessage(soundData) end

    local sourceCreated, source = pcall(self.sourceFactory, soundData, "static")
    if not sourceCreated then return failureMessage(source) end
    self.source = source

    local loopSet, loopError = callSource(source, "setLooping", true)
    if not loopSet then return fail(self, source, loopError) end
    local sought, seekError = callSource(
        source,
        "seek",
        (beat % period) * beatDuration
    )
    if not sought then return fail(self, source, seekError) end
    local pitchSet, pitchError = callSource(source, "setPitch", playbackRate)
    if not pitchSet then return fail(self, source, pitchError) end
    local played, playError = callSource(source, "play")
    if not played then return fail(self, source, playError) end
    return true, nil
end

function MetronomePlayback:pause()
    if not self.source then return true, nil end
    local paused, pauseError = callSource(self.source, "pause")
    if not paused then return fail(self, self.source, pauseError) end
    return true, nil
end

function MetronomePlayback:stop()
    local source = self.source
    self.source = nil
    if not source then return true, nil end

    local stopped, stopError = callSource(source, "stop")
    if not stopped then return failureMessage(stopError) end
    return true, nil
end

return MetronomePlayback
