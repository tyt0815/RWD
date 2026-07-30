local Config = require("projects.rhythm_dotgeo.game.SpeakiSong.Config")
local GameplayConfig = require("projects.rhythm_dotgeo.game.GameplayConfig")
local Sounds = require("projects.rhythm_dotgeo.game.SpeakiSong.Sounds")

local function createSoundData(resource, sampleCount, sampleRate, bitDepth, channels)
    local data = {
        resource = resource,
        sampleCount = sampleCount,
        sampleRate = sampleRate,
        bitDepth = bitDepth,
        channels = channels,
        samples = {},
    }
    for frame = 0, sampleCount - 1 do
        data.samples[frame + 1] = {}
        for channel = 1, channels do
            local value = resource:find("loop", 1, true)
                and (frame % 2 == 0 and 0.4 or 0.5)
                or (frame + 1) / 10
            data.samples[frame + 1][channel] = value
        end
    end
    function data:getSampleCount() return self.sampleCount end
    function data:getSampleRate() return self.sampleRate end
    function data:getBitDepth() return self.bitDepth end
    function data:getChannelCount() return self.channels end
    function data:getDuration() return self.sampleCount / self.sampleRate end
    function data:getSample(frame, channel)
        return self.samples[frame + 1][channel or 1]
    end
    function data:setSample(frame, channel, value)
        self.samples[frame + 1][channel] = value
    end
    return data
end

local function createSound()
    return {
        newSoundData = function(resource, sampleRate, bitDepth, channels)
            if type(resource) == "string" then
                local sampleCount = resource:find("loop", 1, true) and 2 or 3
                return createSoundData(resource, sampleCount, 100, 16, 2)
            end
            return createSoundData("generated", resource,
                sampleRate, bitDepth, channels)
        end,
    }
end

local function createAudio(state)
    return {
        newSource = function(resource, sourceType)
            local source = {
                resource = resource,
                path = resource,
                sourceType = sourceType,
                position = 0,
                playing = false,
            }
            function source:play()
                self.playing = true
                table.insert(state.playedPaths, self.path)
            end
            function source:stop() self.playing = false end
            function source:seek(position) self.position = position end
            function source:isPlaying() return self.playing end
            function source:setLooping(looping) self.looping = looping end
            table.insert(state.sources, source)
            return source
        end,
        newQueueableSource = function(sampleRate, bitDepth, channels, bufferCount)
            local source = {
                sampleRate = sampleRate,
                bitDepth = bitDepth,
                channels = channels,
                bufferCount = bufferCount,
                queued = {},
                playing = false,
                playCount = 0,
            }
            function source:queue(soundData)
                if #self.queued >= self.bufferCount then return false end
                table.insert(self.queued, soundData)
                return true
            end
            function source:getFreeBufferCount()
                return self.bufferCount - #self.queued
            end
            function source:play()
                self.playing = true
                self.playCount = self.playCount + 1
                table.insert(state.playedPaths, "<queueable>")
            end
            function source:stop()
                self.playing = false
                self.queued = {}
            end
            function source:isPlaying() return self.playing end
            function source:consume()
                table.remove(self.queued, 1)
            end
            table.insert(state.sources, source)
            return source
        end,
    }
end

local function createConfig()
    local paths = {}
    for index = 1, 3 do paths[index] = "tap" .. index .. ".mp3" end
    return {
        longStartSound = "hue-start.mp3",
        longLoopSound = "hue-loop.mp3",
        longEndSound = "hue-end.mp3",
        tapSounds = paths,
    }
end

