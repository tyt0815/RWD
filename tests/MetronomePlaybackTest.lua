local SAMPLE_RATE = 44100
local CLICK_SECONDS = 0.012
local AMPLITUDE = 0.35
local CLICK_SAMPLE_COUNT = math.floor(CLICK_SECONDS * SAMPLE_RATE)

local function expectedClickSample(frequency, offset)
    local time = offset / SAMPLE_RATE
    local envelope = 1 - time / CLICK_SECONDS
    return AMPLITUDE
        * envelope
        * math.sin(2 * math.pi * frequency * time)
end

local function newMetronome(options)
    options = options or {}
    local state = {
        soundData = {},
        sources = {},
        clicks = {},
    }

    local function soundDataFactory(sampleCount, sampleRate)
        local soundData = {
            sampleCount = sampleCount,
            sampleRate = sampleRate,
            samples = {},
            setSample = function(self, index, value)
                self.samples[index] = value
            end,
        }
        table.insert(state.soundData, soundData)
        return soundData
    end

    local function sourceFactory(soundData, sourceType)
        if options.sourceErrorAt == #state.sources + 1 then
            error("source creation failed")
        end

        local accentSample = expectedClickSample(1760, 1)
        local kind = math.abs(soundData.samples[1] - accentSample) < 0.000001
            and "accent" or "normal"
        local source = {
            kind = kind,
            sourceType = sourceType,
            pauseCount = 0,
            stopCount = 0,
            setLooping = function(self, looping) self.looping = looping end,
            setPitch = function(self, pitch) self.pitch = pitch end,
            play = function(self)
                if options.playErrorKind == self.kind then
                    error(self.kind .. " play failed")
                end
                table.insert(state.clicks, self.kind)
            end,
            pause = function(self) self.pauseCount = self.pauseCount + 1 end,
            stop = function(self) self.stopCount = self.stopCount + 1 end,
        }
        table.insert(state.sources, source)
        return source
    end

    local MetronomePlayback = require("editor.playback.MetronomePlayback")
    return MetronomePlayback.new({
        soundDataFactory = soundDataFactory,
        sourceFactory = sourceFactory,
    }), state, options
end

local function assertClicks(test, state, expected)
    test.assertEqual(#state.clicks, #expected)
    for index, kind in ipairs(expected) do
        test.assertEqual(state.clicks[index], kind)
    end
end

return {
    {
        name = "Metronome audio memory는 낮은 BPM과 긴 Period에도 고정 크기다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(0.1, 32, 0, 1))

            test.assertEqual(#state.soundData, 2)
            test.assertEqual(state.soundData[1].sampleCount, CLICK_SAMPLE_COUNT)
            test.assertEqual(state.soundData[2].sampleCount, CLICK_SAMPLE_COUNT)
            test.assertEqual(state.soundData[1].sampleRate, SAMPLE_RATE)
            test.assertEqual(state.soundData[2].sampleRate, SAMPLE_RATE)
            test.assertNear(
                state.soundData[1].samples[1],
                expectedClickSample(1760, 1),
                0.000001
            )
            test.assertNear(
                state.soundData[2].samples[1],
                expectedClickSample(880, 1),
                0.000001
            )
            test.assertEqual(state.sources[1].sourceType, "static")
            test.assertEqual(state.sources[2].sourceType, "static")
            test.assertEqual(state.sources[1].looping, false)
            test.assertEqual(state.sources[2].looping, false)
        end,
    },
    {
        name = "Metronome Period 1은 beat 0과 beat 1에 강박을 재생한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 1, 0, 1))
            assert(metronome:update(1))

            assertClicks(test, state, { "accent", "accent" })
        end,
    },
    {
        name = "Metronome Period 4는 강약약약 순서로 beat crossing을 처리한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0, 1))
            assert(metronome:update(4))

            assertClicks(test, state, {
                "accent", "normal", "normal", "normal", "accent",
            })
        end,
    },
    {
        name = "Metronome Period 5는 강약약약약 순서로 beat crossing을 처리한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 5, 0, 1))
            assert(metronome:update(5))

            assertClicks(test, state, {
                "accent", "normal", "normal", "normal", "normal", "accent",
            })
        end,
    },
    {
        name = "Metronome fractional 시작은 지난 클릭을 건너뛴다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 6.5, 1))
            assertClicks(test, state, {})

            assert(metronome:update(7))
            assertClicks(test, state, { "normal" })
            assert(metronome:update(8))
            assertClicks(test, state, { "normal", "accent" })
        end,
    },
    {
        name = "Metronome은 두 Source에 Playback Rate를 적용한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0.5, 0.5))

            test.assertEqual(state.sources[1].pitch, 0.5)
            test.assertEqual(state.sources[2].pitch, 0.5)
        end,
    },
    {
        name = "Metronome Pause와 Stop은 두 Source 모두에 적용된다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0, 1))
            assert(metronome:pause())
            assert(metronome:stop())

            for _, source in ipairs(state.sources) do
                test.assertEqual(source.pauseCount, 1)
                test.assertEqual(source.stopCount, 1)
            end
        end,
    },
    {
        name = "Metronome 두 번째 Source 생성 실패는 첫 Source를 정리한다",
        run = function(test)
            local metronome, state = newMetronome({ sourceErrorAt = 2 })

            local started, errorMessage = metronome:play(120, 4, 0, 1)

            test.assertEqual(started, nil)
            test.assertContains(errorMessage, "source creation failed")
            test.assertEqual(state.sources[1].stopCount, 1)
        end,
    },
    {
        name = "Metronome update 재생 실패는 두 Source를 정리한다",
        run = function(test)
            local metronome, state, options = newMetronome()
            assert(metronome:play(120, 4, 0, 1))
            options.playErrorKind = "normal"

            local updated, errorMessage = metronome:update(1)

            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "normal play failed")
            for _, source in ipairs(state.sources) do
                test.assertEqual(source.stopCount, 1)
            end
        end,
    },
    {
        name = "Metronome은 두 LÖVE userdata Source를 재생하고 정지한다",
        run = function(test)
            local state = { sources = {}, clicks = {} }
            local metronome = require("editor.playback.MetronomePlayback").new({
                soundDataFactory = function()
                    return { setSample = function() end }
                end,
                sourceFactory = function()
                    local source = newproxy(true)
                    local sourceIndex = #state.sources + 1
                    getmetatable(source).__index = {
                        setLooping = function(_, value) state.looping = value end,
                        setPitch = function(_, value) state.pitch = value end,
                        play = function() table.insert(state.clicks, sourceIndex) end,
                        pause = function() end,
                        stop = function()
                            state.stopCount = (state.stopCount or 0) + 1
                        end,
                    }
                    table.insert(state.sources, source)
                    return source
                end,
            })

            assert(metronome:play(120, 4, 0, 1))
            assert(metronome:update(1))
            assert(metronome:stop())

            test.assertEqual(#state.sources, 2)
            test.assertEqual(state.clicks[1], 1)
            test.assertEqual(state.clicks[2], 2)
            test.assertEqual(state.looping, false)
            test.assertEqual(state.pitch, 1)
            test.assertEqual(state.stopCount, 2)
        end,
    },
}
