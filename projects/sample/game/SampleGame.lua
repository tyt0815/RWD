local SampleGame = {}
SampleGame.__index = SampleGame

function SampleGame.new(project)
    return setmetatable({
        project = project,
        elapsedTime = 0,
    }, SampleGame)
end

function SampleGame:update(deltaTime)
    self.elapsedTime = self.elapsedTime + deltaTime
end

function SampleGame:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()

    love.graphics.clear(0.06, 0.08, 0.12, 1)
    love.graphics.setColor(0.55, 0.9, 1, 1)
    love.graphics.printf(self.project.title, 0, height * 0.4, width, "center")
    love.graphics.setColor(0.75, 0.78, 0.84, 1)
    love.graphics.printf("Standalone game project", 0, height * 0.4 + 36, width, "center")
    love.graphics.printf("Esc: Back to launcher", 0, height - 56, width, "center")
end

return SampleGame
