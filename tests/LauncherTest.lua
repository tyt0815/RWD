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
            coreApiVersion = 2,
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

local function newStageRepository()
    return {
        listStages = function() return {}, nil end,
        stageExists = function() return false, nil end,
        load = function() return nil, "not used", "NOT_FOUND" end,
        save = function() return true, nil end,
    }
end

return {
    {
        name = "앱 기본 폰트는 한글을 지원하는 D2Coding TTC를 사용한다",
        run = function(test)
            local AppFont = require("launcher.AppFont")
            local state = {}
            local graphics = {
                newFont = function(path, size)
                    state.path = path
                    state.size = size
                    return { id = "font" }
                end,
                setFont = function(font) state.font = font end,
            }

            local font = AppFont.apply(graphics)

            test.assertEqual(state.path,
                "assets/fonts/D2Coding-Ver1.3.3-20260725-all.ttc")
            test.assertEqual(state.size, 14)
            test.assertEqual(state.font, font)

            local actualFont = love.graphics.newFont(state.path, state.size)
            test.assertTrue(actualFont:hasGlyphs("스피키송", "흐에", "네르지마세요"))
        end,
    },
    {
        name = "LÖVE wheel과 mouse release callback이 등록된다",
        run = function(test)
            test.assertTrue(type(love.wheelmoved) == "function")
            test.assertTrue(type(love.mousereleased) == "function")
        end,
    },
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
        name = "실행기는 주입된 StageRepository를 에디터 세션에 그대로 전달한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local stageRepository = newStageRepository()
            local launcher = Launcher.new({
                stageRepository = stageRepository,
            })

            launcher:openEditor()

            test.assertEqual(
                launcher.activeApp:getSession().stageRepository,
                stageRepository
            )
        end,
    },
    {
        name = "실행기는 같은 StageRepository를 Rhythm Dotgeo에 전달한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local stageRepository = newStageRepository()
            local launcher = Launcher.new({
                stageRepository = stageRepository,
            })

            local opened = launcher:openProject("rhythm_dotgeo")

            test.assertEqual(opened, true)
            test.assertEqual(launcher.activeApp.stageRepository, stageRepository)
        end,
    },
    {
        name = "에디터 preview 게임 factory도 같은 StageRepository를 전달한다",
        run = function(test)
            local receivedOptions
            withProjectFixture("preview-repository", function()
                return {
                    new = function(_, options)
                        receivedOptions = options
                        return {}
                    end,
                }
            end, function()
                local Launcher = require("launcher.Launcher")
                local stageRepository = newStageRepository()
                local launcher = Launcher.new({
                    stageRepository = stageRepository,
                })
                launcher:openEditor()
                local session = launcher.activeApp:getSession()
                local project = assert(
                    session.projectCatalog:getProject("preview-repository")
                )

                local game, errorMessage = session.projectCatalog:createGame(project)

                test.assertTrue(game ~= nil, errorMessage)
                test.assertEqual(receivedOptions.stageRepository, stageRepository)
            end)
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
        name = "2 키로 Rhythm Dotgeo 프로젝트를 연다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            launcher:keypressed("2")

            test.assertEqual(launcher:getMode(), "project:rhythm_dotgeo")
            test.assertEqual(launcher.activeApp:getScreen(), "stageSelect")
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
            local moved, pressed, released, entered, wheeled
            launcher.activeApp.mousemoved = function(_, x, y, deltaX, deltaY, isTouch)
                moved = { x, y, deltaX, deltaY, isTouch }
            end
            launcher.activeApp.mousepressed = function(_, x, y, button, isTouch, presses)
                pressed = { x, y, button, isTouch, presses }
            end
            launcher.activeApp.mousereleased = function(_, x, y, button, isTouch, presses)
                released = { x, y, button, isTouch, presses }
            end
            launcher.activeApp.textinput = function(_, text)
                entered = text
            end
            launcher.activeApp.wheelmoved = function(_, deltaX, deltaY)
                wheeled = { deltaX, deltaY }
            end

            launcher:mousemoved(10, 20, 3, 4, true)
            launcher:mousepressed(30, 40, 1, false, 2)
            launcher:mousereleased(50, 60, 3, true, 1)
            launcher:textinput("stage")
            launcher:wheelmoved(-1, 2)

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
            test.assertEqual(released[1], 50)
            test.assertEqual(released[2], 60)
            test.assertEqual(released[3], 3)
            test.assertEqual(released[4], true)
            test.assertEqual(released[5], 1)
            test.assertEqual(entered, "stage")
            test.assertEqual(wheeled[1], -1)
            test.assertEqual(wheeled[2], 2)

            launcher:keypressed("escape")

            test.assertEqual(launcher:getMode(), "editor")
            test.assertTrue(launcher.activeApp ~= nil)
        end,
    },
    {
        name = "wheel 입력은 menu와 wheel handler 없는 Project 동작을 바꾸지 않는다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            launcher:wheelmoved(0, 1)
            test.assertEqual(launcher:getMode(), "menu")

            assert(launcher:openProject("sample"))
            launcher:wheelmoved(0, -1)
            test.assertEqual(launcher:getMode(), "project:sample")
        end,
    },
    {
        name = "Project에서 Launcher로 돌아갈 때 재생을 정리한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()
            local stopped = false
            launcher.activeApp = {
                stop = function() stopped = true end,
            }
            launcher.mode = "project:test"

            launcher:returnToMenu()

            test.assertEqual(stopped, true)
            test.assertEqual(launcher:getMode(), "menu")
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
