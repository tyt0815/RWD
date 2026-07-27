local Core = require("core")

local SampleGame = {}
SampleGame.__index = SampleGame

function SampleGame.new(project, options)
    options = options or {}
    local categoryHost, hostError = Core.ProjectCategories.createHost(project, {
        runtimeOptions = options.categoryOptions,
    })
    if not categoryHost then error(hostError) end

    return setmetatable({
        project = project,
        categoryHost = categoryHost,
        elapsedTime = 0,
        stage = nil,
        currentBeat = 0,
        stageRuntime = Core.StageRuntime.new(),
    }, SampleGame)
end

-- Game은 Category 구현을 알지 않는다. Core occurrence를 자동 발견된 Runtime에 전달한다.
-- 새 Category 폴더를 추가해도 이 파일의 require나 handler map은 수정하지 않는다.
function SampleGame:startStage(stage, startBeat)
    self.stage = stage
    self.currentBeat = startBeat or 0
    self.stageRuntime = Core.StageRuntime.new()
    self.categoryHost:startStage(stage, self.currentBeat)

    local occurrences, runtimeError = self.stageRuntime:start(stage, self.currentBeat)
    if not occurrences then return nil, runtimeError end
    self.categoryHost:applyOccurrences(occurrences, self.currentBeat)
    return true, nil
end

function SampleGame:setAutoPlay(value)
    self.categoryHost:setAutoPlay(value or "none")
end

function SampleGame:update(deltaTime, beat)
    self.elapsedTime = self.elapsedTime + deltaTime
    if not self.stage or beat == nil then return end

    local occurrences, runtimeError = self.stageRuntime:update(beat)
    if not occurrences then error(runtimeError) end
    self.currentBeat = self.stageRuntime:getCurrentBeat()
    self.categoryHost:applyOccurrences(occurrences, self.currentBeat)
    self.categoryHost:update(deltaTime, self.currentBeat)
end

function SampleGame:keypressed(key, beat)
    if not self.stage or not self.stageRuntime:isInputEnabled() then return end
    self.categoryHost:keypressed(key, beat)
end

function SampleGame:getCategoryRuntime(categoryId)
    return self.categoryHost:getRuntime(categoryId)
end

function SampleGame:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    love.graphics.clear(0, 0, 0, 1)
    if not self.stage then return end
    self.categoryHost:draw(width, height)
end

return SampleGame
