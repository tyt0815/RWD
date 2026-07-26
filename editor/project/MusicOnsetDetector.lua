local MusicOnsetDetector = {}
MusicOnsetDetector.__index = MusicOnsetDetector

local DECODER_BUFFER_BYTES = 4096
local WINDOW_SECONDS = 0.01
local RMS_THRESHOLD = 0.01
local REQUIRED_LOUD_WINDOWS = 2

local function defaultDecoderFactory(path)
    return love.sound.newDecoder(path, DECODER_BUFFER_BYTES)
end

local function releaseDecoder(decoder)
    if decoder and decoder.release then pcall(decoder.release, decoder) end
end

function MusicOnsetDetector.new(options)
    options = options or {}
    return setmetatable({
        decoderFactory = options.decoderFactory or defaultDecoderFactory,
    }, MusicOnsetDetector)
end

local function scanDecoder(decoder)
    local processedFrames = 0
    local windowPower = 0
    local windowFrameCount = 0
    local windowStartFrame = 0
    local candidateFrame
    local loudWindowCount = 0

    while true do
        local soundData = decoder:decode()
        if not soundData then break end

        local sampleRate = soundData:getSampleRate()
        local channelCount = soundData:getChannelCount()
        local targetWindowFrames = math.max(1, math.floor(
            sampleRate * WINDOW_SECONDS + 0.5
        ))

        for sampleIndex = 0, soundData:getSampleCount() - 1 do
            local framePower = 0
            for channel = 1, channelCount do
                local sample = soundData:getSample(sampleIndex, channel)
                framePower = framePower + sample * sample
            end
            windowPower = windowPower + framePower / channelCount
            windowFrameCount = windowFrameCount + 1
            processedFrames = processedFrames + 1

            if windowFrameCount == targetWindowFrames then
                local rms = math.sqrt(windowPower / windowFrameCount)
                if rms >= RMS_THRESHOLD then
                    loudWindowCount = loudWindowCount + 1
                    if loudWindowCount == 1 then
                        candidateFrame = windowStartFrame
                    end
                    if loudWindowCount >= REQUIRED_LOUD_WINDOWS then
                        return candidateFrame / sampleRate
                    end
                else
                    loudWindowCount = 0
                    candidateFrame = nil
                end
                windowPower = 0
                windowFrameCount = 0
                windowStartFrame = processedFrames
            end
        end
    end

    return nil
end

function MusicOnsetDetector:detect(projectId, music)
    local path = "projects/" .. projectId .. "/" .. music
    local created, decoderOrError = pcall(
        self.decoderFactory,
        path,
        DECODER_BUFFER_BYTES
    )
    if not created then
        return nil, "Failed to analyze Music onset: " .. tostring(decoderOrError)
    end

    local decoder = decoderOrError
    local scanned, onsetOrError = pcall(scanDecoder, decoder)
    releaseDecoder(decoder)
    if not scanned then
        return nil, "Failed to analyze Music onset: " .. tostring(onsetOrError)
    end
    if onsetOrError == nil then
        return nil, "No audible sound was detected in Music."
    end
    return onsetOrError, nil
end

return MusicOnsetDetector
