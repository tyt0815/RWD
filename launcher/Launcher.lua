local Core = require("core")
local Editor = require("editor")
local ProjectLoader = require("launcher.ProjectLoader")

local Launcher = {}
Launcher.__index = Launcher

function Launcher.new()
    return setmetatable({
        mode = "menu",
        activeApp = nil,
        errorMessage = nil,
    }, Launcher)
end

function Launcher:getMode()
    return self.mode
end

function Launcher:getErrorMessage()
    return self.errorMessage
end

function Launcher:openEditor()
    local launcher = self
    self.activeApp = Editor.createApp({
        createGame = ProjectLoader.createGame,
        onQuit = function()
            launcher:returnToMenu()
        end,
    })
    self.mode = "editor"
    self.errorMessage = nil
    return true
end

function Launcher:openProject(projectId)
    local project, loadError = ProjectLoader.loadProject(projectId, Core.CORE_API_VERSION)
    if not project then
        self.activeApp = nil
        self.mode = "menu"
        self.errorMessage = loadError
        return false
    end

    local game, createError = ProjectLoader.createGame(project)
    if not game then
        self.activeApp = nil
        self.mode = "menu"
        self.errorMessage = createError
        return false
    end

    self.activeApp = game
    self.mode = "project:" .. project.id
    self.errorMessage = nil
    return true
end

function Launcher:returnToMenu()
    self.activeApp = nil
    self.mode = "menu"
    self.errorMessage = nil
end

function Launcher:update(deltaTime)
    if self.activeApp and self.activeApp.update then
        self.activeApp:update(deltaTime)
    end
end

function Launcher:mousemoved(x, y, deltaX, deltaY, isTouch)
    if self.activeApp and self.activeApp.mousemoved then
        self.activeApp:mousemoved(x, y, deltaX, deltaY, isTouch)
    end
end

function Launcher:wheelmoved(deltaX, deltaY)
    if self.activeApp and self.activeApp.wheelmoved then
        self.activeApp:wheelmoved(deltaX, deltaY)
    end
end

function Launcher:mousepressed(x, y, button, isTouch, presses)
    if self.activeApp and self.activeApp.mousepressed then
        self.activeApp:mousepressed(x, y, button, isTouch, presses)
    end
end

function Launcher:mousereleased(x, y, button, isTouch, presses)
    if self.activeApp and self.activeApp.mousereleased then
        self.activeApp:mousereleased(x, y, button, isTouch, presses)
    end
end

function Launcher:textinput(text)
    if self.activeApp and self.activeApp.textinput then
        self.activeApp:textinput(text)
    end
end

local function drawMenu(errorMessage)
    local width, height = love.graphics.getDimensions()

    love.graphics.clear(0.07, 0.08, 0.1, 1)
    love.graphics.setColor(0.92, 0.93, 0.96, 1)
    love.graphics.printf("RWD", 0, height * 0.28, width, "center")
    love.graphics.printf("E: Editor", 0, height * 0.42, width, "center")
    love.graphics.printf("1: Sample Project", 0, height * 0.42 + 32, width, "center")
    love.graphics.printf("Esc: Quit", 0, height * 0.42 + 64, width, "center")

    if errorMessage then
        love.graphics.setColor(1, 0.45, 0.45, 1)
        love.graphics.printf(errorMessage, width * 0.15, height * 0.68, width * 0.7, "center")
    end
end

function Launcher:draw()
    if self.activeApp and self.activeApp.draw then
        local width, height = love.graphics.getDimensions()
        self.activeApp:draw(width, height)
        return
    end

    drawMenu(self.errorMessage)
end

function Launcher:keypressed(key, scanCode, isRepeat)
    if self.activeApp then
        if self.activeApp.keypressed
            and self.activeApp:keypressed(key, scanCode, isRepeat) then
            return
        end
        if key == "escape" then
            self:returnToMenu()
        end
        return
    end

    if key == "e" then
        self:openEditor()
    elseif key == "1" then
        self:openProject("sample")
    elseif key == "escape" then
        love.event.quit()
    end
end

return Launcher
