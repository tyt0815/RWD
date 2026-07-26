local Button = {}
Button.__index = Button

function Button.new(options)
    options = options or {}
    local button = {}
    for key, value in pairs(options) do
        button[key] = value
    end
    if button.enabled == nil then button.enabled = true end
    return setmetatable(button, Button)
end

function Button:setEnabled(enabled)
    self.enabled = enabled == true
end

function Button:contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width
        and y >= rect.y and y < rect.y + rect.height
end

function Button:hitTest(rect, x, y, mouseButton)
    return self.enabled and mouseButton == 1 and self:contains(rect, x, y)
end

return Button
