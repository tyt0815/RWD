local Core = require("core")
local SampleSounds = require("projects.sample.game.SampleSounds")
local SampleSprites = require("projects.sample.game.SampleSprites")

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
        turnEvents = {},
        judgment = nil,
        guideFlashRemaining = 0,
        playerFlashRemaining = 0,
        playerResult = nil,
        autoPlay = "none",
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
    self.turnEvents = {}
    self.leftMovement = Core.BeatTween.new(0)
    self.rightMovement = Core.BeatTween.new(0)
    self.judgment = Core.TapJudgment.new({
        goodWindowBeats = 0.1,
        badWindowBeats = 0.25,
    })

    for _, event in ipairs(stage.events or {}) do
        if event.type == "projectEvent" and event.eventId == "spawnActors"
            and event.startBeat <= self.currentBeat then
            self.actorsSpawned = true
        elseif event.type == "projectEvent"
            and (event.eventId == "guideTurn" or event.eventId == "playerTurn") then
            table.insert(self.turnEvents, {
                eventId = event.eventId,
                startBeat = event.startBeat,
                triggered = event.startBeat <= self.currentBeat,
            })
        elseif event.type == "projectEvent" and event.eventId == "cueResponse" then
            local responseBeat = event.startBeat + event.params.responseDelayBeats
            local cue = {
                id = event.id,
                cueBeat = event.startBeat,
                responseBeat = responseBeat,
                cuePlayed = event.startBeat < self.currentBeat,
                autoPlayed = false,
            }
            table.insert(self.cueEvents, cue)
            if math.abs(event.startBeat - self.currentBeat) < 0.000001 then
                cue.cuePlayed = true
                self.guideFlashRemaining = FLASH_SECONDS
                self.sounds:play("cue")
            end
            if responseBeat + 0.25 >= self.currentBeat then
                self.judgment:addNote(event.id, responseBeat)
            end
        end
    end

    if self.autoPlay == "good" or self.autoPlay == "bad" then
        local offset = self.autoPlay == "bad" and AUTO_BAD_OFFSET_BEATS or 0
        for _, cue in ipairs(self.cueEvents) do
            local inputBeat = cue.responseBeat + offset
            if inputBeat <= self.currentBeat
                and cue.responseBeat + 0.25 >= self.currentBeat then
                cue.autoPlayed = true
                self:showResult(self.judgment:input(inputBeat))
            end
        end
    end

    table.sort(self.turnEvents, function(first, second)
        return first.startBeat < second.startBeat
    end)
    for _, event in ipairs(self.turnEvents) do
        if event.triggered then self:applyTurn(event.eventId, event.startBeat) end
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
    self.currentBeat = beat
    for _, event in ipairs(self.stage.events or {}) do
        if event.type == "projectEvent" and event.eventId == "spawnActors"
            and crossed(previousBeat, beat, event.startBeat) then
            self.actorsSpawned = true
        end
    end
    for _, turn in ipairs(self.turnEvents) do
        if not turn.triggered and crossed(previousBeat, beat, turn.startBeat) then
            turn.triggered = true
            self:applyTurn(turn.eventId, turn.startBeat)
        end
    end
    for _, cue in ipairs(self.cueEvents) do
        if not cue.cuePlayed and crossed(previousBeat, beat, cue.cueBeat) then
            cue.cuePlayed = true
            self.guideFlashRemaining = FLASH_SECONDS
            self.sounds:play("cue")
        end
    end
    if self.autoPlay == "good" or self.autoPlay == "bad" then
        local offset = self.autoPlay == "bad" and AUTO_BAD_OFFSET_BEATS or 0
        for _, cue in ipairs(self.cueEvents) do
            local inputBeat = cue.responseBeat + offset
            if not cue.autoPlayed and crossed(previousBeat, beat, inputBeat) then
                cue.autoPlayed = true
                self:showResult(self.judgment:input(inputBeat))
            end
        end
    end
    for _, result in ipairs(self.judgment:update(beat)) do
        self:showResult(result)
    end
end

-- 입력키와 현재 beat는 Editor가 전달한다. 판정 규칙은 Project에서 다시 만들지 않고
-- Core.TapJudgment를 조합하며, 색과 소리는 이 Sample Project가 결정한다.
function SampleGame:keypressed(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
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
