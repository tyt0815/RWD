local function withProjectFixture(projectId, gameModuleFactory, run)
    local projectModuleName = "projects." .. projectId .. ".project"
    local gameModuleName = "projects." .. projectId .. ".game.TestGame"
    local previousProjectPreload = package.preload[projectModuleName]
    local previousProjectLoaded = package.loaded[projectModuleName]
    local previousGamePreload = package.preload[gameModuleName]
    local previousGameLoaded = package.loaded[gameModuleName]

    package.preload[projectModuleName] = function()
        return {
            id = projectId,
            title = "Test Project",
            coreApiVersion = 1,
            entryModule = gameModuleName,
        }
    end
    package.loaded[projectModuleName] = nil
    package.preload[gameModuleName] = gameModuleFactory
    package.loaded[gameModuleName] = nil

    local succeeded, errorMessage = xpcall(run, debug.traceback)

    package.preload[projectModuleName] = previousProjectPreload
    package.loaded[projectModuleName] = previousProjectLoaded
    package.preload[gameModuleName] = previousGamePreload
    package.loaded[gameModuleName] = previousGameLoaded

    if not succeeded then
        error(errorMessage, 0)
    end
end

return {
    {
        name = "실행기는 메뉴 모드로 시작한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            test.assertEqual(launcher:getMode(), "menu")
        end,
    },
    {
        name = "에디터 모드로 전환한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            launcher:openEditor()
            test.assertEqual(launcher:getMode(), "editor")
            test.assertTrue(launcher.activeApp ~= nil)
        end,
    },
    {
        name = "sample 프로젝트 모드로 전환한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            local succeeded = launcher:openProject("sample")
            test.assertEqual(succeeded, true)
            test.assertEqual(launcher:getMode(), "project:sample")

            local receivedWidth, receivedHeight
            launcher.activeApp.draw = function(_, width, height)
                receivedWidth, receivedHeight = width, height
            end
            local previousLove = love
            love = {
                graphics = {
                    getDimensions = function()
                        return 640, 360
                    end,
                },
            }
            local drawn, drawError = pcall(function()
                launcher:draw()
            end)
            love = previousLove

            test.assertTrue(drawn, drawError)
            test.assertEqual(receivedWidth, 640)
            test.assertEqual(receivedHeight, 360)
        end,
    },
    {
        name = "없는 프로젝트는 메뉴에 남아 오류를 기록한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            local succeeded = launcher:openProject("missing")
            test.assertEqual(succeeded, false)
            test.assertEqual(launcher:getMode(), "menu")
            test.assertContains(launcher:getErrorMessage(), "Failed to load project")
        end,
    },
    {
        name = "게임 생성자가 예외를 던지면 메뉴에 남아 오류를 기록한다",
        run = function(test)
            withProjectFixture("throwing-constructor", function()
                return {
                    new = function()
                        error("constructor exploded")
                    end,
                }
            end, function()
                local Launcher = require("launcher.Launcher")
                local launcher = Launcher.new()

                local succeeded = launcher:openProject("throwing-constructor")
                local errorMessage = launcher:getErrorMessage()

                test.assertEqual(succeeded, false)
                test.assertEqual(launcher:getMode(), "menu")
                test.assertTrue(type(errorMessage) == "string" and errorMessage ~= "")
            end)
        end,
    },
    {
        name = "게임 생성자가 nil을 반환하면 메뉴에 남아 오류를 기록한다",
        run = function(test)
            withProjectFixture("nil-constructor", function()
                return {
                    new = function()
                        return nil
                    end,
                }
            end, function()
                local Launcher = require("launcher.Launcher")
                local launcher = Launcher.new()

                local succeeded = launcher:openProject("nil-constructor")
                local errorMessage = launcher:getErrorMessage()

                test.assertEqual(succeeded, false)
                test.assertEqual(launcher:getMode(), "menu")
                test.assertTrue(type(errorMessage) == "string" and errorMessage ~= "")
            end)
        end,
    },
    {
        name = "editor handles Escape without leaving launcher editor mode",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()
            launcher:openEditor()
            local moved, pressed, entered
            launcher.activeApp.mousemoved = function(_, x, y, deltaX, deltaY, isTouch)
                moved = { x, y, deltaX, deltaY, isTouch }
            end
            launcher.activeApp.mousepressed = function(_, x, y, button, isTouch, presses)
                pressed = { x, y, button, isTouch, presses }
            end
            launcher.activeApp.textinput = function(_, text)
                entered = text
            end

            launcher:mousemoved(10, 20, 3, 4, true)
            launcher:mousepressed(30, 40, 1, false, 2)
            launcher:textinput("stage")

            test.assertEqual(moved[1], 10)
            test.assertEqual(moved[2], 20)
            test.assertEqual(moved[3], 3)
            test.assertEqual(moved[4], 4)
            test.assertEqual(moved[5], true)
            test.assertEqual(pressed[1], 30)
            test.assertEqual(pressed[2], 40)
            test.assertEqual(pressed[3], 1)
            test.assertEqual(pressed[4], false)
            test.assertEqual(pressed[5], 2)
            test.assertEqual(entered, "stage")

            launcher:keypressed("escape")

            test.assertEqual(launcher:getMode(), "editor")
            test.assertTrue(launcher.activeApp ~= nil)
        end,
    },
    {
        name = "editor menu Quit returns to launcher menu",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()
            launcher:openEditor()

            launcher.activeApp:executeAction("quit")

            test.assertEqual(launcher:getMode(), "menu")
            test.assertEqual(launcher.activeApp, nil)
        end,
    },
}
