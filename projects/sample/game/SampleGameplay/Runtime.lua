local Core = require("core")
local CueResponse = require("projects.sample.game.SampleGameplay.CueResponse")
local GuideTurn = require("projects.sample.game.SampleGameplay.GuideTurn")
local PlayerTurn = require("projects.sample.game.SampleGameplay.PlayerTurn")
local SampleActor = require("projects.sample.game.SampleGameplay.SampleActor")
local Sounds = require("projects.sample.game.SampleGameplay.Sounds")
local SpawnActors = require("projects.sample.game.SampleGameplay.SpawnActors")
local Sprites = require("projects.sample.game.SampleGameplay.Sprites")

local Runtime = {}
Runtime.__index = Runtime

local FLASH_SECONDS = 0.18
local TURN_DURATION_BEATS = 0.5
local GOOD_WINDOW_BEATS = 0.1
local BAD_WINDOW_BEATS = 0.25
local AUTO_BAD_OFFSET_BEATS = 0.2

local EVENT_HANDLERS = {
    spawnActors = SpawnActors,
    guideTurn = GuideTurn,
    playerTurn = PlayerTurn,
    cueResponse = CueResponse,
}

-- Runtime은 SampleGameplay 폴더의 유일한 조립 지점이다. 공용 리소스는 여기서 한 번
-- 만들고 두 Actor에 주입하며, Game이나 다른 Category의 상태에는 접근하지 않는다.
function Runtime.new(project, category, options)
    options = options or {}
    local sprites = options.sprites or Sprites.new(options.graphics)
    return setmetatable({
        project = project,
        category = category,
        sounds = options.sounds or Sounds.new(),
        sprites = sprites,
        guideActor = SampleActor.new({
            role = "guide",
            side = "left",
            sprites = sprites,
        }),
        playerActor = SampleActor.new({
            role = "player",
            side = "right",
            flipHorizontal = true,
            sprites = sprites,
        }),
        currentBeat = 0,
        cueEvents = {},
        judgment = nil,
        playerResult = nil,
        autoPlay = "none",
        flashSeconds = FLASH_SECONDS,
        badWindowBeats = BAD_WINDOW_BEATS,
        autoBadOffsetBeats = AUTO_BAD_OFFSET_BEATS,
    }, Runtime)
end

function Runtime:setAutoPlay(value)
    self.autoPlay = value or "none"
end

function Runtime:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.cueEvents = {}
    self.playerResult = nil
    self.guideActor:reset()
    self.playerActor:reset()
    self.judgment = Core.TapJudgment.new({
        goodWindowBeats = GOOD_WINDOW_BEATS,
        badWindowBeats = BAD_WINDOW_BEATS,
    })
end

-- Core Host가 Definition의 Event ID를 보고 이 Runtime까지 라우팅한다. 여기서는 같은
-- 폴더의 Event 모듈만 선택하므로 새 노드 구현이 SampleGameplay 밖으로 새지 않는다.
function Runtime:handleEvent(event, occurrence, beat)
    self.currentBeat = beat
    local handler = EVENT_HANDLERS[event.eventId]
    if not handler then
        error("Unknown SampleGameplay Event: " .. tostring(event.eventId))
    end
    handler.apply(self, event, occurrence)
end

function Runtime:spawnActors()
    self.guideActor:spawn()
    self.playerActor:spawn()
end

function Runtime:applyTurn(eventId, startBeat)
    if eventId == "guideTurn" then
        self.guideActor:moveOutside(false, startBeat, TURN_DURATION_BEATS)
        self.playerActor:moveOutside(true, startBeat, TURN_DURATION_BEATS)
    elseif eventId == "playerTurn" then
        self.guideActor:moveOutside(true, startBeat, TURN_DURATION_BEATS)
        self.playerActor:moveOutside(false, startBeat, TURN_DURATION_BEATS)
    end
end

function Runtime:playCue()
    self.guideActor:flash(Core.JudgmentResult.GOOD, FLASH_SECONDS)
    self.sounds:play("cue")
end

function Runtime:showResult(result)
    self.playerResult = result.result
    self.playerActor:flash(result.result, FLASH_SECONDS)
    self.sounds:play(result.result)
end

local function crossed(previousBeat, currentBeat, targetBeat)
    return targetBeat > previousBeat and targetBeat <= currentBeat
end

-- Event가 시작한 판정과 Actor flash처럼 여러 frame에 걸친 Category 상태를 갱신한다.
function Runtime:update(deltaTime, beat)
    local previousBeat = self.currentBeat
    self.currentBeat = beat
    self.guideActor:update(deltaTime)
    self.playerActor:update(deltaTime)

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

function Runtime:keypressed(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
    self:showResult(self.judgment:input(beat))
end

function Runtime:getActorSpriteStates()
    return self.guideActor:getSpriteState(), self.playerActor:getSpriteState()
end

function Runtime:draw(width, height)
    self.guideActor:draw(width, height, self.currentBeat)
    self.playerActor:draw(width, height, self.currentBeat)
end

return Runtime
