return {
    {
        name = "Timeline Event geometry는 기본 0.25박과 가변 길이를 계산한다",
        run = function(test)
            local Geometry = require("editor.timeline.TimelineEventGeometry")
            test.assertEqual(Geometry.getWidthBeats({ type = "end" }), 0.25)
            test.assertEqual(
                Geometry.getWidthBeats({ type = "setInputEnabled" }),
                0.25
            )
            test.assertEqual(Geometry.getWidthBeats({ type = "gameplay" }), 1)
            test.assertEqual(Geometry.getWidthBeats({ widthBeats = 2 }), 2)
            test.assertEqual(Geometry.getWidthBeats({ durationBeats = 1 }), 1)
            test.assertEqual(Geometry.getWidthBeats({ durationBeats = 4 }), 4)
        end,
    },
    {
        name = "Timeline Event 충돌은 같은 Track의 가변 beat 영역 겹침을 판정한다",
        run = function(test)
            local Geometry = require("editor.timeline.TimelineEventGeometry")
            local collisions = Geometry.findCollisionIds({
                { id = "wide", startBeat = 4, track = 2, durationBeats = 4 },
                { id = "inside", type = "end", startBeat = 7.5, track = 2 },
                { id = "adjacent", startBeat = 8, track = 2, durationBeats = 1 },
                { id = "other-track", startBeat = 5, track = 3, durationBeats = 4 },
            })
            test.assertEqual(collisions.wide, true)
            test.assertEqual(collisions.inside, true)
            test.assertEqual(collisions.adjacent, nil)
            test.assertEqual(collisions["other-track"], nil)
        end,
    },
}
