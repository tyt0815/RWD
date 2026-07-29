local Background = {}
Background.__index = Background

function Background.new(sprites)
    return setmetatable({ sprites = sprites, spawned = false }, Background)
end

function Background:reset()
    self.spawned = false
end

function Background:spawn()
    self.spawned = true
end

function Background:draw(width, height)
    if not self.spawned then return end
    local image = self.sprites:get("background")
    local scale = math.max(width / image:getWidth(), height / image:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        image,
        width / 2,
        height / 2,
        0,
        scale,
        scale,
        image:getWidth() / 2,
        image:getHeight() / 2
    )
end

return Background
