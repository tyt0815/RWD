local Core = require("core")
local SampleSounds = require("projects.sample.game.SampleSounds")
local SampleSprites = require("projects.sample.game.SampleSprites")
local EVENT_HANDLERS = require("projects.sample.game.events.init")

local SampleGame = {}
SampleGame.__index = SampleGame

local FLASH_SECONDS = 0.18
local TURN_DURATION_BEATS = 0.5
local AUTO_BAD_OFFSET_BEATS = 0.2

function SampleGame.new(project)
    return setmetatable({
        project = project,
        elapsedTime = 0,
        stage = nil,
        currentBeat = 0,
        actorsSpawned = false,
        cueEvents = {},
        stageRuntime = Core.StageRuntime.new(),
        judgment = nil,
        guideFlashRemaining = 0,
        playerFlashRemaining = 0,
        playerResult = nil,
        autoPlay = "none",
        flashSeconds = FLASH_SECONDS,
        badWindowBeats = 0.25,
        autoBadOffsetBeats = AUTO_BAD_OFFSET_BEATS,
        leftMovement = Core.BeatTween.new(0),
        rightMovement = Core.BeatTween.new(0),
        sounds = SampleSounds.new(),
        sprites = SampleSprites.new(),
    }, SampleGame)
end

-- Editor TestPlayer가 현재 Stage와 시작 beat를 전달하는 진입점이다.
-- 새 Project도 같은 이름의 메서드에서 Project Event를 런타임 상태로 전개하면 된다.
local function getTurnTargets(eventId)
    if eventId == "guideTurn" then return 0, 1 end
    if eventId == "playerTurn" then return 1, 0 end
    return nil, nil
end

-- 이동 보간은 Project에서 다시 계산하지 않고 Core.BeatTween 인스턴스를 조합한다.
-- 어느 액터를 화면 밖으로 보낼지는 Sample 노드의 연출 규칙이므로 Project가 소유한다.
function SampleGame:applyTurn(eventId, startBeat)
    local leftTarget, rightTarget = getTurnTargets(eventId)
    if leftTarget == nil then return end
    self.leftMovement:moveTo(leftTarget, startBeat, TURN_DURATION_BEATS)
    self.rightMovement:moveTo(rightTarget, startBeat, TURN_DURATION_BEATS)
end

-- Editor의 선택적 TestPlayer Auto Play 계약이다. 판정창을 아는 Project가
-- Good/Bad 입력 시점과 Miss의 무입력 정책을 직접 결정한다.
function SampleGame:setAutoPlay(value)
    self.autoPlay = value or "none"
end

function SampleGame:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.actorsSpawned = false
    self.cueEvents = {}
    self.stageRuntime = Core.StageRuntime.new()
    self.leftMovement = Core.BeatTween.new(0)
    self.rightMovement = Core.BeatTween.new(0)
    self.judgment = Core.TapJudgment.new({
        goodWindowBeats = 0.1,
        badWindowBeats = 0.25,
    })

    local occurrences, runtimeError = self.stageRuntime:start(stage, self.currentBeat)
    if not occurrences then error(runtimeError) end
    self:applyStageOccurrences(occurrences)
end

function SampleGame:applyStageOccurrences(occurrences)
    for _, occurrence in ipairs(occurrences) do
        local event = occurrence.event
        if event.type == "projectEvent" then
            local handler = EVENT_HANDLERS[event.eventId]
            if not handler then error("Unknown Sample Project Event: " .. tostring(event.eventId)) end
            handler.apply(self, event, occurrence)
        end
    end
end

local function crossed(previousBeat, currentBeat, targetBeat)
    return targetBeat > previousBeat and targetBeat <= currentBeat
end

function SampleGame:showResult(result)
    self.playerResult = result.result
    self.playerFlashRemaining = FLASH_SECONDS
    self.sounds:play(result.result)
end

function SampleGame:update(deltaTime, beat)
    self.elapsedTime = self.elapsedTime + deltaTime
    self.guideFlashRemaining = math.max(0, self.guideFlashRemaining - deltaTime)
    self.playerFlashRemaining = math.max(0, self.playerFlashRemaining - deltaTime)
    if not self.stage or beat == nil then return end

    local previousBeat = self.currentBeat
    local occurrences, runtimeError = self.stageRuntime:update(beat)
    if not occurrences then error(runtimeError) end
    self.currentBeat = self.stageRuntime:getCurrentBeat()
    self:applyStageOccurrences(occurrences)
    if self.autoPlay == "good" or self.autoPlay == "bad" then
        local offset = self.autoPlay == "bad" and AUTO_BAD_OFFSET_BEATS or 0
        for _, cue in ipairs(self.cueEvents) do
            local inputBeat = cue.responseBeat + offset
            if not cue.autoPlayed and crossed(previousBeat, self.currentBeat, inputBeat) then
                cue.autoPlayed = true
                self:showResult(self.judgment:input(inputBeat))
            end
        end
    end
    for _, result in ipairs(self.judgment:update(self.currentBeat)) do
        self:showResult(result)
    end
end

-- 입력키와 현재 beat는 Editor가 전달한다. 판정 규칙은 Project에서 다시 만들지 않고
-- Core.TapJudgment를 조합하며, 색과 소리는 이 Sample Project가 결정한다.
function SampleGame:keypressed(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none"
        or not self.stageRuntime:isInputEnabled() then return end
    self:showResult(self.judgment:input(beat))
end

local function drawActor(image, centerX, y, targetHeight, flipHorizontal)
    local scale = targetHeight / image:getHeight()
    local scaleX = flipHorizontal and -scale or scale
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        image,
        centerX,
        y,
        0,
        scaleX,
        scale,
        image:getWidth() / 2,
        0
    )
end

function SampleGame:getActorSpriteStates()
    local guideState = self.guideFlashRemaining > 0 and "success" or "base"
    local playerState = "base"
    if self.playerFlashRemaining > 0 then
        playerState = (self.playerResult == Core.JudgmentResult.GOOD
            or self.playerResult == Core.JudgmentResult.EMPTY_INPUT)
            and "success" or "failure"
    end
    return guideState, playerState
end

function SampleGame:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    love.graphics.clear(0, 0, 0, 1)
    if not self.stage or not self.actorsSpawned then return end

    local actorHeight = math.max(48, math.min(height * 0.62, width * 0.32))
    local y = (height - actorHeight) / 2
    local margin = math.max(20, width * 0.08)
    local halfWidth = actorHeight * 0.5
    local leftVisibleX = margin + halfWidth
    local rightVisibleX = width - margin - halfWidth
    local leftOutsideX = -halfWidth - 8
    local rightOutsideX = width + halfWidth + 8
    local leftProgress = self.leftMovement:getValue(self.currentBeat)
    local rightProgress = self.rightMovement:getValue(self.currentBeat)
    local leftX = leftVisibleX + (leftOutsideX - leftVisibleX) * leftProgress
    local rightX = rightVisibleX + (rightOutsideX - rightVisibleX) * rightProgress

    local guideState, playerState = self:getActorSpriteStates()
    drawActor(self.sprites:get(guideState), leftX, y, actorHeight, false)
    -- 같은 asset을 재사용하되 오른쪽 액터만 음수 x scale로 좌우 반전한다.
    drawActor(self.sprites:get(playerState), rightX, y, actorHeight, true)
end

return SampleGame
