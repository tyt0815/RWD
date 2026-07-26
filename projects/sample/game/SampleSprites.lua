local SampleSprites = {}
SampleSprites.__index = SampleSprites

local IMAGE_PATHS = {
    base = "projects/sample/assets/image/웃피키.png",
    success = "projects/sample/assets/image/스피키.png",
    failure = "projects/sample/assets/image/스피키_네르기.png",
}

function SampleSprites.new(graphics)
    graphics = graphics or love.graphics
    local images = {}
    for state, path in pairs(IMAGE_PATHS) do
        local image = graphics.newImage(path)
        image:setFilter("linear", "linear")
        images[state] = image
    end
    return setmetatable({ images = images }, SampleSprites)
end

function SampleSprites:get(state)
    return self.images[state] or self.images.base
end

return SampleSprites
