local Sounds = {}
Sounds.__index = Sounds

local ROLES = { "guide", "player" }
local QUEUE_BUFFER_COUNT = 4
local LOOP_CHUNK_SECONDS = 0.25

local function createLoopChunk(sound, loopData)
    local loopFrames = loopData:getSampleCount()
    local sampleRate = loopData:getSampleRate()
    local bitDepth = loopData:getBitDepth()
    local channels = loopData:getChannelCount()
    local targetFrames = math.ceil(LOOP_CHUNK_SECONDS * sampleRate)
    local repeatCount = math.max(1, math.ceil(targetFrames / loopFrames))
    local chunkFrames = loopFrames * repeatCount
    local chunk = sound.newSoundData(
        chunkFrames, sampleRate, bitDepth, channels)

    for frame = 0, chunkFrames - 1 do
        local loopFrame = frame % loopFrames
        for channel = 1, channels do
            chunk:setSample(frame, channel,
                loopData:getSample(loopFrame, channel))
        end
    end
    return chunk
end

local function fillLoopBuffers(sounds, source)
    local freeBufferCount = source:getFreeBufferCount()
    for _ = 1, freeBufferCount do
        source:queue(sounds.longLoopChunkData)
    end
end

function Sounds.new(audio, sound)
    return setmetatable({
        audio = audio or love.audio,
        sound = sound or love.sound,
        longStartData = nil,
        longLoopChunkData = nil,
        longSources = {},
        longEndSources = {},
        longHeld = { guide = false, player = false },
        tapSources = { guide = {}, player = {} },
        tapIndices = { guide = 0, player = 0 },
    }, Sounds)
end

function Sounds:stop()
    for _, role in ipairs(ROLES) do
        local longSource = self.longSources[role]
        local endSource = self.longEndSources[role]
        if longSource then longSource:stop() end
        if endSource then endSource:stop() end
        for _, source in ipairs(self.tapSources[role]) do source:stop() end
        self.longHeld[role] = false
    end
end

-- Config가 Play마다 다시 로드되므로 세 Long SFX 경로도 새 Source에 반영한다.
function Sounds:configure(config)
    self:stop()
    local loopData = self.sound.newSoundData(config.longLoopSound)
    self.longStartData = self.sound.newSoundData(config.longStartSound)
    self.longLoopChunkData = createLoopChunk(self.sound, loopData)
    self.longSources = {}
    self.longEndSources = {}
    self.tapSources = { guide = {}, player = {} }
    for _, role in ipairs(ROLES) do
        self.longSources[role] = self.audio.newQueueableSource(
            self.longStartData:getSampleRate(),
            self.longStartData:getBitDepth(),
            self.longStartData:getChannelCount(),
            QUEUE_BUFFER_COUNT)
        self.longEndSources[role] = self.audio.newSource(config.longEndSound, "static")
        for index, path in ipairs(config.tapSounds) do
            self.tapSources[role][index] = self.audio.newSource(path, "static")
        end
    end
    self:resetTapIndex("guide")
    self:resetTapIndex("player")
end

function Sounds:resetTapIndex(role)
    assert(self.tapIndices[role] ~= nil, "Unknown SpeakiSong sound role")
    self.tapIndices[role] = 0
end

function Sounds:playTap(role)
    local index = self.tapIndices[role]
    assert(index ~= nil, "Unknown SpeakiSong sound role")
    local sourceCount = #self.tapSources[role]
    if sourceCount == 0 then return end
    local source = self.tapSources[role][index + 1]
    source:stop()
    source:seek(0)
    source:play()
    self.tapIndices[role] = (index + 1) % sourceCount
end

function Sounds:startLong(role)
    local longSource = self.longSources[role]
    local endSource = self.longEndSources[role]
    if not longSource or not endSource then return end
    longSource:stop()
    endSource:stop()
    longSource:queue(self.longStartData)
    fillLoopBuffers(self, longSource)
    longSource:play()
    self.longHeld[role] = true
end

function Sounds:releaseLong(role)
    local longSource = self.longSources[role]
    local endSource = self.longEndSources[role]
    if not longSource or not endSource then return end
    self.longHeld[role] = false
    longSource:stop()
    endSource:stop()
    endSource:seek(0, "seconds")
    endSource:play()
end

function Sounds:update()
    for _, role in ipairs(ROLES) do
        local longSource = self.longSources[role]
        if self.longHeld[role] and longSource then
            fillLoopBuffers(self, longSource)
            if not longSource:isPlaying() then longSource:play() end
        end
    end
end

return Sounds
