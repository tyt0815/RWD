return {
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
}
