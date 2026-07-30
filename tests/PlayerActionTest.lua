local Core = require("core")

return {
    {
        name = "PlayerAction은 ms 임계값 전에 떼면 최초 press beat의 Tap을 만든다",
        run = function(test)
            local actions = Core.PlayerAction.new({ longHoldThresholdMs = 100 })

            test.assertEqual(actions:press(12), true)
            test.assertEqual(actions:update(0.099), nil)
            local action = actions:release(12.4)

            test.assertEqual(action.type, "TAP")
            test.assertNear(action.pressBeat, 12, 0.000001)
            test.assertNear(action.releaseBeat, 12.4, 0.000001)
        end,
    },
    {
        name = "PlayerAction은 ms 임계값에서 Long Start를 한 번 만들고 뗄 때 Long Release를 만든다",
        run = function(test)
            local actions = Core.PlayerAction.new({ longHoldThresholdMs = 100 })

            actions:press(20)
            test.assertEqual(actions:update(0.05), nil)
            local started = actions:update(0.05)
            test.assertEqual(started.type, "LONG_START")
            test.assertNear(started.pressBeat, 20, 0.000001)
            test.assertEqual(actions:update(1), nil)

            local released = actions:release(24)
            test.assertEqual(released.type, "LONG_RELEASE")
            test.assertNear(released.pressBeat, 20, 0.000001)
            test.assertNear(released.releaseBeat, 24, 0.000001)
        end,
    },
}
