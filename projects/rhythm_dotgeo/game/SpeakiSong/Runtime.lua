local Core = require("core")
local Background = require("projects.rhythm_dotgeo.game.SpeakiSong.Background")
local Config = require("projects.rhythm_dotgeo.game.SpeakiSong.Config")
local GameplayConfig = require("projects.rhythm_dotgeo.game.GameplayConfig")
local LongCueResponse = require("projects.rhythm_dotgeo.game.SpeakiSong.LongCueResponse")
local Sounds = require("projects.rhythm_dotgeo.game.SpeakiSong.Sounds")
local SpawnActors = require("projects.rhythm_dotgeo.game.SpeakiSong.SpawnActors")
local SpeakiActor = require("projects.rhythm_dotgeo.game.SpeakiSong.SpeakiActor")
local Sprites = require("projects.rhythm_dotgeo.game.SpeakiSong.Sprites")
local TapCueResponse = require("projects.rhythm_dotgeo.game.SpeakiSong.TapCueResponse")

local Runtime = {}
Runtime.__index = Runtime

local TURN_LEAD_BEATS = 0.5
local TURN_DURATION_BEATS = 0.5
local GOOD_WINDOW_BEATS = 0.1
local BAD_WINDOW_BEATS = 0.25
local AUTO_BAD_OFFSET_BEATS = 0.2

local EVENT_HANDLERS = {
    speakiSong = SpawnActors,
    heue = LongCueResponse,
    doNotNer = TapCueResponse,
}

local CUE_EVENTS = {
    heue = true,
    doNotNer = true,
}

local function buildTurnSchedule(stage)
    local moments = {}
    for index, event in ipairs(stage.events or {}) do
        if event.type == "projectEvent" and CUE_EVENTS[event.eventId] then
            local responseDelayBeats = event.params.responseDelayBeats
            table.insert(moments, {
                role = "guide",
                beat = event.startBeat,
                order = index * 2,
            })
            table.insert(moments, {
                role = "player",
                beat = event.startBeat + responseDelayBeats,
                order = index * 2 + 1,
            })
        end
    end
    table.sort(moments, function(left, right)
        if left.beat == right.beat then return left.order < right.order end
        return left.beat < right.beat
    end)

    local schedule = {}
    local previousRole = nil
    for _, moment in ipairs(moments) do
        if moment.role ~= previousRole then
            table.insert(schedule, {
                role = moment.role,
                startBeat = moment.beat - TURN_LEAD_BEATS,
            })
            previousRole = moment.role
        end
    end
    return schedule
end

function Runtime.new(project, category, options)
    options = options or {}
    local sprites = options.sprites or Sprites.new(options.graphics)
    return setmetatable({
        project = project,
        category = category,
        sprites = sprites,
        sounds = options.sounds or Sounds.new(),
        config = options.config or Config.new(options.configLoader),
        gameplayConfig = options.gameplayConfig or GameplayConfig.new(),
        background = Background.new(sprites),
        guideActor = SpeakiActor.new({
            role = "guide",
            side = "left",
            sprites = sprites,
        }),
        playerActor = SpeakiActor.new({
            role = "player",
            side = "right",
            flipHorizontal = true,
            sprites = sprites,
        }),
        currentBeat = 0,
        lastUpdatedBeat = 0,
        turnSchedule = {},
        nextTurnIndex = 1,
        autoPlay = "none",
        tapJudgment = nil,
        longJudgment = nil,
        tapCues = {},
        longCues = {},
        guideLongSounds = {},
        tapResult = nil,
        longResult = nil,
        playerLongHeld = false,
        playerAction = nil,
        badWindowBeats = BAD_WINDOW_BEATS,
        tapDurationBeats = nil,
    }, Runtime)
end

function Runtime:setAutoPlay(value)
    self.autoPlay = value or "none"
end

function Runtime:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.lastUpdatedBeat = self.currentBeat
    self.turnSchedule = buildTurnSchedule(stage)
    self.nextTurnIndex = 1
    self.tapCues = {}
    self.longCues = {}
    self.guideLongSounds = {}
    self.tapResult = nil
    self.longResult = nil
    self.playerLongHeld = false
    self.background:reset()
    self.guideActor:reset()
    self.playerActor:reset()
    local projectConfig, configError = self.config:load()
    if not projectConfig then error(configError) end
    local gameplayConfig, gameplayConfigError = self.gameplayConfig:load()
    if not gameplayConfig then error(gameplayConfigError) end
    self.sounds:configure(projectConfig)
    self.guideActor:configure(projectConfig.actor)
    self.playerActor:configure(projectConfig.actor)
    self:processTurnSchedule(self.currentBeat)
    self.tapDurationBeats = projectConfig.actor.tapDurationBeats
    self.playerAction = Core.PlayerAction.new({
        longHoldThresholdMs = gameplayConfig.longHoldThresholdMs,
    })
    self.tapJudgment = Core.TapJudgment.new({
        goodWindowBeats = GOOD_WINDOW_BEATS,
        badWindowBeats = BAD_WINDOW_BEATS,
    })
    self.longJudgment = Core.LongNoteJudgment.new({
        goodWindowBeats = GOOD_WINDOW_BEATS,
        badWindowBeats = BAD_WINDOW_BEATS,
    })
end

function Runtime:handleEvent(event, occurrence, beat)
    self.currentBeat = beat
    local handler = EVENT_HANDLERS[event.eventId]
    if not handler then error("Unknown SpeakiSong Event: " .. tostring(event.eventId)) end
    handler.apply(self, event, occurrence)
end

