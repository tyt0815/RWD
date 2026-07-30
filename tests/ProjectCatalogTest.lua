local function manifest(id, coreApiVersion)
    return {
        id = id,
        title = id .. " title",
        coreApiVersion = coreApiVersion or 1,
        entryModule = "games." .. id,
    }
end

return {
    {
        name = "Project 목록은 유효한 매니페스트만 제목 순으로 반환한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local zetaProject = manifest("zeta")
            zetaProject.title = "A Project"
            local alphaProject = manifest("alpha")
            alphaProject.title = "Z Project"
            local modules = {
                ["projects.zeta.project"] = zetaProject,
                ["projects.alpha.project"] = alphaProject,
                ["projects.bad.project"] = { id = "bad" },
            }
            local catalog = ProjectCatalog.new({
                listDirectory = function() return { "zeta", "bad", "alpha" } end,
                loadModule = function(name) return modules[name] end,
                coreApiVersion = 1,
            })
            local projects = catalog:listProjects()
            test.assertEqual(#projects, 2)
            test.assertEqual(projects[1].title, "A Project")
            test.assertEqual(projects[1].id, "zeta")
            test.assertEqual(projects[2].title, "Z Project")
            test.assertEqual(projects[2].id, "alpha")
        end,
    },
    {
        name = "Core API가 맞지 않는 Project는 열지 않는다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return { "future" } end,
                loadModule = function() return manifest("future", 2) end,
                coreApiVersion = 1,
            })
            local project, errorMessage, errorCode = catalog:getProject("future")
            local Core = require("core")
            local _, expectedMessage, expectedCode = Core.ProjectManifest.validate(
                manifest("future", 2),
                {
                    expectedId = "future",
                    expectedCoreApiVersion = 1,
                }
            )
            test.assertEqual(project, nil)
            test.assertEqual(errorMessage, expectedMessage)
            test.assertEqual(errorCode, expectedCode)
        end,
    },
    {
        name = "Project directory ID 불일치는 ProjectManifest 오류 계약을 사용한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local project = manifest("other")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function() return project end,
                coreApiVersion = 1,
            })
            local loadedProject, errorMessage, errorCode = catalog:getProject("expected")
            local Core = require("core")
            local _, expectedMessage, expectedCode = Core.ProjectManifest.validate(
                project,
                {
                    expectedId = "expected",
                    expectedCoreApiVersion = 1,
                }
            )

            test.assertEqual(loadedProject, nil)
            test.assertEqual(errorMessage, expectedMessage)
            test.assertEqual(errorCode, expectedCode)
        end,
    },
    {
        name = "존재하지 않는 Project 오류를 문자열로 반환한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function() error("missing") end,
                coreApiVersion = 1,
            })
            local project, errorMessage = catalog:getProject("missing")
            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Failed to load project")
        end,
    },
    {
        name = "Project 게임 생성은 주입된 factory에 위임하고 오류를 안전하게 반환한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local project = manifest("delegated")
            local expectedGame = {}
            local receivedProject = nil
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function()
                    error("game entry modules must not be loaded")
                end,
                createGame = function(forwardedProject)
                    receivedProject = forwardedProject
                    return expectedGame
                end,
                coreApiVersion = 1,
            })

            local game, errorMessage = catalog:createGame(project)
            test.assertEqual(receivedProject, project)
            test.assertEqual(game, expectedGame)
            test.assertEqual(errorMessage, nil)

            local failedCatalog = ProjectCatalog.new({
                createGame = function()
                    return nil, "delegated failure"
                end,
            })
            game, errorMessage = failedCatalog:createGame(project)
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "delegated failure")

            local throwingCatalog = ProjectCatalog.new({
                createGame = function()
                    error("boom")
                end,
            })
            game, errorMessage = throwingCatalog:createGame(project)
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "Failed to create game")
            test.assertContains(errorMessage, "boom")

            local invalidCatalog = ProjectCatalog.new({
                createGame = function()
                    return "not a game"
                end,
            })
            game, errorMessage = invalidCatalog:createGame(project)
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "must return a table")

            local unconfiguredCatalog = ProjectCatalog.new()
            game, errorMessage = unconfiguredCatalog:createGame(project)
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "not configured")
        end,
    },
}
