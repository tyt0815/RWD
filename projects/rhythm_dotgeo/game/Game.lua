local Core = require("core")
local StagePlayback = require("projects.rhythm_dotgeo.game.StagePlayback")
local StageSelect = require("projects.rhythm_dotgeo.game.StageSelect")

local Game = {}
Game.__index = Game

function Game.new(project, options)
    options = options or {}
    local stageSelect = StageSelect.new(options.stageRepository, project.id)
    local categoryHost, hostError = Core.ProjectCategories.createHost(project, {
        runtimeOptions = options.categoryOptions,
    })
    if not categoryHost then error(hostError) end
    local playbackOptions = {}
    for key, value in pairs(options) do playbackOptions[key] = value end
    playbackOptions.categoryHost = categoryHost
    local self = setmetatable({
        project = project,
        stageRepository = options.stageRepository,
        stageSelect = stageSelect,
        categoryHost = categoryHost,
        playback = StagePlayback.new(project, playbackOptions),
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
    local stage, loadError = self.stageRepository:load(self.project.id, stageId)
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

function Game:update(deltaTime, beat, realDeltaTime)
    if self.screen ~= "stage" then return end
    local updated, updateError = self.playback:update(
        self,
        deltaTime,
        beat,
        realDeltaTime
    )
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

function Game:setAutoPlay(value)
    self.categoryHost:setAutoPlay(value or "none")
end

function Game:keypressed(key, beat)
    if self.screen ~= "stage" or not self:isInputEnabled() then return false end
    self.categoryHost:keypressed(
        key,
        type(beat) == "number" and beat or self.currentBeat
    )
    return true
end

function Game:keyreleased(key, beat)
    if self.screen ~= "stage" or not self:isInputEnabled() then return false end
    self.categoryHost:keyreleased(
        key,
        type(beat) == "number" and beat or self.currentBeat
    )
    return true
end

function Game:getCategoryRuntime(categoryId)
    return self.categoryHost:getRuntime(categoryId)
end

function Game:stop()
    local stopped, stopError = self.playback:stop()
    self.categoryHost:stop()
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
    self.categoryHost:draw(width, height)
    if self.errorMessage then
        love.graphics.setColor(1, 0.45, 0.45, 1)
        love.graphics.printf(self.errorMessage, width * 0.2, height * 0.6, width * 0.6, "center")
    end
end

return Game
