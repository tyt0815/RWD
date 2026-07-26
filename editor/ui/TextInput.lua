local utf8 = require("utf8")

local TextInput = {}
TextInput.__index = TextInput

local CURSOR_BLINK_INTERVAL = 0.5

local function previousCursorPosition(text, cursorPosition)
    if cursorPosition == 0 then return 0 end
    local byteIndex = utf8.offset(text, -1, cursorPosition + 1)
    return byteIndex and byteIndex - 1 or 0
end

local function nextCursorPosition(text, cursorPosition)
    if cursorPosition >= #text then return #text end
    local byteIndex = utf8.offset(text, 2, cursorPosition + 1)
    return byteIndex and byteIndex - 1 or #text
end

function TextInput.new(text, options)
    options = options or {}
    text = tostring(text or "")
    return setmetatable({
        text = text,
        cursorPosition = #text,
        cursorBlinkTime = 0,
        cursorVisible = true,
        filter = options.filter,
    }, TextInput)
end

function TextInput:getText()
    return self.text
end

function TextInput:setText(text)
    self.text = tostring(text)
    self.cursorPosition = #self.text
    self:resetCursorBlink()
end

function TextInput:getTextBeforeCursor()
    return self.text:sub(1, self.cursorPosition)
end

function TextInput:resetCursorBlink()
    self.cursorBlinkTime = 0
    self.cursorVisible = true
end

function TextInput:update(deltaTime)
    local elapsed = self.cursorBlinkTime + deltaTime
    local toggleCount = math.floor(elapsed / CURSOR_BLINK_INTERVAL)
    self.cursorBlinkTime = elapsed % CURSOR_BLINK_INTERVAL
    if toggleCount % 2 == 1 then
        self.cursorVisible = not self.cursorVisible
    end
end

function TextInput:textinput(text)
    if self.filter then text = self.filter(text) end
    if text == "" then return false end

    self.text = self.text:sub(1, self.cursorPosition)
        .. text
        .. self.text:sub(self.cursorPosition + 1)
    self.cursorPosition = self.cursorPosition + #text
    self:resetCursorBlink()
    return true
end

function TextInput:keypressed(key)
    local cursorPosition = self.cursorPosition
    if key == "backspace" then
        local previousPosition = previousCursorPosition(self.text, cursorPosition)
        self.text = self.text:sub(1, previousPosition)
            .. self.text:sub(cursorPosition + 1)
        self.cursorPosition = previousPosition
    elseif key == "delete" then
        local nextPosition = nextCursorPosition(self.text, cursorPosition)
        self.text = self.text:sub(1, cursorPosition)
            .. self.text:sub(nextPosition + 1)
    elseif key == "left" then
        self.cursorPosition = previousCursorPosition(self.text, cursorPosition)
    elseif key == "right" then
        self.cursorPosition = nextCursorPosition(self.text, cursorPosition)
    else
        return false
    end

    self:resetCursorBlink()
    return true
end

return TextInput
