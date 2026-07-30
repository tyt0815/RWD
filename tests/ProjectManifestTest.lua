local function projectWith(categories)
    return {
        id = "sample",
        title = "Sample",
        coreApiVersion = 1,
        entryModule = "projects.sample.game.SampleGame",
        eventCategories = categories,
    }
end

local function category(id, events)
    return {
        id = id,
        label = id,
        runtimeModule = "projects.sample.game." .. id .. ".Runtime",
        events = events,
    }
end

local function event(id)
    return { id = id, label = id, properties = {} }
end

local function validate(project)
    local Core = require("core")
    return Core.ProjectManifest.validate(project, {
        expectedId = "sample",
        expectedCoreApiVersion = 1,
    })
end

return {
    {
        name = "ProjectManifest는 다른 Category의 같은 Event ID를 허용한다",
        run = function(test)
            local valid, message, code = validate(projectWith({
                category("first", { event("spawn") }),
                category("second", { event("spawn") }),
            }))

            test.assertEqual(valid, true)
            test.assertEqual(message, nil)
            test.assertEqual(code, nil)
        end,
    },
    {
        name = "ProjectManifest는 같은 Category의 같은 Event ID를 거부한다",
        run = function(test)
            local valid, _, code = validate(projectWith({
                category("first", { event("spawn"), event("spawn") }),
            }))

            test.assertEqual(valid, nil)
            test.assertEqual(code, "INVALID_PROJECT")
        end,
    },
    {
        name = "ProjectManifest는 manifest 구조 오류를 INVALID_PROJECT로 반환한다",
        run = function(test)
            local cases = {
                projectWith({
                    category("first", {}),
                    category("first", {}),
                }),
                (function()
                    local project = projectWith({})
                    project.id = "other"
                    return project
                end)(),
                (function()
                    local project = projectWith({})
                    project.coreApiVersion = 2
                    return project
                end)(),
                (function()
                    local project = projectWith({})
                    project.entryModule = ""
                    return project
                end)(),
                projectWith({
                    category("first", {
                        {
                            id = "spawn",
                            label = "Spawn",
                            properties = {
                                {
                                    id = "delay",
                                    kind = "number",
                                    default = math.huge,
                                },
                            },
                        },
                    }),
                }),
            }

            for _, project in ipairs(cases) do
                local valid, _, code = validate(project)
                test.assertEqual(valid, nil)
                test.assertEqual(code, "INVALID_PROJECT")
            end
        end,
    },
}
