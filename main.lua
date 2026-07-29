local activeApp = nil

local function containsArgument(arguments, expected)
    for _, argument in ipairs(arguments or {}) do
        if argument == expected then
            return true
        end
    end

    return false
end

local function runTests()
    local succeeded, errorMessage = xpcall(function()
        local TestRunner = require("tests.TestRunner")
        TestRunner.run()
    end, debug.traceback)

    if not succeeded then
        io.stderr:write(errorMessage .. "\n")
    end

    love.event.quit(succeeded and 0 or 1)
end

function love.load(arguments)
    if containsArgument(arguments, "--test") then
        runTests()
        return
    end

    local AppFont = require("launcher.AppFont")
    local Launcher = require("launcher.Launcher")
    AppFont.apply()
    activeApp = Launcher.new()
end

function love.update(deltaTime)
    if activeApp and activeApp.update then
        activeApp:update(deltaTime)
    end
end

function love.draw()
    if activeApp and activeApp.draw then
        activeApp:draw()
    end
end

function love.keypressed(key, scanCode, isRepeat)
    if activeApp and activeApp.keypressed then
        activeApp:keypressed(key, scanCode, isRepeat)
    end
end

function love.keyreleased(key, scanCode)
    if activeApp and activeApp.keyreleased then
        activeApp:keyreleased(key, scanCode)
    end
end

function love.mousemoved(x, y, deltaX, deltaY, isTouch)
    if activeApp and activeApp.mousemoved then
        activeApp:mousemoved(x, y, deltaX, deltaY, isTouch)
    end
end

function love.wheelmoved(deltaX, deltaY)
    if activeApp and activeApp.wheelmoved then
        activeApp:wheelmoved(deltaX, deltaY)
    end
end

function love.mousepressed(x, y, button, isTouch, presses)
    if activeApp and activeApp.mousepressed then
        activeApp:mousepressed(x, y, button, isTouch, presses)
    end
end

function love.mousereleased(x, y, button, isTouch, presses)
    if activeApp and activeApp.mousereleased then
        activeApp:mousereleased(x, y, button, isTouch, presses)
    end
end

function love.textinput(text)
    if activeApp and activeApp.textinput then
        activeApp:textinput(text)
    end
end
