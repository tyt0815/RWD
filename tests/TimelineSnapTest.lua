return {
    {
        name = "TimelineSnap은 beat를 지정한 간격의 가장 가까운 위치에 맞춘다",
        run = function(test)
            local TimelineSnap = require("editor.timeline.TimelineSnap")

            test.assertEqual(TimelineSnap.snapBeat(0.4, 1), 0)
            test.assertEqual(TimelineSnap.snapBeat(0.38, 0.25), 0.5)
            test.assertEqual(TimelineSnap.snapBeat(0.5, 1), 1)
            test.assertEqual(TimelineSnap.snapBeat(5.9, 4), 4)
            test.assertEqual(TimelineSnap.snapBeat(6, 4), 8)
            test.assertEqual(TimelineSnap.snapBeat(-2, 4), 0)
        end,
    },
    {
        name = "Timeline Event는 Snap 크기의 셀 시작 위치에 맞춘다",
        run = function(test)
            local TimelineSnap = require("editor.timeline.TimelineSnap")

            test.assertEqual(TimelineSnap.snapEventBeat(0.9, 1), 0)
            test.assertEqual(TimelineSnap.snapEventBeat(0.9, 0.5), 0.5)
            test.assertEqual(TimelineSnap.snapEventBeat(0.9, 0.25), 0.75)
            test.assertNear(TimelineSnap.snapEventBeat(0.3, 0.1), 0.3, 0.000001)
            test.assertNear(TimelineSnap.snapEventBeat(0.3 - 0.000001, 0.1), 0.2, 0.000001)
            test.assertEqual(TimelineSnap.snapEventBeat(1, 1), 1)
            test.assertEqual(TimelineSnap.snapEventBeat(5.9, 4), 4)
            test.assertEqual(TimelineSnap.snapEventBeat(7.9, 4), 4)
            test.assertEqual(TimelineSnap.snapEventBeat(8, 4), 8)
            test.assertEqual(TimelineSnap.snapEventBeat(-2, 4), 0)
        end,
    },
}
