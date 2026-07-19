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
