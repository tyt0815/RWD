local TextInput = require("core.ui.TextInput")

local ComboBox = {}
ComboBox.__index = ComboBox

local DEFAULT_VISIBLE_OPTIONS = 6

local function copyOptions(options)
    local copy = {}
    for _, option in ipairs(options or {}) do
        table.insert(copy, {
            value = option.value,
            label = tostring(option.label),
        })
    end
    return copy
end

function ComboBox.new(options, config)
    config = config or {}
    local self = setmetatable({
        options = {},
        selectedIndex = 0,
        opened = false,
        queryInput = TextInput.new(""),
        filteredIndices = {},
        highlightedPosition = 0,
        scrollOffset = 0,
        maxVisibleOptions = config.maxVisibleOptions or DEFAULT_VISIBLE_OPTIONS,
    }, ComboBox)
    self:setOptions(options)
    return self
end

function ComboBox:refreshFilter()
    local query = self.queryInput:getText():lower()
    self.filteredIndices = {}
    for optionIndex, option in ipairs(self.options) do
        if query == "" or option.label:lower():find(query, 1, true) then
            table.insert(self.filteredIndices, optionIndex)
        end
    end

    self.highlightedPosition = #self.filteredIndices > 0 and 1 or 0
    for position, optionIndex in ipairs(self.filteredIndices) do
        if optionIndex == self.selectedIndex then
            self.highlightedPosition = position
            break
        end
    end
    self:ensureHighlightVisible()
end

function ComboBox:ensureHighlightVisible()
    if self.highlightedPosition == 0 then
        self.scrollOffset = 0
    elseif self.highlightedPosition <= self.scrollOffset then
        self.scrollOffset = self.highlightedPosition - 1
    elseif self.highlightedPosition > self.scrollOffset + self.maxVisibleOptions then
        self.scrollOffset = self.highlightedPosition - self.maxVisibleOptions
    end
end

function ComboBox:setOptions(options)
    self.options = copyOptions(options)
    self.selectedIndex = #self.options > 0 and 1 or 0
    self.queryInput:setText("")
    self:refreshFilter()
end

function ComboBox:getValue()
    local option = self.options[self.selectedIndex]
    return option and option.value or nil
end

function ComboBox:getLabel()
    local option = self.options[self.selectedIndex]
    return option and option.label or ""
end

function ComboBox:select(value)
    for optionIndex, option in ipairs(self.options) do
        if option.value == value then
            self.selectedIndex = optionIndex
            self:refreshFilter()
            return true
        end
    end
    return false
end

function ComboBox:isOpen()
    return self.opened
end

function ComboBox:open()
    self.opened = true
    self.queryInput:setText("")
    self:refreshFilter()
end

function ComboBox:close()
    self.opened = false
end

function ComboBox:toggle()
    if self.opened then self:close() else self:open() end
end

function ComboBox:textinput(text)
    if not self.opened then return false end
    if self.queryInput:textinput(text) then
        self:refreshFilter()
        return true
    end
    return false
end

function ComboBox:chooseOption(optionIndex)
    if not self.options[optionIndex] then return false end
    self.selectedIndex = optionIndex
    self:close()
    return true
end

function ComboBox:getVisibleOptions(maxVisibleOptions)
    if maxVisibleOptions then
        self.maxVisibleOptions = maxVisibleOptions
        self:ensureHighlightVisible()
    end
    local visible = {}
    local lastPosition = math.min(
        #self.filteredIndices,
        self.scrollOffset + self.maxVisibleOptions
    )
    for position = self.scrollOffset + 1, lastPosition do
        local optionIndex = self.filteredIndices[position]
        local option = self.options[optionIndex]
        table.insert(visible, {
            value = option.value,
            label = option.label,
            optionIndex = optionIndex,
            highlighted = position == self.highlightedPosition,
            selected = optionIndex == self.selectedIndex,
        })
    end
    return visible
end

function ComboBox:keypressed(key)
    if not self.opened then return false end

    if key == "up" or key == "down" then
        if #self.filteredIndices > 0 then
            local direction = key == "up" and -1 or 1
            self.highlightedPosition = math.max(1, math.min(
                #self.filteredIndices,
                self.highlightedPosition + direction
            ))
            self:ensureHighlightVisible()
        end
        return true
    elseif key == "return" or key == "kpenter" then
        local optionIndex = self.filteredIndices[self.highlightedPosition]
        if optionIndex then
            self:chooseOption(optionIndex)
            return "selected"
        end
        return true
    elseif key == "escape" then
        self:close()
        return "closed"
    elseif self.queryInput:keypressed(key) then
        self:refreshFilter()
        return true
    end
    return false
end

function ComboBox:update(deltaTime)
    if self.opened then self.queryInput:update(deltaTime) end
end

return ComboBox
