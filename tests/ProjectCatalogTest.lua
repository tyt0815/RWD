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
            local modules = {
                ["projects.zeta.project"] = manifest("zeta"),
                ["projects.alpha.project"] = manifest("alpha"),
                ["projects.bad.project"] = { id = "bad" },
            }
            local catalog = ProjectCatalog.new({
                listDirectory = function() return { "zeta", "bad", "alpha" } end,
                loadModule = function(name) return modules[name] end,
                coreApiVersion = 1,
            })
            local projects = catalog:listProjects()
            test.assertEqual(#projects, 2)
            test.assertEqual(projects[1].id, "alpha")
            test.assertEqual(projects[2].id, "zeta")
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
            local project, errorMessage = catalog:getProject("future")
            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Core API")
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
        name = "Project 게임 생성의 예외를 안전한 오류로 바꾼다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function(name)
                    if name == "games.throwing" then
                        return { new = function() error("boom") end }
                    end
                    return manifest("throwing")
                end,
                coreApiVersion = 1,
            })
            local game, errorMessage = catalog:createGame(manifest("throwing"))
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "Failed to create game")
        end,
    },
}
