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
    {
        name = "Editor Menu와 Dialog의 명시적 버튼은 Core UI Button을 사용한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local EditorDialog = require("editor.ui.EditorDialog")
            local session = {
                hasStage = function() return false end,
                isPlaying = function() return false end,
                isDirty = function() return false end,
            }

            test.assertTrue(type(EditorMenu.getItems(session)[1].hitTest) == "function")
            test.assertTrue(type(EditorDialog.error("error").buttons[1].hitTest) == "function")
        end,
    },
}
