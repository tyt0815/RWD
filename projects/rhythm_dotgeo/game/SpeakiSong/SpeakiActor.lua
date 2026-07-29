local Core = require("core")

local SpeakiActor = {}
SpeakiActor.__index = SpeakiActor

-- 화면 배치 조절값: ACTOR_HEIGHT_RATIO는 크기, SIDE_MARGIN_RATIO는 좌우 여백이다.
local ACTOR_HEIGHT_RATIO = 0.52
local MAX_ACTOR_WIDTH_RATIO = 0.3
local SIDE_MARGIN_RATIO = 0.09
local MIN_MARGIN = 24
local OUTSIDE_PADDING = 12

-- 반응 조절값: Long은 이미지 기준 좌하단 압박, Tap은 우하단 왕복·진동 거리다.
local LONG_PRESS_BEATS = 0.2
local LONG_SHIFT_X_RATIO = 0.035
local LONG_SHIFT_Y_RATIO = 0.045
local TAP_DURATION_BEATS = 0.35
local TAP_SHIFT_X_RATIO = 0.07
local TAP_SHIFT_Y_RATIO = 0.055
local TAP_SHAKE_RATIO = 0.012

function SpeakiActor.new(options)
    options = options or {}
    return setmetatable({
        role = options.role,
        side = options.side,
        flipHorizontal = options.flipHorizontal == true,
        sprites = options.sprites,
        movement = Core.BeatTween.new(0),
        spawned = false,
        effect = nil,
        effectStartBeat = 0,
        effectEndBeat = 0,
    }, SpeakiActor)
end

function SpeakiActor:reset()
    self.movement = Core.BeatTween.new(0)
    self.spawned = false
    self.effect = nil
    self.effectStartBeat = 0
    self.effectEndBeat = 0
end

function SpeakiActor:spawn()
    self.spawned = true
end

function SpeakiActor:moveOutside(outside, startBeat, durationBeats)
    self.movement:moveTo(outside and 1 or 0, startBeat, durationBeats)
end

function SpeakiActor:startLong(startBeat, lengthBeats)
    self.effect = "long"
    self.effectStartBeat = startBeat
    self.effectEndBeat = startBeat + lengthBeats
end

function SpeakiActor:stopLong()
    if self.effect == "long" then self.effect = nil end
end

function SpeakiActor:tap(startBeat)
    self.effect = "tap"
    self.effectStartBeat = startBeat
    self.effectEndBeat = startBeat + TAP_DURATION_BEATS
end

function SpeakiActor:update(beat)
    if self.effect and beat > self.effectEndBeat then self.effect = nil end
end

local function actorCenterX(actor, width, actorWidth)
    local margin = math.max(MIN_MARGIN, width * SIDE_MARGIN_RATIO)
    local visibleX
    local outsideX
    if actor.side == "left" then
        visibleX = margin + actorWidth / 2
        outsideX = -actorWidth / 2 - OUTSIDE_PADDING
    else
        visibleX = width - margin - actorWidth / 2
        outsideX = width + actorWidth / 2 + OUTSIDE_PADDING
    end
    local progress = actor.movement:getValue(actor.currentBeat)
    return visibleX + (outsideX - visibleX) * progress
end

local function effectTransform(actor, width, height, beat)
    if actor.effect == "long" then
        local progress = math.min(1, math.max(0,
            (beat - actor.effectStartBeat) / LONG_PRESS_BEATS
        ))
        local imageDirection = actor.flipHorizontal and 1 or -1
        return imageDirection * width * LONG_SHIFT_X_RATIO * progress,
            height * LONG_SHIFT_Y_RATIO * progress,
            progress,
            "long"
    end
    if actor.effect == "tap" then
        local duration = actor.effectEndBeat - actor.effectStartBeat
        local progress = math.min(1, math.max(0, (beat - actor.effectStartBeat) / duration))
        local pulse = math.sin(math.pi * progress)
        local shake = math.sin(math.pi * 4 * progress) * width * TAP_SHAKE_RATIO
        local imageDirection = actor.flipHorizontal and -1 or 1
        return imageDirection * (width * TAP_SHIFT_X_RATIO * pulse + shake),
            height * TAP_SHIFT_Y_RATIO * pulse,
            progress,
            "tap"
    end
    return 0, 0, 0, nil
end

local function drawImage(actor, image, centerX, topY, scale, alpha)
    local scaleX = actor.flipHorizontal and -scale or scale
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        image,
        centerX,
        topY,
        0,
        scaleX,
        scale,
        image:getWidth() / 2,
        0
    )
end

function SpeakiActor:draw(width, height, beat)
    if not self.spawned then return end
    self.currentBeat = beat
    local smile = self.sprites:get("smile")
    local actorHeight = math.max(64, math.min(
        height * ACTOR_HEIGHT_RATIO,
        width * MAX_ACTOR_WIDTH_RATIO * smile:getHeight() / smile:getWidth()
    ))
    local scale = actorHeight / smile:getHeight()
    local actorWidth = smile:getWidth() * scale
    local centerX = actorCenterX(self, width, actorWidth)
    local topY = height - actorHeight - height * 0.08
    local offsetX, offsetY, progress, effect = effectTransform(self, width, height, beat)

    if effect == "long" then
        drawImage(self, self.sprites:get("uu"), centerX + offsetX, topY + offsetY,
            scale, 1 - progress)
        drawImage(self, self.sprites:get("ner"), centerX + offsetX, topY + offsetY,
            scale, progress)
    elseif effect == "tap" then
        drawImage(self, self.sprites:get("uu"), centerX + offsetX, topY + offsetY,
            scale, 1)
    else
        drawImage(self, smile, centerX, topY, scale, 1)
    end
end

return SpeakiActor
