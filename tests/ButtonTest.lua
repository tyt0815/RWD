return {
    {
        name = "Core UI Button은 활성 좌클릭만 hit test한다",
        run = function(test)
            local Button = require("core").UI.Button
            local button = Button.new({
                id = "apply",
                label = "Apply",
                enabled = true,
            })
            local rect = { x = 10, y = 20, width = 80, height = 24 }

            test.assertEqual(button.id, "apply")
            test.assertEqual(button.label, "Apply")
            test.assertEqual(button:hitTest(rect, 10, 20, 1), true)
            test.assertEqual(button:hitTest(rect, 90, 20, 1), false)
            test.assertEqual(button:hitTest(rect, 20, 30, 2), false)

            button:setEnabled(false)
            test.assertEqual(button:contains(rect, 20, 30), true)
            test.assertEqual(button:hitTest(rect, 20, 30, 1), false)
        end,
    },
}
