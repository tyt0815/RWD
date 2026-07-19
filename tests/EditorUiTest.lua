local function sessionState(values)
    values = values or {}
    return {
        hasStage = function() return values.hasStage == true end,
        isDirty = function() return values.dirty == true end,
        isPlaying = function() return values.playing == true end,
    }
end

return {
    {
        name = "Menu는 요청한 일곱 항목만 순서대로 제공한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            local labels = { "New", "Open", "Save", "Save As", "Play", "Pause", "Quit" }
            test.assertEqual(#items, #labels)
            for index, label in ipairs(labels) do
                test.assertEqual(items[index].label, label)
            end
        end,
    },
    {
        name = "Stage가 없으면 저장과 재생 항목이 비활성화된다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            test.assertEqual(items[3].enabled, false)
            test.assertEqual(items[4].enabled, false)
            test.assertEqual(items[5].enabled, false)
            test.assertEqual(items[6].enabled, false)
        end,
    },
    {
        name = "dirty Stage는 Save 별표를 표시한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState({ hasStage = true, dirty = true }))
            test.assertEqual(items[3].label, "Save*")
        end,
    },
    {
        name = "Play와 Pause 활성 상태는 재생 여부에 따라 교대한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local stopped = EditorMenu.getItems(sessionState({ hasStage = true }))
            local playing = EditorMenu.getItems(sessionState({ hasStage = true, playing = true }))
            test.assertEqual(stopped[5].enabled, true)
            test.assertEqual(stopped[6].enabled, false)
            test.assertEqual(playing[5].enabled, false)
            test.assertEqual(playing[6].enabled, true)
        end,
    },
    {
        name = "Menu hit test는 클릭한 활성 항목을 반환한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local panel = { x = 0, y = 0, width = 180, height = 360 }
            local items = EditorMenu.getItems(sessionState())
            local item = EditorMenu.hitTest(panel, items, 20, 44)
            test.assertEqual(item.action, "new")
        end,
    },
    {
        name = "Properties와 Values 합친 영역과 BPM Value 영역을 계산한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)
            local preview = EditorLayout.getPreviewRect(layout)
            local bpm = EditorLayout.getBpmValueRect(layout)
            test.assertEqual(preview.x, layout.panels[4].x)
            test.assertEqual(preview.width, layout.panels[4].width + layout.panels[5].width)
            test.assertEqual(bpm.x, layout.panels[5].x)
            test.assertEqual(bpm.y, 32)
        end,
    },
}
