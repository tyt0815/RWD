local SAMPLE_RATE = 44100

local function newFixture()
    local state = {
        samples = {},
        playing = false,
    }

    local function soundDataFactory(sampleCount, sampleRate)
        state.sampleCount = sampleCount
        state.sampleRate = sampleRate
        return {
            setSample = function(_, index, value)
                state.samples[index] = value
            end,
        }
    end

    local function sourceFactory(soundData, sourceType)
        state.soundData = soundData
        state.sourceType = sourceType
        return {
            setLooping = function(_, looping)
                state.looping = looping
            end,
            seek = function(_, position)
                state.seekPosition = position
            end,
            setPitch = function(_, pitch)
                state.pitch = pitch
            end,
            play = function()
                state.playing = true
            end,
            pause = function()
                state.playing = false
            end,
            stop = function()
                state.playing = false
            end,
        }
    end

    return state, soundDataFactory, sourceFactory
end

local function newMetronome()
    local MetronomePlayback = require("editor.playback.MetronomePlayback")
    local state, soundDataFactory, sourceFactory = newFixture()
    return MetronomePlayback.new({
        soundDataFactory = soundDataFactory,
        sourceFactory = sourceFactory,
    }), state
end

return {
    {
        name = "Metronome Period 4는 한 beat에 강박 하나와 일반박 셋을 만든다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0, 1))

            test.assertEqual(state.sampleCount, SAMPLE_RATE / 2)
            test.assertEqual(state.sampleRate, SAMPLE_RATE)

            local firstTick = state.samples[1]
            local secondTick = state.samples[5513]
            local thirdTick = state.samples[11026]
            local fourthTick = state.samples[16538]
            test.assertTrue(math.abs(firstTick) > math.abs(secondTick))
            test.assertNear(secondTick, thirdTick, 0.000001)
            test.assertNear(thirdTick, fourthTick, 0.000001)
        end,
    },
    {
        name = "Metronome beat 0 Play는 phase 0에서 즉시 재생한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0, 1))

            test.assertEqual(state.seekPosition, 0)
            test.assertEqual(state.looping, true)
            test.assertEqual(state.playing, true)
            test.assertEqual(state.sourceType, "static")
        end,
    },
    {
        name = "Metronome은 중간 beat의 세부 위치에서 재개한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 2.5, 1))

            test.assertNear(state.seekPosition, 0.25, 0.000001)
        end,
    },
    {
        name = "Metronome은 Playback Rate를 적용하고 Pause한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 2.5, 0.5))

            test.assertEqual(state.pitch, 0.5)
            test.assertEqual(state.playing, true)
            assert(metronome:pause())
            test.assertEqual(state.playing, false)
        end,
    },
    {
        name = "Metronome Stop은 현재 Source를 정지한다",
        run = function(test)
            local metronome, state = newMetronome()
            assert(metronome:play(120, 4, 0, 1))

            assert(metronome:stop())
            test.assertEqual(state.playing, false)
        end,
    },
    {
        name = "Metronome Source 시작 실패는 생성한 Source를 정리한다",
        run = function(test)
            local state = { playing = false, stopCount = 0 }
            local metronome = require("editor.playback.MetronomePlayback").new({
                soundDataFactory = function()
                    return { setSample = function() end }
                end,
                sourceFactory = function()
                    return {
                        setLooping = function() end,
                        seek = function() end,
                        setPitch = function() end,
                        play = function()
                            state.playing = true
                            error("source play failed")
                        end,
                        stop = function()
                            state.stopCount = state.stopCount + 1
                            state.playing = false
                        end,
                    }
                end,
            })

            local returned, started, errorMessage = pcall(function()
                return metronome:play(120, 4, 0, 1)
            end)

            test.assertEqual(returned, true)
            test.assertEqual(started, nil)
            test.assertContains(errorMessage, "source play failed")
            test.assertEqual(state.stopCount, 1)
            test.assertEqual(state.playing, false)
        end,
    },
    {
        name = "Metronome은 LÖVE userdata Source를 재생한다",
        run = function(test)
            local state = { playing = false }
            local source = newproxy(true)
            getmetatable(source).__index = {
                setLooping = function(_, value) state.looping = value end,
                seek = function(_, value) state.seekPosition = value end,
                setPitch = function(_, value) state.pitch = value end,
                play = function() state.playing = true end,
                pause = function() state.playing = false end,
                stop = function() state.playing = false end,
            }
            local metronome = require("editor.playback.MetronomePlayback").new({
                soundDataFactory = function()
                    return { setSample = function() end }
                end,
                sourceFactory = function() return source end,
            })

            local started, errorMessage = metronome:play(120, 4, 0, 1)

            test.assertEqual(started, true, errorMessage)
            test.assertEqual(state.looping, true)
            test.assertEqual(state.playing, true)
        end,
    },
}
