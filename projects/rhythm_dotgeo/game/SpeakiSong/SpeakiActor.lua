local Core = require("core")

local SpeakiActor = {}
SpeakiActor.__index = SpeakiActor

function SpeakiActor.new(options)
    options = options or {}
    return setmetatable({
        role = options.role,
        side = options.side,
        flipHorizontal = options.flipHorizontal == true,
        sprites = options.sprites,
        settings = options.settings,
        movement = Core.BeatTween.new(0),
        spawned = false,
        effect = nil,
        effectStartBeat = 0,
        effectEndBeat = 0,
    }, SpeakiActor)
end

function SpeakiActor:configure(settings)
    self.settings = settings
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
    self.effectEndBeat = startBeat + self.settings.tapDurationBeats
end

function SpeakiActor:update(beat)
    if self.effect and beat > self.effectEndBeat then self.effect = nil end
end

local function actorCenterX(actor, width, actorWidth)
    local settings = actor.settings
    local margin = math.max(settings.minMargin, width * settings.sideMarginRatio)
    local visibleX
    local outsideX
    if actor.side == "left" then
        visibleX = margin + actorWidth / 2
        outsideX = -actorWidth / 2 - settings.outsidePadding
    else
        visibleX = width - margin - actorWidth / 2
        outsideX = width + actorWidth / 2 + settings.outsidePadding
    end
    local progress = actor.movement:getValue(actor.currentBeat)
    return visibleX + (outsideX - visibleX) * progress
end

local function effectTransform(actor, width, height, beat)
    local settings = actor.settings
    if actor.effect == "long" then
        local progress = math.min(1, math.max(0,
            (beat - actor.effectStartBeat) / settings.longPressBeats
        ))
        local imageDirection = actor.flipHorizontal and 1 or -1
        return imageDirection * width * settings.longShiftXRatio * progress,
            height * settings.longShiftYRatio * progress,
            progress,
            "long"
    end
    if actor.effect == "tap" then
        local duration = actor.effectEndBeat - actor.effectStartBeat
        local progress = math.min(1, math.max(0, (beat - actor.effectStartBeat) / duration))
        local pulse = math.sin(math.pi * progress)
        local shake = math.sin(math.pi * 4 * progress)
            * width * settings.tapShakeRatio
        local imageDirection = actor.flipHorizontal and -1 or 1
        return imageDirection * (width * settings.tapShiftXRatio * pulse + shake),
            height * settings.tapShiftYRatio * pulse,
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
    local settings = self.settings
    local actorHeight = math.max(64, math.min(
        height * settings.actorHeightRatio,
        width * settings.maxActorWidthRatio * smile:getHeight() / smile:getWidth()
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
