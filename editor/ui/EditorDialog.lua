local Core = require("core")

local ComboBox = Core.UI.ComboBox
local Button = Core.UI.Button
local TextInput = Core.UI.TextInput

local EditorDialog = {}
EditorDialog.__index = EditorDialog

local MODAL_WIDTH = 560
local MODAL_HEIGHT = 420
local PADDING = 24
local LABEL_WIDTH = 120
local ROW_HEIGHT = 32
local OPTION_HEIGHT = 28
local ROW_GAP = 8
local MUSIC_VISIBLE_OPTIONS = 6

local function projectOptions(projects)
    local options = {}
    for _, project in ipairs(projects) do
        table.insert(options, { value = project.id, label = project.title })
    end
    return options
end

local function stringOptions(values)
    local options = {}
    for _, value in ipairs(values) do
        table.insert(options, { value = value, label = value })
    end
    return options
end

local function newDialog(config)
    config.fields = config.fields or {}
    config.selectors = config.selectors or {}
    config.buttons = config.buttons or {}
    config.focusedFieldIndex = #config.fields > 0 and 1 or nil
    for selectorIndex, selector in ipairs(config.selectors) do
        local selectedValue = selector.options[selector.selectedIndex or 1]
        selectedValue = selectedValue and selectedValue.value or nil
        local comboBox = ComboBox.new(selector.options, {
            maxVisibleOptions = selector.maxVisibleOptions,
        })
        comboBox.id = selector.id
        comboBox.label = selector.label
        if selectedValue ~= nil then comboBox:select(selectedValue) end
        config.selectors[selectorIndex] = comboBox
    end
    for _, field in ipairs(config.fields) do
        field.input = TextInput.new(field.value)
        field.value = nil
    end
    for buttonIndex, button in ipairs(config.buttons) do
        config.buttons[buttonIndex] = Button.new(button)
    end
    config.result = nil
    return setmetatable(config, EditorDialog)
end

local function contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width
        and y >= rect.y and y < rect.y + rect.height
end

