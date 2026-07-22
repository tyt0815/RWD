local PROJECTS = {
    { id = "alpha", title = "Alpha" },
    { id = "sample", title = "Sample" },
}

local function findRect(rects, key, value)
    for _, rect in ipairs(rects) do
        if rect[key] == value then
            return rect
        end
    end
    return nil
end

local function clickCenter(dialog, rect)
    return dialog:mousepressed(
        rect.x + rect.width / 2,
        rect.y + rect.height / 2
    )
end

local function withGraphicsRecorder(run)
    local previousLove = _G.love
    local currentColor = { 1, 1, 1, 1 }
    local recorder = { rectangles = {} }
    local graphics = {}

    function graphics.push() end
    function graphics.pop() end
    function graphics.print() end
    function graphics.printf() end

    function graphics.setColor(red, green, blue, alpha)
        currentColor = { red, green, blue, alpha }
    end

    function graphics.rectangle(mode, x, y, width, height)
        table.insert(recorder.rectangles, {
            mode = mode,
            x = x,
            y = y,
            width = width,
            height = height,
            color = currentColor,
        })
    end

    _G.love = { graphics = graphics }
    local succeeded, errorMessage = xpcall(function()
        run(recorder)
    end, debug.traceback)
    _G.love = previousLove

    if not succeeded then
        error(errorMessage, 0)
    end
end

return {
    {
        name = "New Stage 모달은 Project와 세 입력값을 가진다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.newStage(PROJECTS)
            test.assertEqual(dialog:getKind(), "newStage")
            test.assertEqual(dialog:getSelection("projectId"), "alpha")
            test.assertEqual(dialog:getValue("bpm"), "120")

            local layout = dialog:getLayout(1000, 700)
            test.assertEqual(layout.modal.x, 220)
            test.assertEqual(layout.modal.y, 140)
            test.assertEqual(layout.modal.width, 560)
            test.assertEqual(layout.modal.height, 420)

            withGraphicsRecorder(function(recorder)
                dialog:draw(1000, 700)
                local backdrop = recorder.rectangles[1]
                test.assertEqual(backdrop.mode, "fill")
                test.assertEqual(backdrop.x, 0)
                test.assertEqual(backdrop.y, 0)
                test.assertEqual(backdrop.width, 1000)
                test.assertEqual(backdrop.height, 700)
                test.assertEqual(backdrop.color[4], 0.65)
            end)

            local saveAs = EditorDialog.saveAs("copy", "Copy")
            test.assertEqual(saveAs:getKind(), "saveAs")
            test.assertEqual(saveAs:getValue("stageId"), "copy")
            test.assertEqual(saveAs:getValue("name"), "Copy")
        end,
    },
    {
        name = "활성 입력 필드는 textinput과 UTF-8 Backspace를 처리한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.editBpm(120)
            dialog:textinput("가")
            test.assertEqual(dialog:getValue("bpm"), "120가")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("bpm"), "120")
            dialog:textinput("5")
            test.assertEqual(dialog:getValue("bpm"), "1205")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("bpm"), "120")
        end,
    },
    {
        name = "Tab과 마우스는 활성 텍스트 입력 필드를 이동한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.newStage(PROJECTS)
            test.assertEqual(dialog:getFocusedFieldId(), "stageId")
            dialog:keypressed("tab")
            test.assertEqual(dialog:getFocusedFieldId(), "name")

            local layout = dialog:getLayout(1000, 700)
            local bpmField = findRect(layout.fields, "fieldId", "bpm")
            test.assertTrue(bpmField ~= nil)
            test.assertEqual(clickCenter(dialog, bpmField), true)
            test.assertEqual(dialog:getFocusedFieldId(), "bpm")
            dialog:textinput("5")
            test.assertEqual(dialog:getValue("bpm"), "1205")
            test.assertEqual(dialog:mousepressed(0, 0), true)
            test.assertEqual(dialog:getFocusedFieldId(), "bpm")
        end,
    },
    {
        name = "Open Stage selector option을 교체하고 선택할 수 있다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.openStage(PROJECTS, { "one" })
            test.assertEqual(dialog:setSelectorOptions("stageId", {
                { value = "one", label = "one" },
                { value = "two", label = "two" },
            }), true)
            local layout = dialog:getLayout(1000, 700)
            local secondStageOption
            for _, rect in ipairs(layout.selectorOptions) do
                if rect.selectorId == "stageId" and rect.optionIndex == 2 then
                    secondStageOption = rect
                end
            end
            test.assertTrue(secondStageOption ~= nil)
            test.assertEqual(clickCenter(dialog, secondStageOption), true)
            test.assertEqual(dialog:getSelection("stageId"), "two")
            test.assertEqual(dialog:setSelectorOptions("missing", {}), false)
        end,
    },
    {
        name = "Enter는 기본 버튼 결과를 만들고 Escape는 cancel 또는 OK 결과를 만든다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local enterDialog = EditorDialog.editBpm(120)
            enterDialog:keypressed("return")
            local enterResult = enterDialog:consumeResult()
            test.assertEqual(enterResult.buttonId, "confirm")
            test.assertEqual(enterResult.values.bpm, "120")
            test.assertEqual(enterDialog:consumeResult(), nil)

            local escapeDialog = EditorDialog.editBpm(120)
            escapeDialog:keypressed("escape")
            test.assertEqual(escapeDialog:consumeResult().buttonId, "cancel")

            local errorDialog = EditorDialog.error("failed")
            test.assertEqual(errorDialog:getKind(), "error")
            errorDialog:keypressed("escape")
            test.assertEqual(errorDialog:consumeResult().buttonId, "ok")

            local mouseDialog = EditorDialog.editBpm(135)
            local layout = mouseDialog:getLayout(1000, 700)
            local confirm = findRect(layout.buttons, "buttonId", "confirm")
            test.assertEqual(clickCenter(mouseDialog, confirm), true)
            local mouseResult = mouseDialog:consumeResult()
            test.assertEqual(mouseResult.buttonId, "confirm")
            test.assertEqual(mouseResult.values.bpm, "135")
        end,
    },
    {
        name = "Unsaved 모달은 Save Discard Cancel 결과를 구분한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            for _, buttonId in ipairs({ "save", "discard", "cancel" }) do
                local dialog = EditorDialog.unsaved("quit")
                local layout = dialog:getLayout(1000, 700)
                local button = findRect(layout.buttons, "buttonId", buttonId)
                test.assertTrue(button ~= nil)
                test.assertEqual(clickCenter(dialog, button), true)
                local result = dialog:consumeResult()
                test.assertEqual(result.buttonId, buttonId)
                test.assertEqual(result.context.pendingAction, "quit")
            end

            local payload = { projectId = "alpha", stageId = "one" }
            local overwrite = EditorDialog.overwrite(payload)
            test.assertEqual(overwrite:getKind(), "overwrite")
            overwrite:submit("confirm")
            local result = overwrite:consumeResult()
            test.assertEqual(result.buttonId, "confirm")
            test.assertEqual(result.context, payload)
        end,
    },
}
