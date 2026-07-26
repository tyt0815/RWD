return {
    {
        name = "TapJudgment는 GOOD BAD EMPTY_INPUT을 beat 판정창으로 구분한다",
        run = function(test)
            local Core = require("core")
            local judgment = Core.TapJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            judgment:addNote("good", 4)
            judgment:addNote("bad", 8)

            local good = judgment:input(4.08)
            local empty = judgment:input(6)
            local bad = judgment:input(7.8)

            test.assertEqual(good.result, Core.JudgmentResult.GOOD)
            test.assertEqual(good.noteId, "good")
            test.assertEqual(empty.result, Core.JudgmentResult.EMPTY_INPUT)
            test.assertEqual(empty.noteId, nil)
            test.assertEqual(bad.result, Core.JudgmentResult.BAD)
            test.assertEqual(bad.noteId, "bad")
        end,
    },
    {
        name = "TapJudgment는 BAD 판정창이 지난 미입력 노트를 MISS로 만든다",
        run = function(test)
            local Core = require("core")
            local judgment = Core.TapJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            judgment:addNote("miss", 4)

            test.assertEqual(#judgment:update(4.25), 0)
            local misses = judgment:update(4.251)
            test.assertEqual(#misses, 1)
            test.assertEqual(misses[1].result, Core.JudgmentResult.MISS)
            test.assertEqual(misses[1].noteId, "miss")
            test.assertEqual(#judgment:update(5), 0)
        end,
    },
}
