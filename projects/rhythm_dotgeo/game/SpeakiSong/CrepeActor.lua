local Core = require("core")
local BeatBounce = require("projects.rhythm_dotgeo.game.SpeakiSong.BeatBounce")

local CrepeActor = {}
CrepeActor.__index = CrepeActor

local STEP_WIDTH_RATIO = 0.05
local TURN_BEATS = 8
local FRAME_COUNT = 24
local IDLE_FRAME_COUNT = 40
local ANIMATION_FPS = 30
local FLIP_DURATION_BEATS = 0.25

function CrepeActor.new(graphics, fileExists)
    graphics = graphics or love.graphics
    fileExists = fileExists or function(path) return love.filesystem.getInfo(path, "file") ~= nil end
    local frames = {}
    for index = 1, FRAME_COUNT do
        local image = graphics.newImage(
            "projects/rhythm_dotgeo/assets/image/crepe_walk_" .. (index - 1) .. ".png")
        image:setFilter("linear", "linear")
        frames[index] = image
    end
    local idleFrames = {}
    local hasIdle = true
    for index = 0, IDLE_FRAME_COUNT - 1 do
        if not fileExists("projects/rhythm_dotgeo/assets/image/crepe_idle_" .. index .. ".png") then
            hasIdle = false
            break
        end
    end
    if hasIdle then
        for index = 1, IDLE_FRAME_COUNT do
            local image = graphics.newImage(
                "projects/rhythm_dotgeo/assets/image/crepe_idle_" .. (index - 1) .. ".png")
            image:setFilter("linear", "linear")
            idleFrames[index] = image
        end
    end
    return setmetatable({
        frames = frames,
        idleFrames = idleFrames,
        pauses = {},
        flipTween = Core.BeatTween.new(1),
    }, CrepeActor)
end

function CrepeActor:setMovementStart(beat, seconds)
    self.movementStartBeat = beat
    self.movementStartSeconds = seconds
    self.pauses = {}
end

function CrepeActor:stopMovement(beat, seconds)
    local last = self.pauses[#self.pauses]
    if last and not last.endBeat then return end
    table.insert(self.pauses, { startBeat = beat, startSeconds = seconds })
end

function CrepeActor:resumeMovement(beat, seconds)
    local last = self.pauses[#self.pauses]
    if last and not last.endBeat and beat > last.startBeat then
        last.endBeat = beat
        last.endSeconds = seconds
    end
end

function CrepeActor:getPlayback(beat, seconds)
    if not self.movementStartBeat or beat < self.movementStartBeat then
        return 0, seconds, false
    end
    local elapsedBeat = beat - self.movementStartBeat
    local elapsedSeconds = seconds - self.movementStartSeconds
    for _, pause in ipairs(self.pauses) do
        if beat < pause.startBeat then break end
        local startBeat = math.max(pause.startBeat, self.movementStartBeat)
        local startSeconds = math.max(pause.startSeconds, self.movementStartSeconds)
        if not pause.endBeat or beat < pause.endBeat then
            return elapsedBeat - (beat - startBeat), seconds - pause.startSeconds, false
        end
        if pause.endBeat > startBeat then
            elapsedBeat = elapsedBeat - (pause.endBeat - startBeat)
            elapsedSeconds = elapsedSeconds - (pause.endSeconds - startSeconds)
        end
    end
    return elapsedBeat, elapsedSeconds, true
end

function CrepeActor:getMotion(beat, halfWidthRatio)
    if not self.movementStartBeat or beat < self.movementStartBeat then return 0.5, -1, 1 end
    local walking, animationSeconds
    beat, animationSeconds, walking = self:getPlayback(beat, 0)
    local travel = math.min(STEP_WIDTH_RATIO * TURN_BEATS, 1 - halfWidthRatio * 2)
    -- 이동 거리와 이미지 너비를 뺀 나머지를 좌우 여백으로 균등 배분한다.
    local margin = (1 - travel - halfWidthRatio * 2) / 2
    local left = margin + halfWidthRatio
    local right = 1 - margin - halfWidthRatio
    local firstLeg = TURN_BEATS / 2
    if beat < firstLeg then
        return 0.5 - travel * beat / TURN_BEATS, -1, 1
    end
    local turn = math.floor((beat - firstLeg) / TURN_BEATS)
    local turnBeat = firstLeg + turn * TURN_BEATS
    local elapsed = beat - turnBeat
    local direction = turn % 2 == 0 and 1 or -1
    local position = (direction == -1 and right or left)
        + direction * travel * elapsed / TURN_BEATS
    self.flipTween:start(direction, -direction, turnBeat, FLIP_DURATION_BEATS)
    return position, direction, walking and self.flipTween:getValue(beat) or -direction
end

function CrepeActor:draw(width, height, beat, seconds)
    -- Stage 재생 시간으로 계산해 중간 재생과 일시정지에도 동기화한다.
    local _, animationSeconds, walking = self:getPlayback(beat, seconds)
    local frameCount = walking and FRAME_COUNT or IDLE_FRAME_COUNT
    local frameIndex = math.floor(math.max(0, animationSeconds) * ANIMATION_FPS) % frameCount + 1
    local image = walking and self.frames[frameIndex] or self.idleFrames[frameIndex] or self.frames[1]
    local scale = math.min(height * 0.32 / image:getHeight(), width * 0.3 / image:getWidth())
    local halfWidth = image:getWidth() * scale / 2
    local position, _, flipScale = self:getMotion(beat, halfWidth / width)
    local scaleX = scale * flipScale
    local centerX = position * width
    local bouncing = true
    for _, pause in ipairs(self.pauses) do
        if beat >= pause.startBeat and (not pause.endBeat or beat < pause.endBeat) then
            bouncing = false
            break
        end
    end
    local heightRatio = bouncing and BeatBounce.getHeightRatio(beat) or 1
    local centerY = height * 0.6 + image:getHeight() * scale * (1 - heightRatio) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, centerX, centerY, 0, scaleX, scale * heightRatio,
        image:getWidth() / 2, image:getHeight() / 2)
end

return CrepeActor
