return {
    {
        name = "StageRuntime은 시작 beat까지 Event 상태를 복원한다",
        run = function(test)
            local Core = require("core")
            local runtime = Core.StageRuntime.new()
            local occurrences = assert(runtime:start({
                events = {
                    { id = "spawn", type = "projectEvent", eventId = "spawn", startBeat = 0 },
                    { id = "disable", type = "setInputEnabled", enabled = false, startBeat = 2 },
                    { id = "future", type = "projectEvent", eventId = "future", startBeat = 4 },
                },
            }, 3))

            test.assertEqual(#occurrences, 2)
            test.assertEqual(occurrences[1].event.id, "spawn")
            test.assertEqual(occurrences[1].catchUp, true)
            test.assertEqual(runtime:isInputEnabled(), false)
            test.assertEqual(runtime:isEnded(), false)
        end,
    },
    {
        name = "StageRuntime은 건너간 Project Event를 순서대로 한 번 실행한다",
        run = function(test)
            local Core = require("core")
            local runtime = Core.StageRuntime.new()
            assert(runtime:start({
                events = {
                    { id = "second", type = "projectEvent", startBeat = 2 },
                    { id = "first", type = "projectEvent", startBeat = 1 },
                },
            }, 0))

            local occurrences = assert(runtime:update(2.5))
            test.assertEqual(#occurrences, 2)
            test.assertEqual(occurrences[1].event.id, "first")
            test.assertEqual(occurrences[2].event.id, "second")
            test.assertEqual(occurrences[1].catchUp, false)
            test.assertEqual(#assert(runtime:update(3)), 0)
        end,
    },
    {
        name = "StageRuntime은 End beat에서 종료하고 이후 Event를 실행하지 않는다",
        run = function(test)
            local Core = require("core")
            local runtime = Core.StageRuntime.new()
            assert(runtime:start({
                events = {
                    { id = "disable", type = "setInputEnabled", enabled = false, startBeat = 2 },
                    { id = "end", type = "end", startBeat = 3 },
                    { id = "after", type = "projectEvent", startBeat = 4 },
                },
            }, 0))

            local occurrences = assert(runtime:update(5))
            test.assertEqual(#occurrences, 2)
            test.assertEqual(runtime:isInputEnabled(), false)
            test.assertEqual(runtime:isEnded(), true)
            test.assertEqual(runtime:getEndBeat(), 3)
            test.assertEqual(runtime:getCurrentBeat(), 3)
            test.assertEqual(#assert(runtime:update(6)), 0)
        end,
    },
    {
        name = "StageRuntime은 beat 역행을 거부한다",
        run = function(test)
            local Core = require("core")
            local runtime = Core.StageRuntime.new()
            assert(runtime:start({ events = {} }, 2))

            local occurrences, errorMessage = runtime:update(1)

            test.assertEqual(occurrences, nil)
            test.assertContains(errorMessage, "backwards")
        end,
    },
}
