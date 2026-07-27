return {
    {
        name = "Sample Project Event가 Editor Category와 기본 Property로 등록된다",
        run = function(test)
            local project = require("projects.sample.project")
            local Catalog = require("editor.properties.PropertyCatalog")
            local categories = Catalog.getCategories(project)
            test.assertEqual(categories[3].id, "sampleGameplay")
            local events = Catalog.getEvents("sampleGameplay", project)
            test.assertEqual(events[1].timelineType, "project:spawnActors")
            test.assertEqual(events[2].timelineType, "project:guideTurn")
            test.assertEqual(events[3].timelineType, "project:playerTurn")
            test.assertEqual(events[4].properties[1].default, 4)
            test.assertEqual(events[4].geometry.endpointWidthBeats, 1)
            test.assertEqual(events[4].color[1], 0.92)
            test.assertEqual(events[4].color[2], 0.94)
            test.assertEqual(events[4].color[3], 0.97)
            test.assertEqual(events[4].color[4], 1)
        end,
    },
    {
        name = "StageDocument는 Project Event params를 저장하고 편집한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.create("sample", "gameplay", "Gameplay", 120))
            local event = assert(document:addEvent(
                "projectEvent",
                4,
                2,
                "cueResponse",
                { responseDelayBeats = 4 }
            ))
            test.assertEqual(event.eventId, "cueResponse")
            assert(document:setEventProperty(event.id, "responseDelayBeats", 2))
            test.assertEqual(document:getEvents()[1].params.responseDelayBeats, 2)
            test.assertEqual(StageDocument.validate(document:toTable()), nil)
        end,
    },
    {
        name = "연결형 노드는 가운데 겹침을 허용하고 양 끝 겹침은 거부한다",
        run = function(test)
            local Geometry = require("editor.timeline.TimelineEventGeometry")
            local cue = {
                id = "cue", startBeat = 4, track = 1, widthBeats = 5,
                collisionSegments = {
                    { offsetBeats = 0, widthBeats = 1 },
                    { offsetBeats = 4, widthBeats = 1 },
                },
            }
            local middle = { id = "middle", startBeat = 6, track = 1, widthBeats = 1 }
            local endpoint = { id = "endpoint", startBeat = 8, track = 1, widthBeats = 1 }
            test.assertEqual(next(Geometry.findCollisionIds({ cue, middle })), nil)
            local collisions = Geometry.findCollisionIds({ cue, endpoint })
            test.assertEqual(collisions.cue, true)
            test.assertEqual(collisions.endpoint, true)
        end,
    },
    {
        name = "TestPlayer는 Stage, beat와 Space 입력을 Project 게임에 전달한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local received = {}
            local graphics = {
                newCanvas = function() return {} end,
                push = function() end,
                pop = function() end,
                setCanvas = function() end,
                clear = function() end,
                draw = function() end,
            }
            local player = TestPlayer.new({
                graphics = graphics,
                createGame = function()
                    return {
                        startStage = function(_, stage, beat)
                            received.stage = stage
                            received.startBeat = beat
                        end,
                        update = function(_, _, beat) received.updateBeat = beat end,
                        keypressed = function(_, key, beat)
                            received.key = key
                            received.inputBeat = beat
                        end,
                    }
                end,
            })
            local stage = { stageId = "gameplay" }
            assert(player:start({ id = "sample" }, stage, 3))
            assert(player:update(0.1, 3.5))
            assert(player:keypressed("space", 3.6))
            test.assertEqual(received.stage, stage)
            test.assertEqual(received.startBeat, 3)
            test.assertEqual(received.updateBeat, 3.5)
            test.assertEqual(received.key, "space")
            test.assertEqual(received.inputBeat, 3.6)
        end,
    },
    {
        name = "Sample Turn 노드는 0.5박 동안 상대 액터를 화면 밖으로 보간한다",
        run = function(test)
            local game = require("projects.sample.game.SampleGame").new(
                require("projects.sample.project")
            )
            local runtime = game:getCategoryRuntime("sampleGameplay")
            runtime.sounds = { play = function() end }
            game:startStage({
                events = {
                    {
                        id = "spawn", type = "projectEvent", eventId = "spawnActors",
                        startBeat = 0, track = 1, params = {},
                    },
                    {
                        id = "guide", type = "projectEvent", eventId = "guideTurn",
                        startBeat = 2, track = 1, params = {},
                    },
                    {
                        id = "player", type = "projectEvent", eventId = "playerTurn",
                        startBeat = 4, track = 1, params = {},
                    },
                },
            }, 0)

            game:update(0.1, 2.25)
            test.assertNear(runtime.guideActor.movement:getValue(2.25), 0, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(2.25), 0.5, 0.000001)
            game:update(0.1, 4.25)
            test.assertNear(runtime.guideActor.movement:getValue(4.25), 0.5, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(4.25), 0.5, 0.000001)
        end,
    },
    {
        name = "Sample Auto Play는 Good, Bad, Miss 판정을 자동 실행한다",
        run = function(test)
            local SampleGame = require("projects.sample.game.SampleGame")
            local project = require("projects.sample.project")
            local stage = {
                events = {
                    {
                        id = "response", type = "projectEvent", eventId = "cueResponse",
                        startBeat = 0, track = 1,
                        params = { responseDelayBeats = 4 },
                    },
                },
            }
            local cases = {
                { mode = "good", beat = 4, result = "GOOD" },
                { mode = "bad", beat = 4.2, result = "BAD" },
                { mode = "miss", beat = 4.3, result = "MISS" },
            }
            for _, case in ipairs(cases) do
                local game = SampleGame.new(project)
                local runtime = game:getCategoryRuntime("sampleGameplay")
                runtime.sounds = { play = function() end }
                game:setAutoPlay(case.mode)
                game:startStage(stage, 0)
                game:update(0.1, case.beat)
                test.assertEqual(runtime.playerResult, case.result)
            end
        end,
    },
    {
        name = "Sample 오른쪽 액터 Sprite는 좌우 반전해 렌더링한다",
        run = function(test)
            local game = require("projects.sample.game.SampleGame").new(
                require("projects.sample.project")
            )
            game.stage = { events = {} }
            local runtime = game:getCategoryRuntime("sampleGameplay")
            runtime.guideActor:spawn()
            runtime.playerActor:spawn()
            local image = {
                getWidth = function() return 300 end,
                getHeight = function() return 300 end,
            }
            local sprites = { get = function() return image end }
            runtime.guideActor.sprites = sprites
            runtime.playerActor.sprites = sprites
            local scales = {}
            local previousLove = love
            love = {
                graphics = {
                    clear = function() end,
                    setColor = function() end,
                    draw = function(_, _, _, _, scaleX)
                        table.insert(scales, scaleX)
                    end,
                },
            }
            local succeeded, errorMessage = pcall(function() game:draw(640, 360) end)
            love = previousLove

            test.assertTrue(succeeded, errorMessage)
            test.assertTrue(scales[1] > 0)
            test.assertTrue(scales[2] < 0)
        end,
    },
    {
        name = "Sample Stage는 검은 화면에서 액터를 스폰하고 Space를 판정한다",
        run = function(test)
            local game = require("projects.sample.game.SampleGame").new(
                require("projects.sample.project")
            )
            local sounds = {}
            local runtime = game:getCategoryRuntime("sampleGameplay")
            runtime.sounds = { play = function(_, id) table.insert(sounds, id) end }
            game:startStage({
                events = {
                    {
                        id = "spawn", type = "projectEvent", eventId = "spawnActors",
                        startBeat = 0, track = 1, params = {},
                    },
                    {
                        id = "response", type = "projectEvent", eventId = "cueResponse",
                        startBeat = 0, track = 1,
                        params = { responseDelayBeats = 4 },
                    },
                },
            }, 0)
            test.assertEqual(runtime.guideActor.spawned, true)
            test.assertEqual(runtime.playerActor.spawned, true)
            test.assertEqual(sounds[1], "cue")
            game:keypressed("space", 4.08)
            test.assertEqual(runtime.playerResult, "GOOD")
            test.assertEqual(sounds[2], "GOOD")
            local guideState, playerState = runtime:getActorSpriteStates()
            test.assertEqual(guideState, "success")
            test.assertEqual(playerState, "success")
            game:keypressed("space", 6)
            test.assertEqual(runtime.playerResult, "EMPTY_INPUT")
            test.assertEqual(select(2, runtime:getActorSpriteStates()), "success")
            runtime:showResult({ result = "BAD" })
            test.assertEqual(select(2, runtime:getActorSpriteStates()), "failure")
            runtime:showResult({ result = "MISS" })
            test.assertEqual(select(2, runtime:getActorSpriteStates()), "failure")
        end,
    },
}
