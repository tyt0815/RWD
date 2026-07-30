local Sprites = {}
Sprites.__index = Sprites

local IMAGE_PATHS = {
    background = "projects/rhythm_dotgeo/assets/image/ghost_basic.png",
    smile = "projects/rhythm_dotgeo/assets/image/speaki_smile.png",
    uu = "projects/rhythm_dotgeo/assets/image/speaki_uu.png",
    ner = "projects/rhythm_dotgeo/assets/image/speaki_ner.png",
}

-- 가이드와 플레이어가 같은 이미지를 쓰므로 Category 수명 동안 한 번만 로드한다.
function Sprites.new(graphics)
    graphics = graphics or love.graphics
    local images = {}
    for id, path in pairs(IMAGE_PATHS) do
        local image = graphics.newImage(path)
        image:setFilter("linear", "linear")
        images[id] = image
    end
    return setmetatable({ images = images }, Sprites)
end

function Sprites:get(id)
    return self.images[id]
end

return Sprites
