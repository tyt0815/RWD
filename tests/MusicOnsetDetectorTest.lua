local function newSoundData(samples, sampleRate)
    return {
        getSampleCount = function() return #samples end,
        getSampleRate = function() return sampleRate end,
        getChannelCount = function() return 2 end,
        getSample = function(_, index, channel)
            return samples[index + 1][channel]
        end,
    }
end

local function newDecoder(chunks)
    local index = 0
    local released = false
    return {
        decode = function()
            index = index + 1
            return chunks[index]
        end,
        release = function()
            released = true
        end,
        wasReleased = function()
            return released
        end,
    }
end

local function repeatedSamples(count, value)
    local samples = {}
    for _ = 1, count do
        table.insert(samples, { value, value })
    end
    return samples
end

return {
    {
        name = "MusicOnsetDetector는 청크 경계를 넘어 연속된 첫 소리 시간을 찾는다",
        run = function(test)
            local MusicOnsetDetector = require("editor.project.MusicOnsetDetector")
            local decoder = newDecoder({
                newSoundData(repeatedSamples(20, 0), 1000),
                newSoundData(repeatedSamples(10, 0.02), 1000),
                newSoundData(repeatedSamples(10, 0.02), 1000),
            })
            local requestedPath
            local detector = MusicOnsetDetector.new({
                decoderFactory = function(path)
                    requestedPath = path
                    return decoder
                end,
            })

            local onset = assert(detector:detect(
                "sample",
                "assets/audio/song.ogg"
            ))

            test.assertEqual(requestedPath, "projects/sample/assets/audio/song.ogg")
            test.assertNear(onset, 0.02, 0.000001)
            test.assertEqual(decoder:wasReleased(), true)
        end,
    },
    {
        name = "MusicOnsetDetector는 무음과 decode 오류를 설명한다",
        run = function(test)
            local MusicOnsetDetector = require("editor.project.MusicOnsetDetector")
            local silentDetector = MusicOnsetDetector.new({
                decoderFactory = function()
                    return newDecoder({
                        newSoundData(repeatedSamples(20, 0), 1000),
                    })
                end,
            })
            local onset, silentError = silentDetector:detect(
                "sample",
                "assets/audio/silent.wav"
            )
            test.assertEqual(onset, nil)
            test.assertContains(silentError, "No audible sound")

            local failedDetector = MusicOnsetDetector.new({
                decoderFactory = function()
                    error("decode failed")
                end,
            })
            local failedOnset, decodeError = failedDetector:detect(
                "sample",
                "assets/audio/broken.mp3"
            )
            test.assertEqual(failedOnset, nil)
            test.assertContains(decodeError, "decode failed")
        end,
    },
}