function EditorDialog.newStage(projects)
    return newDialog({
        kind = "newStage",
        title = "New Stage",
        selectors = {
            {
                id = "projectId",
                label = "Project",
                options = projectOptions(projects),
                selectedIndex = 1,
            },
        },
        fields = {
            { id = "stageId", label = "Stage ID", value = "" },
            { id = "name", label = "Name", value = "" },
            { id = "bpm", label = "BPM", value = "120" },
        },
        buttons = {
            { id = "confirm", label = "Create", default = true },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.openStage(projects, stageIds)
    return newDialog({
        kind = "openStage",
        title = "Open Stage",
        selectors = {
            {
                id = "projectId",
                label = "Project",
                options = projectOptions(projects),
                selectedIndex = 1,
            },
            {
                id = "stageId",
                label = "Stage",
                options = stringOptions(stageIds),
                selectedIndex = 1,
            },
        },
        buttons = {
            { id = "confirm", label = "Open", default = true },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.music(files, currentMusic)
    local options = {
        { value = "", label = "None" },
    }
    local selectedIndex = 1
    for _, file in ipairs(files) do
        table.insert(options, { value = file, label = file })
        if file == currentMusic then
            selectedIndex = #options
        end
    end

    return newDialog({
        kind = "music",
        title = "Select Music",
        selectors = {
            {
                id = "music",
                label = "Music",
                options = options,
                selectedIndex = selectedIndex,
                maxVisibleOptions = MUSIC_VISIBLE_OPTIONS,
                scrollOffset = math.max(0, selectedIndex - MUSIC_VISIBLE_OPTIONS),
            },
        },
        buttons = {
            { id = "confirm", label = "Apply", default = true },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.saveAs(stageId, name)
    return newDialog({
        kind = "saveAs",
        title = "Save As",
        fields = {
            { id = "stageId", label = "Stage ID", value = stageId },
            { id = "name", label = "Name", value = name },
        },
        buttons = {
            { id = "confirm", label = "Save", default = true },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.unsaved(pendingAction)
    return newDialog({
        kind = "unsaved",
        title = "Unsaved Changes",
        message = "Save changes before continuing?",
        context = { pendingAction = pendingAction },
        buttons = {
            { id = "save", label = "Save", default = true },
            { id = "discard", label = "Discard" },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.overwrite(payload)
    return newDialog({
        kind = "overwrite",
        title = "Confirm Overwrite",
        message = "Stage already exists. Overwrite it?",
        context = payload,
        buttons = {
            { id = "confirm", label = "Overwrite", default = true },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.error(message)
    return newDialog({
        kind = "error",
        title = "Error",
        message = tostring(message),
        buttons = {
            { id = "ok", label = "OK", default = true, cancel = true },
        },
    })
end

function EditorDialog:getKind()
    return self.kind
end

function EditorDialog:getFocusedFieldId()
    local field = self.focusedFieldIndex and self.fields[self.focusedFieldIndex]
    return field and field.id or nil
end

function EditorDialog:getValue(fieldId)
    for _, field in ipairs(self.fields) do
        if field.id == fieldId then
            return field.input:getText()
        end
    end
    return nil
end

function EditorDialog:setValue(fieldId, value)
    for _, field in ipairs(self.fields) do
        if field.id == fieldId then
            field.input:setText(value)
            return true
        end
    end
    return false
end

function EditorDialog:getSelection(selectorId)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then return selector:getValue() end
    end
    return nil
end

function EditorDialog:select(selectorId, value)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then return selector:select(value) end
    end
    return false
end

function EditorDialog:setSelectorOptions(selectorId, options)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then
            selector:setOptions(options)
            return true
        end
    end
    return false
end

function EditorDialog:textinput(text)
    for _, selector in ipairs(self.selectors) do
        if selector:isOpen() then
            selector:textinput(text)
            return
        end
    end
    local field = self.focusedFieldIndex and self.fields[self.focusedFieldIndex]
    if field then field.input:textinput(text) end
end

function EditorDialog:submit(buttonId)
    local values = {}
    local selections = {}
    for _, field in ipairs(self.fields) do
        values[field.id] = field.input:getText()
    end
    for _, selector in ipairs(self.selectors) do
        selections[selector.id] = self:getSelection(selector.id)
    end
    self.result = {
        buttonId = buttonId,
        values = values,
        selections = selections,
        context = self.context or {},
    }
end

function EditorDialog:keypressed(key)
    for _, selector in ipairs(self.selectors) do
        if selector:isOpen() then
            local result = selector:keypressed(key)
            if result then return true end
        end
    end

    if self.focusedFieldIndex
        and self.fields[self.focusedFieldIndex].input:keypressed(key) then
        return true
    elseif key == "tab" and #self.fields > 0 then
        self.focusedFieldIndex = self.focusedFieldIndex % #self.fields + 1
        self.fields[self.focusedFieldIndex].input:resetCursorBlink()
        return true
    elseif key == "return" or key == "kpenter" then
        for _, button in ipairs(self.buttons) do
            if button.default then
                self:submit(button.id)
                return true
            end
        end
    elseif key == "escape" then
        for _, button in ipairs(self.buttons) do
            if button.cancel then
                self:submit(button.id)
                return true
            end
        end
    end
    return false
end

function EditorDialog:update(deltaTime)
    for _, selector in ipairs(self.selectors) do
        if selector:isOpen() then
            selector:update(deltaTime)
            return
        end
    end
    local field = self.focusedFieldIndex and self.fields[self.focusedFieldIndex]
    if field then field.input:update(deltaTime) end
end

function EditorDialog:consumeResult()
    local result = self.result
    self.result = nil
    return result
end

function EditorDialog:getLayout(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    local modal = {
        x = math.floor((width - MODAL_WIDTH) / 2),
        y = math.floor((height - MODAL_HEIGHT) / 2),
        width = MODAL_WIDTH,
        height = MODAL_HEIGHT,
    }
    local contentX = modal.x + PADDING
    local contentWidth = modal.width - PADDING * 2
    local cursorY = modal.y + 58
    local layout = {
        modal = modal,
        selectorLabels = {},
        selectorBoxes = {},
        selectorOptions = {},
        fields = {},
        buttons = {},
    }

    if self.message then
        cursorY = cursorY + 44
    end

    for selectorIndex, selector in ipairs(self.selectors) do
        table.insert(layout.selectorLabels, {
            x = contentX,
            y = cursorY + 7,
            label = selector.label,
        })
        table.insert(layout.selectorBoxes, {
            x = contentX + LABEL_WIDTH,
            y = cursorY,
            width = contentWidth - LABEL_WIDTH,
            height = ROW_HEIGHT,
            selectorIndex = selectorIndex,
            selectorId = selector.id,
            label = selector:isOpen()
                and selector.queryInput:getText()
                or selector:getLabel(),
            cursorPosition = selector.queryInput.cursorPosition,
            cursorVisible = selector.queryInput.cursorVisible,
            opened = selector:isOpen(),
        })
        if selector:isOpen() then layout.openSelectorIndex = selectorIndex end
        cursorY = cursorY + ROW_HEIGHT + ROW_GAP
    end

    for fieldIndex, field in ipairs(self.fields) do
        table.insert(layout.fields, {
            x = contentX + LABEL_WIDTH,
            y = cursorY,
            width = contentWidth - LABEL_WIDTH,
            height = ROW_HEIGHT,
            labelX = contentX,
            fieldIndex = fieldIndex,
            fieldId = field.id,
            label = field.label,
            value = field.input:getText(),
            cursorPosition = field.input.cursorPosition,
            cursorVisible = field.input.cursorVisible,
            focused = layout.openSelectorIndex == nil
                and self.focusedFieldIndex == fieldIndex,
        })
        cursorY = cursorY + ROW_HEIGHT + ROW_GAP
    end

    local buttonGap = 8
    local buttonWidth = math.floor(
        (contentWidth - buttonGap * math.max(0, #self.buttons - 1))
            / math.max(1, #self.buttons)
    )
    local buttonY = modal.y + modal.height - PADDING - ROW_HEIGHT
    for buttonIndex, button in ipairs(self.buttons) do
        table.insert(layout.buttons, {
            x = contentX + (buttonIndex - 1) * (buttonWidth + buttonGap),
            y = buttonY,
            width = buttonWidth,
            height = ROW_HEIGHT,
            buttonId = button.id,
            label = button.label,
            button = button,
        })
    end

    for selectorIndex, selector in ipairs(self.selectors) do
        if selector:isOpen() then
            local box = layout.selectorBoxes[selectorIndex]
            local optionY = box.y + box.height + 4
            local availableCount = math.max(1, math.floor((buttonY - optionY) / 32))
            local visibleOptions = selector:getVisibleOptions(math.min(
                selector.maxVisibleOptions,
                availableCount
            ))
            for _, option in ipairs(visibleOptions) do
                table.insert(layout.selectorOptions, {
                    x = box.x,
                    y = optionY,
                    width = box.width,
                    height = OPTION_HEIGHT,
                    selectorIndex = selectorIndex,
                    selectorId = selector.id,
                    optionIndex = option.optionIndex,
                    label = option.label,
                    selected = option.selected,
                    highlighted = option.highlighted,
                })
                optionY = optionY + OPTION_HEIGHT + 4
            end
            break
        end
    end

    self.lastLayout = layout
    return layout
end

function EditorDialog:mousepressed(x, y)
    local layout = self.lastLayout or self:getLayout()
    for _, rect in ipairs(layout.selectorOptions) do
        if contains(rect, x, y) then
            self.selectors[rect.selectorIndex]:chooseOption(rect.optionIndex)
            return true
        end
    end
    for _, rect in ipairs(layout.selectorBoxes) do
        if contains(rect, x, y) then
            local wasOpen = self.selectors[rect.selectorIndex]:isOpen()
            for _, selector in ipairs(self.selectors) do selector:close() end
            if not wasOpen then self.selectors[rect.selectorIndex]:open() end
            return true
        end
    end

    for _, selector in ipairs(self.selectors) do selector:close() end
    for _, rect in ipairs(layout.fields) do
        if contains(rect, x, y) then
            self.focusedFieldIndex = rect.fieldIndex
            self.fields[rect.fieldIndex].input:resetCursorBlink()
            return true
        end
    end
    for _, rect in ipairs(layout.buttons) do
        if rect.button:hitTest(rect, x, y, 1) then
            self:submit(rect.buttonId)
            return true
        end
    end
    return true
end

function EditorDialog:draw(width, height)
    local graphics = love.graphics
    local layout = self:getLayout(width, height)
    graphics.push("all")
    graphics.setColor(0, 0, 0, 0.65)
    graphics.rectangle("fill", 0, 0, width, height)
    graphics.setColor(0.13, 0.14, 0.16, 1)
    graphics.rectangle("fill", layout.modal.x, layout.modal.y, layout.modal.width, layout.modal.height)
    graphics.setColor(0.85, 0.86, 0.89, 1)
    graphics.rectangle("line", layout.modal.x, layout.modal.y, layout.modal.width, layout.modal.height)
    graphics.print(self.title, layout.modal.x + PADDING, layout.modal.y + 20)
    if self.message then
        graphics.printf(
            self.message,
            layout.modal.x + PADDING,
            layout.modal.y + 54,
            layout.modal.width - PADDING * 2,
            "left"
        )
    end

    for _, label in ipairs(layout.selectorLabels) do
        graphics.setColor(0.75, 0.77, 0.81, 1)
        graphics.print(label.label, label.x, label.y)
    end
    for _, rect in ipairs(layout.selectorBoxes) do
        graphics.setColor(0.09, 0.1, 0.12, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(rect.opened and 1 or 0.45, rect.opened and 0.55 or 0.47, 0.22, 1)
        graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.94, 0.94, 0.96, 1)
        graphics.print(rect.label, rect.x + 8, rect.y + 7)
        graphics.printf(rect.opened and "^" or "v", rect.x, rect.y + 7, rect.width - 8, "right")
        if rect.opened and rect.cursorVisible then
            local textBeforeCursor = rect.label:sub(1, rect.cursorPosition)
            local cursorX = rect.x + 8 + graphics.getFont():getWidth(textBeforeCursor)
            graphics.rectangle("fill", cursorX, rect.y + 6, 1, rect.height - 12)
        end
    end
    for _, rect in ipairs(layout.fields) do
        graphics.setColor(0.75, 0.77, 0.81, 1)
        graphics.print(rect.label, rect.labelX, rect.y + 7)
        graphics.setColor(0.09, 0.1, 0.12, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(
            rect.focused and 1 or 0.45,
            rect.focused and 0.55 or 0.47,
            0.22,
            1
        )
        graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.94, 0.94, 0.96, 1)
        graphics.print(rect.value, rect.x + 8, rect.y + 7)
        if rect.focused and rect.cursorVisible then
            local textBeforeCursor = rect.value:sub(1, rect.cursorPosition)
            local cursorX = rect.x + 8 + graphics.getFont():getWidth(textBeforeCursor)
            graphics.rectangle("fill", cursorX, rect.y + 6, 1, rect.height - 12)
        end
    end
    for _, rect in ipairs(layout.buttons) do
        graphics.setColor(0.24, 0.25, 0.29, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.92, 0.93, 0.96, 1)
        graphics.printf(rect.label, rect.x, rect.y + 7, rect.width, "center")
    end

    for _, rect in ipairs(layout.selectorOptions) do
        graphics.setColor(
            rect.highlighted and 0.31 or (rect.selected and 0.25 or 0.16),
            rect.highlighted and 0.35 or (rect.selected and 0.29 or 0.17),
            rect.highlighted and 0.42 or (rect.selected and 0.34 or 0.2),
            1
        )
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.92, 0.93, 0.96, 1)
        graphics.print(rect.label, rect.x + 8, rect.y + 6)
    end
    graphics.pop()
end

return EditorDialog
