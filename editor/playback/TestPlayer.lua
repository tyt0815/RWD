local TestPlayer = {}
TestPlayer.__index = TestPlayer

local function defaultGraphics()
    return love.graphics
end

function TestPlayer.new(options)
    options = options or {}
    return setmetatable({
        createGame = options.createGame,
        graphics = options.graphics or defaultGraphics(),
        game = nil,
        canvas = nil,
        canvasWidth = nil,
        canvasHeight = nil,
        playing = false,
    }, TestPlayer)
end

function TestPlayer:start(project, stage, startBeat, autoPlay)
    self:stop()

    if type(self.createGame) ~= "function" then
        return nil, "TestPlayer requires createGame(project)."
    end

    local succeeded, game, errorMessage = pcall(self.createGame, project)
    if not succeeded then
        return nil, "Project preview creation failed: " .. tostring(game)
    end

    if type(game) ~= "table" then
        return nil, "Project preview creation failed: "
            .. tostring(errorMessage or "createGame(project) must return a game table.")
    end

    if game.setAutoPlay then
        local autoPlaySet, autoPlayError = pcall(
            game.setAutoPlay,
            game,
            autoPlay or "none"
        )
        if not autoPlaySet then
            return nil, "Project Auto Play setup failed: " .. tostring(autoPlayError)
        end
    end

    if stage and game.startStage then
        local stageCalled, stageResult, stageError = pcall(
            game.startStage,
            game,
            stage,
            startBeat or 0
        )
        if not stageCalled then
            return nil, "Project Stage start failed: " .. tostring(stageResult)
        end
        if stageResult == false or (stageResult == nil and stageError ~= nil) then
            return nil, "Project Stage start failed: " .. tostring(stageError)
        end
    end

    self.game = game
    self.playing = true
    return true, nil
end

function TestPlayer:stop()
    if self.game and self.game.stop then pcall(self.game.stop, self.game) end
    self.game = nil
    self.canvas = nil
    self.canvasWidth = nil
    self.canvasHeight = nil
    self.playing = false
end

function TestPlayer:isPlaying()
    return self.playing
end

function TestPlayer:update(deltaTime, beat, realDeltaTime)
    if not self.playing or not self.game or not self.game.update then
        return true, nil
    end

    local succeeded, errorMessage = pcall(
        self.game.update,
        self.game,
        deltaTime,
        beat,
        realDeltaTime
    )
    if not succeeded then
        return nil, "Project preview update failed: " .. tostring(errorMessage)
    end

    return true, nil
end

local function sendInput(self, methodName, key, beat)
    if not self.playing or not self.game or not self.game[methodName] then
        return true, nil
    end
    local succeeded, errorMessage = pcall(
        self.game[methodName],
        self.game,
        key,
        beat
    )
    if not succeeded then
        return nil, "Project preview input failed: " .. tostring(errorMessage)
    end
    return true, nil
end

function TestPlayer:keypressed(key, beat)
    return sendInput(self, "keypressed", key, beat)
end

function TestPlayer:keyreleased(key, beat)
    return sendInput(self, "keyreleased", key, beat)
end

function TestPlayer:draw(rect)
    if not self.playing or not self.game then
        return true, nil
    end

    if self.canvasWidth ~= rect.width or self.canvasHeight ~= rect.height then
        self.canvas = self.graphics.newCanvas(rect.width, rect.height)
        self.canvasWidth = rect.width
        self.canvasHeight = rect.height
    end

    self.graphics.push("all")
    self.graphics.setCanvas(self.canvas)
    self.graphics.clear(0, 0, 0, 1)
    local succeeded, errorMessage = pcall(function()
        if self.game.draw then
            self.game:draw(rect.width, rect.height)
        end
    end)
    self.graphics.pop()

    if not succeeded then
        return nil, "Project preview draw failed: " .. tostring(errorMessage)
    end

    self.graphics.draw(self.canvas, rect.x, rect.y)
    return true, nil
end

return TestPlayer