return {
    {
        name = "Rhythm Dotgeo gameplay Config는 전역 Long 임계값 ms를 읽는다",
        run = function(test)
            local config = GameplayConfig.new({
                load = function()
                    return { longHoldThresholdMs = 125 }
                end,
            })

            local resolved = assert(config:load())

            test.assertEqual(resolved.longHoldThresholdMs, 125)
        end,
    },
    {
        name = "스피키 Config는 3개 Tap SFX 배열을 그대로 허용한다",
        run = function(test)
            local rawConfig = {
                longStartSound = "assets/audio/sfx/start.mp3",
                longLoopSound = "assets/audio/sfx/loop.mp3",
                longEndSound = "assets/audio/sfx/end.mp3",
                actorLayout = {
                    heightRatio = 0.52,
                    maxWidthRatio = 0.3,
                    sideMarginRatio = 0.09,
                    minMargin = 24,
                    outsidePadding = 12,
                },
                reactions = {
                    longPressBeats = 0.2,
                    longShiftXRatio = 0.035,
                    longShiftYRatio = 0.045,
                    tapDurationBeats = 0.35,
                    tapShiftXRatio = 0.07,
                    tapShiftYRatio = 0.055,
                    tapShakeRatio = 0.012,
                },
                tapSounds = {
                    "assets/audio/sfx/tap1.mp3",
                    "assets/audio/sfx/tap2.mp3",
                    "assets/audio/sfx/tap3.mp3",
                },
            }
            local config = Config.new({
                load = function() return rawConfig end,
            })

            local resolved = assert(config:load())

            test.assertEqual(#resolved.tapSounds, 3)
            test.assertEqual(resolved.tapSounds[3],
                "projects/rhythm_dotgeo/assets/audio/sfx/tap3.mp3")
        end,
    },
    {
        name = "스피키 Long SFX는 start와 loop PCM을 미리 큐에 넣고 소비된 loop를 보충한다",
        run = function(test)
            local state = { sources = {}, playedPaths = {} }
            local sounds = Sounds.new(createAudio(state), createSound())
            sounds:configure(createConfig())
            sounds:startLong("guide")
            local longSource = sounds.longSources.guide
            local endSource = sounds.longEndSources.guide

            test.assertEqual(longSource.playing, true)
            test.assertEqual(#longSource.queued, 4)
            test.assertEqual(longSource.queued[1].resource, "hue-start.mp3")
            test.assertEqual(longSource.queued[2], sounds.longLoopChunkData)
            test.assertEqual(sounds.longLoopChunkData:getSampleCount(), 26)
            test.assertNear(sounds.longLoopChunkData:getSample(0, 1), 0.4, 0.000001)
            test.assertNear(sounds.longLoopChunkData:getSample(1, 1), 0.5, 0.000001)
            test.assertNear(sounds.longLoopChunkData:getSample(2, 1), 0.4, 0.000001)

            longSource:consume()
            sounds:update()
            test.assertEqual(#longSource.queued, 4)
            test.assertEqual(longSource.queued[4], sounds.longLoopChunkData)
            test.assertEqual(longSource.playCount, 1)

            sounds:releaseLong("guide")
            test.assertEqual(longSource.playing, false)
            test.assertEqual(#longSource.queued, 0)
            test.assertEqual(endSource.playing, true)
            test.assertEqual(state.playedPaths[1], "<queueable>")
            test.assertEqual(state.playedPaths[2], "hue-end.mp3")

            sounds:startLong("guide")
            sounds:releaseLong("guide")
            test.assertEqual(longSource.playing, false)
            test.assertEqual(endSource.playing, true)
        end,
    },
    {
        name = "가이드 Long SFX와 플레이어 입력 SFX는 서로 중첩된다",
        run = function(test)
            local state = { sources = {}, playedPaths = {} }
            local sounds = Sounds.new(createAudio(state), createSound())
            sounds:configure(createConfig())

            sounds:startLong("guide")
            sounds:playTap("player")
            sounds:startLong("player")

            test.assertEqual(sounds.longSources.guide.playing, true)
            test.assertEqual(sounds.longSources.player.playing, true)
            test.assertEqual(sounds.tapSources.player[1].playing, true)
        end,
    },
    {
        name = "스피키 Tap SFX는 설정된 개수만큼 역할별로 독립 순환한다",
        run = function(test)
            local state = { sources = {}, playedPaths = {} }
            local sounds = Sounds.new(createAudio(state), createSound())
            sounds:configure(createConfig())
            sounds:resetTapIndex("guide")
            sounds:resetTapIndex("player")

            for _ = 1, 4 do sounds:playTap("guide") end
            sounds:playTap("player")

            test.assertEqual(state.playedPaths[1], "tap1.mp3")
            test.assertEqual(state.playedPaths[3], "tap3.mp3")
            test.assertEqual(state.playedPaths[4], "tap1.mp3")
            test.assertEqual(state.playedPaths[5], "tap1.mp3")
            test.assertEqual(sounds.tapIndices.guide, 1)
            test.assertEqual(sounds.tapIndices.player, 1)
        end,
    },
}
