-- 버튼의 활성 상태와 사각형 클릭 판정을 제공한다. 라벨·동작 정보를 보관하되 그림은 직접 그리지 않는다.

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
