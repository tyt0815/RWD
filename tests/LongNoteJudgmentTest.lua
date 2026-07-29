local Core = require("core")

return {
    {
        name = "LongNoteJudgment는 누름과 뗌 시점을 함께 판정한다",
        run = function(test)
            local judgment = Core.LongNoteJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            judgment:addNote("long", 4, 6)

            local pressed = judgment:press(4.05)
            test.assertEqual(pressed.result, "GOOD")
            test.assertEqual(pressed.phase, "PRESS")
            local released = judgment:release(6.08)
            test.assertEqual(released.result, "GOOD")
            test.assertEqual(released.phase, "RELEASE")
            test.assertEqual(released.noteId, "long")
        end,
    },
    {
        name = "LongNoteJudgment는 BAD 시작 또는 종료를 최종 BAD로 판정한다",
        run = function(test)
            local judgment = Core.LongNoteJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            judgment:addNote("long", 2, 3)

            test.assertEqual(judgment:press(2.2).result, "BAD")
            test.assertEqual(judgment:release(3.05).result, "BAD")
        end,
    },
    {
        name = "LongNoteJudgment는 지나친 시작과 종료를 MISS 처리한다",
        run = function(test)
            local missedStart = Core.LongNoteJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            missedStart:addNote("start", 1, 2)
            local startResults = missedStart:update(1.3)
            test.assertEqual(startResults[1].result, "MISS")
            test.assertEqual(startResults[1].phase, "PRESS")

            local missedEnd = Core.LongNoteJudgment.new({
                goodWindowBeats = 0.1,
                badWindowBeats = 0.25,
            })
            missedEnd:addNote("end", 3, 4)
            missedEnd:press(3)
            local endResults = missedEnd:update(4.3)
            test.assertEqual(endResults[1].result, "MISS")
            test.assertEqual(endResults[1].phase, "RELEASE")
        end,
    },
}
