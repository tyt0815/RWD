local SampleSounds = {}
SampleSounds.__index = SampleSounds

local TONES = {
    cue = { frequency = 880, duration = 0.08 },
    GOOD = { frequency = 1320, duration = 0.09 },
    BAD = { frequency = 440, duration = 0.11 },
    MISS = { frequency = 180, duration = 0.16 },
    EMPTY_INPUT = { frequency = 260, duration = 0.08 },
}

local function createTone(audio, sound, frequency, duration)
    local sampleRate = 22050
    local sampleCount = math.floor(sampleRate * duration)
    local data = sound.newSoundData(sampleCount, sampleRate, 16, 1)
    for index = 0, sampleCount - 1 do
        local envelope = 1 - index / sampleCount
        data:setSample(index, math.sin(index / sampleRate * frequency * math.pi * 2)
            * 0.2 * envelope)
    end
    return audio.newSource(data, "static")
end

function SampleSounds.new()
    local instance = setmetatable({ sources = {} }, SampleSounds)
    if not love or not love.audio or not love.sound then return instance end
    for id, tone in pairs(TONES) do
        instance.sources[id] = createTone(
            love.audio,
            love.sound,
            tone.frequency,
            tone.duration
        )
    end
    return instance
end

function SampleSounds:play(id)
    local source = self.sources[id]
    if not source then return end
    source:stop()
    source:seek(0)
    source:play()
end

return SampleSounds
