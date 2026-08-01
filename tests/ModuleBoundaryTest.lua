local function startsWith(value, prefix)
    return value:sub(1, #prefix) == prefix
end

local function inspectRequire(path, moduleName, violations)
    local forbidden = false
    if startsWith(path, "core/") then
        forbidden = startsWith(moduleName, "editor.")
            or startsWith(moduleName, "launcher.")
            or startsWith(moduleName, "projects.")
    elseif startsWith(path, "editor/") then
        forbidden = startsWith(moduleName, "core.")
    elseif startsWith(path, "projects/") then
        forbidden = startsWith(moduleName, "core.")
            or startsWith(moduleName, "editor.")
            or startsWith(moduleName, "launcher.")
    elseif startsWith(path, "launcher/") then
        forbidden = startsWith(moduleName, "editor.stage.")
    end

    if forbidden then
        table.insert(violations, path .. " requires forbidden module " .. moduleName)
    end
end

local function findViolations(sources)
    local paths = {}
    for path in pairs(sources) do table.insert(paths, path) end
    table.sort(paths)

    local violations = {}
    for _, path in ipairs(paths) do
        local source = sources[path]
        for moduleName in source:gmatch('require%s*%(%s*"([^"]+)"%s*%)') do
            inspectRequire(path, moduleName, violations)
        end
        for moduleName in source:gmatch("require%s*%(%s*'([^']+)'%s*%)") do
            inspectRequire(path, moduleName, violations)
        end
    end
    return violations
end

local function collectLuaSources()
    local sources = {}

    local function collectDirectory(path)
        local items = love.filesystem.getDirectoryItems(path)
        table.sort(items)
        for _, item in ipairs(items) do
            local childPath = path .. "/" .. item
            local info = love.filesystem.getInfo(childPath)
            if info and info.type == "directory" then
                collectDirectory(childPath)
            elseif info and info.type == "file" and childPath:match("%.lua$") then
                local source, readError = love.filesystem.read(childPath)
                assert(source, "Failed to read " .. childPath .. ": " .. tostring(readError))
                sources[childPath] = source
            end
        end
    end

    for _, root in ipairs({ "core", "editor", "launcher", "projects" }) do
        collectDirectory(root)
    end
    return sources
end

return {
    {
        name = "Module boundary scanner rejects a Project dependency on Editor Stage internals",
        run = function(test)
            local violations = findViolations({
                ["projects/demo/game/Game.lua"] =
                    'local StageStore = require("editor.stage.StageStore")',
            })

            test.assertEqual(#violations, 1)
            test.assertContains(violations[1], "projects/demo/game/Game.lua")
            test.assertContains(violations[1], "editor.stage.StageStore")
        end,
    },
    {
        name = "Module boundary scanner enforces every dependency direction for both quote styles",
        run = function(test)
            local violations = findViolations({
                ["core/Clock.lua"] = table.concat({
                    "require('editor.EditorApp')",
                    'require("launcher.Launcher")',
                    "require('projects.sample.project')",
                }, "\n"),
                ["editor/Stage.lua"] = table.concat({
                    'require("core")',
                    "require('core.StageSchema')",
                }, "\n"),
                ["projects/demo/game/Game.lua"] = table.concat({
                    'require("core.StageRuntime")',
                    "require('launcher.Launcher')",
                }, "\n"),
                ["launcher/Launcher.lua"] = table.concat({
                    "require('editor.stage.StageDocument')",
                    'require("editor.EditorApp")',
                }, "\n"),
            })
            local report = table.concat(violations, "\n")

            test.assertEqual(#violations, 7)
            test.assertContains(report, "core/Clock.lua")
            test.assertContains(report, "editor.EditorApp")
            test.assertContains(report, "launcher.Launcher")
            test.assertContains(report, "projects.sample.project")
            test.assertContains(report, "editor/Stage.lua")
            test.assertContains(report, "core.StageSchema")
            test.assertContains(report, "core.StageRuntime")
            test.assertContains(report, "editor.stage.StageDocument")
        end,
    },
    {
        name = "Core, Editor, Launcher, and Project sources respect module boundaries",
        run = function(test)
            local violations = findViolations(collectLuaSources())
            test.assertEqual(#violations, 0, table.concat(violations, "\n"))
        end,
    },
}
