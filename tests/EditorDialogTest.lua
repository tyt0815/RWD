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
    function graphics.getFont()
        return {
            getWidth = function(_, text)
                return #text * 8
            end,
        }
    end

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
            test.assertEqual(#layout.selectorBoxes, 1)
            test.assertEqual(layout.selectorBoxes[1].label, "Alpha")
            test.assertEqual(#layout.selectorOptions, 0)

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
            local dialog = EditorDialog.saveAs("copy", "Copy")
            dialog:textinput("가")
            test.assertEqual(dialog:getValue("stageId"), "copy가")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("stageId"), "copy")
            dialog:textinput("5")
            test.assertEqual(dialog:getValue("stageId"), "copy5")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("stageId"), "copy")
        end,
    },
    {
        name = "Dialog 입력은 UTF-8 커서 중간 편집과 깜빡임을 처리한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.saveAs("가나", "Copy")

            dialog:keypressed("left")
            dialog:textinput("X")
            test.assertEqual(dialog:getValue("stageId"), "가X나")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("stageId"), "가나")
            dialog:keypressed("delete")
            test.assertEqual(dialog:getValue("stageId"), "가")

            local field = dialog:getLayout(1000, 700).fields[1]
            test.assertEqual(field.cursorVisible, true)
            withGraphicsRecorder(function(recorder)
                dialog:draw(1000, 700)
                local cursorCount = 0
                for _, rectangle in ipairs(recorder.rectangles) do
                    if rectangle.mode == "fill"
                        and rectangle.width == 1
                        and rectangle.height == field.height - 12 then
                        cursorCount = cursorCount + 1
                    end
                end
                test.assertEqual(cursorCount, 1)
            end)

            dialog:update(0.51)
            field = dialog:getLayout(1000, 700).fields[1]
            test.assertEqual(field.cursorVisible, false)
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
            local stageBox = findRect(layout.selectorBoxes, "selectorId", "stageId")
            test.assertEqual(clickCenter(dialog, stageBox), true)
            layout = dialog:getLayout(1000, 700)
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
        name = "Music 모달은 None과 파일 목록을 순서대로 표시하고 현재 값을 선택한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.music({
                "assets/audio/a.ogg",
                "assets/audio/b.wav",
            }, "assets/audio/b.wav")

            test.assertEqual(dialog:getKind(), "music")
            test.assertEqual(dialog.title, "Select Music")
            test.assertEqual(dialog.selectors[1].id, "music")
            test.assertEqual(dialog.selectors[1].options[1].value, "")
            test.assertEqual(dialog.selectors[1].options[1].label, "None")
            test.assertEqual(dialog.selectors[1].options[2].value, "assets/audio/a.ogg")
            test.assertEqual(dialog.selectors[1].options[2].label, "assets/audio/a.ogg")
            test.assertEqual(dialog.selectors[1].options[3].value, "assets/audio/b.wav")
            test.assertEqual(dialog.selectors[1].options[3].label, "assets/audio/b.wav")
            test.assertEqual(dialog:getSelection("music"), "assets/audio/b.wav")

            local layout = dialog:getLayout(1000, 700)
            local musicBox = findRect(layout.selectorBoxes, "selectorId", "music")
            test.assertEqual(clickCenter(dialog, musicBox), true)
            layout = dialog:getLayout(1000, 700)
            test.assertEqual(layout.selectorBoxes[1].label, "")
            test.assertEqual(layout.comboSearch, nil)

            dialog:textinput("a.ogg")
            layout = dialog:getLayout(1000, 700)
            test.assertEqual(layout.selectorBoxes[1].label, "a.ogg")
            test.assertEqual(#layout.selectorOptions, 1)
            test.assertEqual(layout.selectorOptions[1].label, "assets/audio/a.ogg")
            withGraphicsRecorder(function(recorder)
                dialog:draw(1000, 700)
                local cursorCount = 0
                for _, rectangle in ipairs(recorder.rectangles) do
                    if rectangle.mode == "fill" and rectangle.width == 1 then
                        cursorCount = cursorCount + 1
                    end
                end
                test.assertEqual(cursorCount, 1)
            end)
            test.assertEqual(clickCenter(dialog, layout.selectorOptions[1]), true)
            test.assertEqual(dialog:getSelection("music"), "assets/audio/a.ogg")
        end,
    },
    {
        name = "Music 모달은 Apply 선택을 반환하고 Escape는 취소한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.music({ "assets/audio/a.ogg" }, nil)
            test.assertEqual(dialog:getSelection("music"), "")
            test.assertTrue(dialog:select("music", "assets/audio/a.ogg"))

            dialog:keypressed("return")
            local result = dialog:consumeResult()
            test.assertEqual(result.buttonId, "confirm")
            test.assertEqual(result.selections.music, "assets/audio/a.ogg")

            local cancelDialog = EditorDialog.music({}, nil)
            cancelDialog:keypressed("escape")
            test.assertEqual(cancelDialog:consumeResult().buttonId, "cancel")
        end,
    },
    {
        name = "긴 Music 목록은 버튼과 겹치지 않고 키보드로 끝까지 이동한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local files = {}
            for index = 1, 9 do
                files[index] = "assets/audio/" .. index .. ".ogg"
            end
            local dialog = EditorDialog.music(files, nil)
            local layout = dialog:getLayout(1000, 700)
            test.assertEqual(#layout.selectorOptions, 0)
            test.assertEqual(clickCenter(dialog, layout.selectorBoxes[1]), true)
            layout = dialog:getLayout(1000, 700)
            test.assertEqual(#layout.selectorOptions, 6)

            for _ = 1, 9 do
                dialog:keypressed("down")
            end
            layout = dialog:getLayout(1000, 700)
            test.assertEqual(layout.selectorOptions[6].optionIndex, 10)
            dialog:keypressed("return")
            test.assertEqual(dialog:getSelection("music"), files[9])

            layout = dialog:getLayout(1000, 700)
            local confirm = findRect(layout.buttons, "buttonId", "confirm")
            test.assertEqual(clickCenter(dialog, confirm), true)
            local result = dialog:consumeResult()
            test.assertEqual(result.buttonId, "confirm")
            test.assertEqual(result.selections.music, files[9])
        end,
    },
    {
        name = "Enter는 기본 버튼 결과를 만들고 Escape는 cancel 또는 OK 결과를 만든다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local enterDialog = EditorDialog.saveAs("copy", "Copy")
            enterDialog:keypressed("return")
            local enterResult = enterDialog:consumeResult()
            test.assertEqual(enterResult.buttonId, "confirm")
            test.assertEqual(enterResult.values.stageId, "copy")
            test.assertEqual(enterDialog:consumeResult(), nil)

            local escapeDialog = EditorDialog.saveAs("copy", "Copy")
            escapeDialog:keypressed("escape")
            test.assertEqual(escapeDialog:consumeResult().buttonId, "cancel")

            local errorDialog = EditorDialog.error("failed")
            test.assertEqual(errorDialog:getKind(), "error")
            errorDialog:keypressed("escape")
            test.assertEqual(errorDialog:consumeResult().buttonId, "ok")

            local mouseDialog = EditorDialog.saveAs("copy", "Copy")
            local layout = mouseDialog:getLayout(1000, 700)
            local confirm = findRect(layout.buttons, "buttonId", "confirm")
            test.assertEqual(clickCenter(mouseDialog, confirm), true)
            local mouseResult = mouseDialog:consumeResult()
            test.assertEqual(mouseResult.buttonId, "confirm")
            test.assertEqual(mouseResult.values.stageId, "copy")
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
