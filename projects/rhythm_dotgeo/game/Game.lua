local StagePlayback = require("projects.rhythm_dotgeo.game.StagePlayback")
local StageSelect = require("projects.rhythm_dotgeo.game.StageSelect")

local Game = {}
Game.__index = Game

function Game.new(project, options)
    options = options or {}
    local stageSelect = StageSelect.new(options.stageStore, project.id)
    local self = setmetatable({
        project = project,
        stageStore = options.stageStore,
        stageSelect = stageSelect,
        playback = StagePlayback.new(project, options),
        screen = "stageSelect",
        stage = nil,
        transport = nil,
        currentBeat = 0,
        errorMessage = nil,
        width = 1920,
        height = 1080,
    }, Game)
    local refreshed, refreshError = stageSelect:refresh()
    if not refreshed then self.errorMessage = refreshError end
    return self
end

function Game:getScreen()
    return self.screen
end

function Game:getViewModel(width, height)
    return {
        screen = self.screen,
        stages = self.stageSelect:getItems(width or self.width, height or self.height),
        errorMessage = self.errorMessage,
    }
end

function Game:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    local started, startError = self.playback:start(self, stage, self.currentBeat)
    if not started then return nil, startError end

    self.transport = self.playback.transport
    self.currentBeat = self.playback:getBeat()
    self.screen = "stage"
    self.errorMessage = nil
    return true, nil
end

function Game:returnToStageSelect(errorMessage)
    self:stop()
    self.stage = nil
    self.screen = "stageSelect"
    self.errorMessage = errorMessage
end

function Game:startSelectedStage(stageId)
    local stage, loadError = self.stageStore:load(self.project.id, stageId)
    if not stage then
        self.errorMessage = loadError
        return false
    end

    local started, startError = self:startStage(stage, 0)
    if not started then
        self:returnToStageSelect(startError)
        return false
    end
    return true
end

function Game:update(deltaTime, beat)
    if self.screen ~= "stage" then return end
    local updated, updateError = self.playback:update(self, deltaTime, beat)
    if not updated then
        self.errorMessage = updateError
        self.playback:stop()
        self.transport = nil
        return
    end
    self.currentBeat = self.playback:getBeat()
end

function Game:isInputEnabled()
    return self.playback:isInputEnabled()
end

function Game:stop()
    local stopped, stopError = self.playback:stop()
    self.transport = nil
    return stopped, stopError
end

function Game:mousepressed(x, y, button)
    if self.screen ~= "stageSelect" then return false end
    local stageId = self.stageSelect:hitTest(x, y, button, self.width, self.height)
    if not stageId then return false end
    return self:startSelectedStage(stageId)
end

function Game:draw(width, height)
    self.width = width
    self.height = height
    if self.screen == "stageSelect" then
        self.stageSelect:draw(self.project.title, width, height, self.errorMessage)
        return
    end

    love.graphics.clear(0.07, 0.08, 0.1, 1)
    love.graphics.setColor(0.92, 0.93, 0.96, 1)
    love.graphics.printf(self.stage.name, 0, height * 0.45, width, "center")
    if self.errorMessage then
        love.graphics.setColor(1, 0.45, 0.45, 1)
        love.graphics.printf(self.errorMessage, width * 0.2, height * 0.6, width * 0.6, "center")
    end
end

return Game
