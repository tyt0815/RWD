return {
    {
        name = "코어 API 버전은 1이다",
        run = function(test)
            local Core = require("core")
            test.assertEqual(Core.CORE_API_VERSION, 1)
        end,
    },
    {
        name = "코어는 네 가지 판정 결과를 공개한다",
        run = function(test)
            local Core = require("core")
            test.assertEqual(Core.JudgmentResult.GOOD, "GOOD")
            test.assertEqual(Core.JudgmentResult.BAD, "BAD")
            test.assertEqual(Core.JudgmentResult.MISS, "MISS")
            test.assertEqual(Core.JudgmentResult.EMPTY_INPUT, "EMPTY_INPUT")
        end,
    },
    {
        name = "게임용 Core PlaybackTransport Play 기본 rate는 1이다",
        run = function(test)
            local Core = require("core")
            local state = {}
            local transport = assert(Core.PlaybackTransport.new({
                bpm = 120,
                musicPlayback = {
                    prepare = function() return true, nil end,
                    play = function(_, _, rate)
                        state.musicRate = rate
                        return true, nil
                    end,
                    update = function() return true, nil end,
                    pause = function() return true, nil end,
                },
            }))
            assert(transport:configureMixtape(
                { volume = 1, beat0Offset = 0 },
                "game.wav"
            ))

            assert(transport:play())
            assert(transport:update(0.5))

            test.assertEqual(transport:getPlaybackRate(), 1)
            test.assertEqual(state.musicRate, 1)
            test.assertNear(transport:getBeat(), 1, 0.000001)
        end,
    },
    {
        name = "Core Transport는 Offset -0.5 Rate 2에서 0.25초 뒤 Music position 0으로 시작한다",
        run = function(test)
            local Core = require("core")
            local state = { playCount = 0 }
            local transport = assert(Core.PlaybackTransport.new({
                bpm = 120,
                musicPlayback = {
                    prepare = function() return true, nil end,
                    play = function(_, position, rate)
                        state.playCount = state.playCount + 1
                        state.position = position
                        state.rate = rate
                        return true, nil
                    end,
                    update = function() return true, nil end,
                    pause = function() return true, nil end,
                },
            }))
            assert(transport:configureMixtape(
                { volume = 1, beat0Offset = -0.5 },
                "game.wav"
            ))

            assert(transport:play(2))
            test.assertEqual(state.playCount, 0)
            assert(transport:update(0.25))

            test.assertEqual(state.playCount, 1)
            test.assertNear(state.position, 0, 0.000001)
            test.assertEqual(state.rate, 2)
            test.assertNear(transport:getBeat(), 1, 0.000001)
        end,
    },
}