function Runtime:applyTurn(role, startBeat)
    local showGuide = role == "guide"
    self.guideActor:moveOutside(not showGuide, startBeat, TURN_DURATION_BEATS)
    self.playerActor:moveOutside(showGuide, startBeat, TURN_DURATION_BEATS)
    self.sounds:resetTapIndex(role)
end

function Runtime:processTurnSchedule(beat)
    while self.nextTurnIndex <= #self.turnSchedule do
        local turn = self.turnSchedule[self.nextTurnIndex]
        if turn.startBeat > beat then break end
        self:applyTurn(turn.role, turn.startBeat)
        self.nextTurnIndex = self.nextTurnIndex + 1
    end
end

function Runtime:startGuideLongSound(startBeat, lengthBeats)
    self.sounds:startLong("guide")
    table.insert(self.guideLongSounds, {
        endBeat = startBeat + lengthBeats,
        released = false,
    })
end

local function crossed(previousBeat, currentBeat, targetBeat)
    return targetBeat > previousBeat and targetBeat <= currentBeat
end

function Runtime:applyTapInput(beat)
    local result = self.tapJudgment:input(beat)
    self.tapResult = result.result
    if result.result == Core.JudgmentResult.EMPTY_INPUT then return false end
    self.playerActor:tap(beat)
    self.sounds:playTap("player")
    return true
end

function Runtime:applyEmptyTapInput(beat)
    self.tapResult = Core.JudgmentResult.EMPTY_INPUT
    self.playerActor:tap(beat)
    self.sounds:playTap("player")
end

function Runtime:startEmptyLongInput(beat)
    self.longResult = Core.JudgmentResult.EMPTY_INPUT
    self.playerActor:startLong(beat, math.huge)
    self.sounds:startLong("player")
    self.playerLongHeld = true
end

function Runtime:applyLongPress(beat)
    local result = self.longJudgment:press(beat)
    local endBeat = result.endBeat
    if result.result == Core.JudgmentResult.EMPTY_INPUT then
        for _, cue in ipairs(self.longCues) do
            if beat >= cue.startBeat and beat <= cue.endBeat then
                endBeat = cue.endBeat
                break
            end
        end
        if not endBeat then
            self:startEmptyLongInput(beat)
            return true
        end
    end

    self.longResult = result.result
    self.playerActor:startLong(beat, endBeat - beat + BAD_WINDOW_BEATS)
    self.sounds:startLong("player")
    self.playerLongHeld = true
    return true
end

function Runtime:applyLongRelease(beat)
    local result = self.longJudgment:release(beat)
    if not self.playerLongHeld
        and result.result == Core.JudgmentResult.EMPTY_INPUT then return false end
    self.playerLongHeld = false
    self.playerActor:stopLong()
    self.sounds:releaseLong("player")
    self.longResult = result.result
    return true
end

function Runtime:update(deltaTime, beat, realDeltaTime)
    local previousBeat = self.lastUpdatedBeat
    self.currentBeat = beat
    self:processTurnSchedule(beat)
    local playerAction = self.playerAction:update(realDeltaTime or deltaTime)
    if playerAction and playerAction.type == "LONG_START" then
        self:applyLongPress(playerAction.pressBeat)
    end
    self.guideActor:update(beat)
    self.playerActor:update(beat)
    for _, sound in ipairs(self.guideLongSounds) do
        if not sound.released and crossed(previousBeat, beat, sound.endBeat) then
            sound.released = true
            self.sounds:releaseLong("guide")
        end
    end

    if self.autoPlay == "good" or self.autoPlay == "bad" then
        local offset = self.autoPlay == "bad" and AUTO_BAD_OFFSET_BEATS or 0
        for _, cue in ipairs(self.longCues) do
            local pressBeat = cue.startBeat + offset
            local releaseBeat = cue.endBeat + offset
            if not cue.autoPressed and crossed(previousBeat, beat, pressBeat) then
                cue.autoPressed = true
                self:applyLongPress(pressBeat)
            end
            if cue.autoPressed and not cue.autoReleased
                and crossed(previousBeat, beat, releaseBeat) then
                cue.autoReleased = true
                self:applyLongRelease(releaseBeat)
            end
        end
        for _, cue in ipairs(self.tapCues) do
            local inputBeat = cue.responseBeat + offset
            if not cue.autoPlayed and crossed(previousBeat, beat, inputBeat) then
                cue.autoPlayed = true
                self:applyTapInput(inputBeat)
            end
        end
    end

    if not self.playerAction:isPending() then
        for _, result in ipairs(self.tapJudgment:update(beat)) do
            self.tapResult = result.result
        end
        for _, result in ipairs(self.longJudgment:update(beat)) do
            self.longResult = result.result
            if result.phase == "RELEASE" and not self.playerLongHeld then
                self.playerActor:stopLong()
            end
        end
    end
    self.sounds:update()
    self.lastUpdatedBeat = beat
end

function Runtime:keypressed(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
    self.playerAction:press(beat)
end

function Runtime:keyreleased(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
    local action = self.playerAction:release(beat)
    if not action then return end
    if action.type == "TAP" then
        if not self:applyTapInput(action.pressBeat) then
            self:applyEmptyTapInput(action.pressBeat)
        end
    elseif action.type == "LONG_RELEASE" then
        self:applyLongRelease(action.releaseBeat)
    end
end

function Runtime:stop()
    self.sounds:stop()
end

function Runtime:draw(width, height)
    self.background:draw(width, height)
    self.guideActor:draw(width, height, self.currentBeat)
    self.playerActor:draw(width, height, self.currentBeat)
end

return Runtime
