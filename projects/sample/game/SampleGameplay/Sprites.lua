local Sprites = {}
Sprites.__index = Sprites

-- 두 Sample Actor가 같은 이미지 세트를 사용하므로 Category에서 한 번만 로드해 공유한다.
-- Actor별 이미지가 달라지면 이 테이블을 억지로 확장하지 말고 해당 Actor 모듈로 옮긴다.
local IMAGE_PATHS = {
    base = "projects/sample/assets/image/웃피키.png",
    success = "projects/sample/assets/image/스피키.png",
    failure = "projects/sample/assets/image/스피키_네르기.png",
}

function Sprites.new(graphics)
    graphics = graphics or love.graphics
    local images = {}
    for state, path in pairs(IMAGE_PATHS) do
        local image = graphics.newImage(path)
        image:setFilter("linear", "linear")
        images[state] = image
    end
    return setmetatable({ images = images }, Sprites)
end

function Sprites:get(state)
    return self.images[state] or self.images.base
end

return Sprites
