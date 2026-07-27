return {
    {
        name = "sample 프로젝트 매니페스트를 로드한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project, errorMessage = ProjectLoader.loadProject("sample", 1)

            test.assertEqual(errorMessage, nil)
            test.assertEqual(project.id, "sample")
            test.assertEqual(project.title, "Sample Project")
            test.assertEqual(project.entryModule, "projects.sample.game.SampleGame")
        end,
    },
    {
        name = "없는 프로젝트는 오류를 반환한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project, errorMessage = ProjectLoader.loadProject("missing", 1)

            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Failed to load project")
        end,
    },
    {
        name = "게임 생성자에 StageStore를 주입한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local gameModuleName = "projects.stage-store-test.game.Game"
            local receivedOptions
            package.preload[gameModuleName] = function()
                return {
                    new = function(_, options)
                        receivedOptions = options
                        return {}
                    end,
                }
            end
            package.loaded[gameModuleName] = nil
            local stageStore = {}
            local transportFactory = function() end

            local game, errorMessage = ProjectLoader.createGame({
                id = "stage-store-test",
                entryModule = gameModuleName,
            }, {
                stageStore = stageStore,
                standalone = true,
                transportFactory = transportFactory,
            })

            package.preload[gameModuleName] = nil
            package.loaded[gameModuleName] = nil

            test.assertTrue(game ~= nil, errorMessage)
            test.assertEqual(receivedOptions.stageStore, stageStore)
            test.assertEqual(receivedOptions.standalone, true)
            test.assertEqual(receivedOptions.transportFactory, transportFactory)
        end,
    },
    {
        name = "코어 API 버전이 다르면 프로젝트를 거부한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local moduleName = "projects.incompatible.project"

            package.preload[moduleName] = function()
                return {
                    id = "incompatible",
                    title = "Incompatible Project",
                    coreApiVersion = 999,
                    entryModule = "projects.sample.game.SampleGame",
                }
            end
            package.loaded[moduleName] = nil

            local project, errorMessage = ProjectLoader.loadProject("incompatible", 1)

            package.preload[moduleName] = nil
            package.loaded[moduleName] = nil

            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Core API version mismatch")
        end,
    },
}
