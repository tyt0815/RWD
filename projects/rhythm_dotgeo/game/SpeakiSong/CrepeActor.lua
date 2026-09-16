local Core = require("core")

local CrepeActor = {}
CrepeActor.__index = CrepeActor

local STEP_WIDTH_RATIO = 0.05
local FRAME_COUNT = 12
local ANIMATION_BEATS = 2
local FLIP_DURATION_BEATS = 0.25

function CrepeActor.new(graphics)
    graphics = graphics or love.graphics
    local frames = {}
    for index = 1, FRAME_COUNT do
        local image = graphics.newImage(
            "projects/rhythm_dotgeo/assets/image/crepe_walk_" .. (index - 1) .. ".png")
        image:setFilter("linear", "linear")
        frames[index] = image
    end
    return setmetatable({
        frames = frames,
        turnSchedule = {},
        flipTween = Core.BeatTween.new(1),
    }, CrepeActor)
end

function CrepeActor:setTurnSchedule(turnSchedule)
    self.turnSchedule = turnSchedule
end

function CrepeActor:getStepOffset(beat)
    local step = math.floor(beat)
    local offset = -beat
    local direction = -1
    self.flipTween:start(1, 1, 0, FLIP_DURATION_BEATS)
    -- Turn 구간별 경과 beat를 합산해 박자 사이에도 일정한 속도로 이동한다.
    for _, turn in ipairs(self.turnSchedule) do
        -- 방향 반전은 프레임이 바뀌는 정수 박자에 유지한다.
        if turn.startBeat > step then break end
        local turnBeat = math.max(0, math.ceil(turn.startBeat))
        local nextDirection = turn.role == "guide" and 1 or -1
        offset = offset + math.max(0, beat - turnBeat) * (nextDirection - direction)
        if nextDirection ~= direction then
            self.flipTween:moveTo(-nextDirection, turnBeat, FLIP_DURATION_BEATS)
        end
        direction = nextDirection
    end
    return offset, direction, self.flipTween:getValue(beat)
end

function CrepeActor:draw(width, height, beat)
    -- 누적 시간 대신 Stage beat를 사용해 중간 재생과 일시정지에도 동기화한다.
    local frameIndex = math.floor((beat % ANIMATION_BEATS) / ANIMATION_BEATS * FRAME_COUNT) + 1
    local image = self.frames[frameIndex]
    local scale = math.min(height * 0.32 / image:getHeight(), width * 0.3 / image:getWidth())
    local halfWidth = image:getWidth() * scale / 2
    local offset, _, flipScale = self:getStepOffset(beat)
    local scaleX = scale * flipScale
    local centerX = (width / 2 + halfWidth + offset * width * STEP_WIDTH_RATIO)
        % (width + halfWidth * 2) - halfWidth
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, centerX, height * 0.6, 0, scaleX, scale,
        image:getWidth() / 2, image:getHeight() / 2)
end

return CrepeActor
