local Game = {}
Game.__index = Game

function Game.new(project)
    return setmetatable({
        project = project,
        stage = nil,
        currentBeat = 0,
    }, Game)
end

function Game:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
end

function Game:update(deltaTime, beat)
    if beat ~= nil then
        self.currentBeat = beat
    end
end

function Game:draw(width, height)
    love.graphics.clear(0.07, 0.08, 0.1, 1)
    love.graphics.setColor(0.92, 0.93, 0.96, 1)
    love.graphics.printf(self.project.title, 0, height * 0.45, width, "center")
end

return Game
