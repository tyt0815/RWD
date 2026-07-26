return {
    {
        name = "TimelineSnap은 beat를 지정한 정수 간격의 가장 가까운 위치에 맞춘다",
        run = function(test)
            local TimelineSnap = require("editor.timeline.TimelineSnap")

            test.assertEqual(TimelineSnap.snapBeat(0.4, 1), 0)
            test.assertEqual(TimelineSnap.snapBeat(0.5, 1), 1)
            test.assertEqual(TimelineSnap.snapBeat(5.9, 4), 4)
            test.assertEqual(TimelineSnap.snapBeat(6, 4), 8)
            test.assertEqual(TimelineSnap.snapBeat(-2, 4), 0)
        end,
    },
}
