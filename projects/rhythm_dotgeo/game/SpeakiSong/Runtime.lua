local Core = require("core")
local Background = require("projects.rhythm_dotgeo.game.SpeakiSong.Background")
local LongCueResponse = require("projects.rhythm_dotgeo.game.SpeakiSong.LongCueResponse")
local Sounds = require("projects.rhythm_dotgeo.game.SpeakiSong.Sounds")
local SpawnActors = require("projects.rhythm_dotgeo.game.SpeakiSong.SpawnActors")
local SpeakiActor = require("projects.rhythm_dotgeo.game.SpeakiSong.SpeakiActor")
local Sprites = require("projects.rhythm_dotgeo.game.SpeakiSong.Sprites")
local TapCueResponse = require("projects.rhythm_dotgeo.game.SpeakiSong.TapCueResponse")
local Turn = require("projects.rhythm_dotgeo.game.SpeakiSong.Turn")

local Runtime = {}
Runtime.__index = Runtime

local TURN_DURATION_BEATS = 0.5
local GOOD_WINDOW_BEATS = 0.1
local BAD_WINDOW_BEATS = 0.25
local AUTO_BAD_OFFSET_BEATS = 0.2

local EVENT_HANDLERS = {
    speakiSong = SpawnActors,
    heue = LongCueResponse,
    doNotNer = TapCueResponse,
    guideTurn = Turn,
    playerTurn = Turn,
}

function Runtime.new(project, category, options)
    options = options or {}
    local sprites = options.sprites or Sprites.new(options.graphics)
    return setmetatable({
        project = project,
        category = category,
        sprites = sprites,
        sounds = options.sounds or Sounds.new(),
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
        autoPlay = "none",
        tapJudgment = nil,
        longJudgment = nil,
        tapCues = {},
        longCues = {},
        tapResult = nil,
        longResult = nil,
        badWindowBeats = BAD_WINDOW_BEATS,
        tapDurationBeats = 0.35,
    }, Runtime)
end

function Runtime:setAutoPlay(value)
    self.autoPlay = value or "none"
end

function Runtime:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.tapCues = {}
    self.longCues = {}
    self.tapResult = nil
    self.longResult = nil
    self.background:reset()
    self.guideActor:reset()
    self.playerActor:reset()
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

function Runtime:applyTurn(eventId, startBeat)
    if eventId == "guideTurn" then
        self.guideActor:moveOutside(false, startBeat, TURN_DURATION_BEATS)
        self.playerActor:moveOutside(true, startBeat, TURN_DURATION_BEATS)
    elseif eventId == "playerTurn" then
        self.guideActor:moveOutside(true, startBeat, TURN_DURATION_BEATS)
        self.playerActor:moveOutside(false, startBeat, TURN_DURATION_BEATS)
    end
end

local function crossed(previousBeat, currentBeat, targetBeat)
    return targetBeat > previousBeat and targetBeat <= currentBeat
end

function Runtime:applyTapInput(beat)
    local result = self.tapJudgment:input(beat)
    if result.result ~= Core.JudgmentResult.EMPTY_INPUT then
        self.tapResult = result.result
        self.playerActor:tap(beat)
        self.sounds:play("doNotNerPlayer")
        return true
    end
    return false
end

function Runtime:applyLongPress(beat)
    local result = self.longJudgment:press(beat)
    if result.result == Core.JudgmentResult.EMPTY_INPUT then return false end
    self.playerActor:startLong(beat, result.endBeat - beat + BAD_WINDOW_BEATS)
    self.sounds:play("heuePlayerStart")
    return true
end

function Runtime:applyLongRelease(beat)
    local result = self.longJudgment:release(beat)
    if result.result == Core.JudgmentResult.EMPTY_INPUT then return false end
    self.longResult = result.result
    self.playerActor:stopLong()
    self.sounds:play("heuePlayerEnd")
    return true
end

function Runtime:update(_, beat)
    local previousBeat = self.currentBeat
    self.currentBeat = beat
    self.guideActor:update(beat)
    self.playerActor:update(beat)

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

    for _, result in ipairs(self.tapJudgment:update(beat)) do
        self.tapResult = result.result
    end
    for _, result in ipairs(self.longJudgment:update(beat)) do
        self.longResult = result.result
        if result.phase == "RELEASE" then self.playerActor:stopLong() end
    end
end

function Runtime:keypressed(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
    if not self:applyLongPress(beat) then self:applyTapInput(beat) end
end

function Runtime:keyreleased(key, beat)
    if key ~= "space" or not self.stage or self.autoPlay ~= "none" then return end
    self:applyLongRelease(beat)
end

function Runtime:draw(width, height)
    self.background:draw(width, height)
    self.guideActor:draw(width, height, self.currentBeat)
    self.playerActor:draw(width, height, self.currentBeat)
end

return Runtime
