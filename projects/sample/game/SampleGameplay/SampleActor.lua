local Core = require("core")

local SampleActor = {}
SampleActor.__index = SampleActor

-- 현재 Guide와 Player는 이동·Sprite 규칙이 같아 이 모듈의 두 인스턴스로 표현한다.
-- 둘의 변경 이유가 갈라지면 이 파일을 비대하게 만들지 말고 역할별 Actor로 분리한다.
function SampleActor.new(options)
    options = options or {}
    return setmetatable({
        role = options.role,
        side = options.side,
        flipHorizontal = options.flipHorizontal == true,
        sprites = options.sprites,
        movement = Core.BeatTween.new(0),
        spawned = false,
        flashRemaining = 0,
        result = nil,
    }, SampleActor)
end

function SampleActor:reset()
    self.movement = Core.BeatTween.new(0)
    self.spawned = false
    self.flashRemaining = 0
    self.result = nil
end

function SampleActor:spawn()
    self.spawned = true
end

function SampleActor:moveOutside(outside, startBeat, durationBeats)
    self.movement:moveTo(outside and 1 or 0, startBeat, durationBeats)
end

function SampleActor:flash(result, durationSeconds)
    self.result = result
    self.flashRemaining = durationSeconds
end

function SampleActor:update(deltaTime)
    self.flashRemaining = math.max(0, self.flashRemaining - deltaTime)
end

function SampleActor:getSpriteState()
    if self.flashRemaining <= 0 then return "base" end
    if self.role == "guide" then return "success" end
    return (self.result == Core.JudgmentResult.GOOD
        or self.result == Core.JudgmentResult.EMPTY_INPUT)
        and "success" or "failure"
end

local function actorCenterX(actor, width, actorHeight)
    local margin = math.max(20, width * 0.08)
    local halfWidth = actorHeight * 0.5
    local visibleX
    local outsideX
    if actor.side == "left" then
        visibleX = margin + halfWidth
        outsideX = -halfWidth - 8
    else
        visibleX = width - margin - halfWidth
        outsideX = width + halfWidth + 8
    end
    local progress = actor.movement:getValue(actor.currentBeat)
    return visibleX + (outsideX - visibleX) * progress
end

function SampleActor:draw(width, height, beat)
    if not self.spawned then return end
    self.currentBeat = beat
    local actorHeight = math.max(48, math.min(height * 0.62, width * 0.32))
    local image = self.sprites:get(self:getSpriteState())
    local scale = actorHeight / image:getHeight()
    local scaleX = self.flipHorizontal and -scale or scale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        image,
        actorCenterX(self, width, actorHeight),
        (height - actorHeight) / 2,
        0,
        scaleX,
        scale,
        image:getWidth() / 2,
        0
    )
end

return SampleActor
