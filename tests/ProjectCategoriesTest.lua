return {
    {
        name = "ProjectCategories는 game 바로 아래 Category Definition을 자동 발견한다",
        run = function(test)
            local Core = require("core")
            local loadedModules = {}
            local categories, errorMessage = Core.ProjectCategories.discover({
                directoryPath = "projects/test/game",
                modulePrefix = "projects.test.game",
                listDirectory = function()
                    return { "Game.lua", "NewGameSample", "SampleGameplay" }
                end,
                isFile = function(path)
                    return path == "projects/test/game/NewGameSample/Definition.lua"
                        or path == "projects/test/game/NewGameSample/Runtime.lua"
                        or path == "projects/test/game/SampleGameplay/Definition.lua"
                        or path == "projects/test/game/SampleGameplay/Runtime.lua"
                end,
                loadModule = function(moduleName)
                    table.insert(loadedModules, moduleName)
                    if moduleName:find("NewGameSample", 1, true) then
                        return {
                            id = "newGameSample",
                            label = "New Game Sample",
                            events = {},
                        }
                    end
                    return {
                        id = "sampleGameplay",
                        label = "Sample Gameplay",
                        events = {},
                    }
                end,
            })

            test.assertEqual(errorMessage, nil)
            test.assertEqual(#categories, 2)
            test.assertEqual(categories[1].id, "newGameSample")
            test.assertEqual(categories[1].runtimeModule,
                "projects.test.game.NewGameSample.Runtime")
            test.assertEqual(categories[2].id, "sampleGameplay")
            test.assertEqual(#loadedModules, 2)
        end,
    },
    {
        name = "ProjectCategories Host는 Event를 소유 Category Runtime에 전달한다",
        run = function(test)
            local Core = require("core")
            local received = {}
            local project = {
                eventCategories = {
                    {
                        id = "gameplay",
                        label = "Gameplay",
                        runtimeModule = "projects.test.game.Gameplay.Runtime",
                        events = {
                            { id = "spawn", label = "Spawn", properties = {} },
                        },
                    },
                },
            }
            local host, errorMessage = Core.ProjectCategories.createHost(project, {
                loadModule = function(moduleName)
                    test.assertEqual(moduleName,
                        "projects.test.game.Gameplay.Runtime")
                    return {
                        new = function()
                            return {
                                startStage = function(_, stage, beat)
                                    received.stage = stage
                                    received.startBeat = beat
                                end,
                                handleEvent = function(_, event, occurrence, beat)
                                    received.event = event
                                    received.catchUp = occurrence.catchUp
                                    received.beat = beat
                                end,
                            }
                        end,
                    }
                end,
            })

            test.assertEqual(errorMessage, nil)
            local stage = { events = {} }
            host:startStage(stage, 2)
            host:applyOccurrences({
                {
                    event = {
                        id = "event-1",
                        type = "projectEvent",
                        eventId = "spawn",
                    },
                    catchUp = false,
                },
            }, 3)

            test.assertEqual(received.stage, stage)
            test.assertEqual(received.startBeat, 2)
            test.assertEqual(received.event.eventId, "spawn")
            test.assertEqual(received.catchUp, false)
            test.assertEqual(received.beat, 3)
            test.assertEqual(host:getRuntime("gameplay") ~= nil, true)
        end,
    },
}
