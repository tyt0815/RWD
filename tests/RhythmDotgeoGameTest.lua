local function createStageRepository()
    local stages = {
        speaki_song = {
            schemaVersion = 3,
            projectId = "rhythm_dotgeo",
            stageId = "speaki_song",
            name = "Speaki Song",
            bpm = 152,
            mixtape = {
                music = "assets/audio/music/Moai_Doo-Wop.mp3",
                beat0Offset = 0.47,
            },
            events = {},
        },
    }
    return {
        loadCount = 0,
        listStages = function()
            return { "speaki_song" }, nil
        end,
        load = function(self, projectId, stageId)
            self.loadCount = self.loadCount + 1
            return stages[stageId], nil
        end,
    }
end

return {
    {
        name = "Rhythm Dotgeo는 스피키송 Category 노드를 자동 등록한다",
        run = function(test)
            local project = require("projects.rhythm_dotgeo.project")
            local category = project.eventCategories[1]
            test.assertEqual(category.id, "speakiSong")
            test.assertEqual(category.label, "스피키송")
            test.assertEqual(category.events[1].label, "스피키송")
            test.assertEqual(category.events[2].label, "흐에")
            test.assertEqual(category.events[2].properties[1].id, "responseDelayBeats")
            test.assertEqual(category.events[2].properties[2].id, "longNoteLengthBeats")
            test.assertEqual(category.events[2].geometry.startEndpointWidthProperty,
                "longNoteLengthBeats")
            test.assertEqual(category.events[2].geometry.endEndpointWidthProperty,
                "longNoteLengthBeats")
            test.assertEqual(category.events[3].label, "네르지마세요")
            test.assertEqual(#category.events, 3)
        end,
    },
    {
        name = "스피키송 턴 스케줄은 다른 Category의 동명 Event를 무시한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
            })
            local stage = {
                schemaVersion = 3,
                projectId = "rhythm_dotgeo",
                stageId = "category_collision",
                name = "Category Collision",
                bpm = 120,
                events = {
                    { id = "own", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "heue",
                        startBeat = 4, track = 1,
                        params = { responseDelayBeats = 2, longNoteLengthBeats = 1 } },
                    { id = "foreign", type = "projectEvent",
                        categoryId = "other", eventId = "heue",
                        startBeat = 8, track = 1 },
                },
            }

            assert(game:startStage(stage, 0))
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertEqual(#runtime.turnSchedule, 2)
        end,
    },
    {
        name = "스피키송 노드는 액터를 소환하고 턴과 큐 응답 상태를 실행한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
            })
            local stage = {
                projectId = "rhythm_dotgeo",
                stageId = "effects",
                name = "Effects",
                bpm = 120,
                events = {
                    { id = "spawn", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "speakiSong",
                        startBeat = 0, track = 1, params = {} },
                    { id = "long", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "heue",
                        startBeat = 1, track = 1,
                        params = { responseDelayBeats = 2, longNoteLengthBeats = 1 } },
                    { id = "next", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "doNotNer",
                        startBeat = 2, track = 2,
                        params = { responseDelayBeats = 10 } },
                    { id = "tap", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "doNotNer",
                        startBeat = 5, track = 1,
                        params = { responseDelayBeats = 2 } },
                },
            }
            assert(game:startStage(stage, 0))
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertEqual(runtime.guideActor.spawned, true)
            test.assertEqual(runtime.playerActor.spawned, true)
            test.assertEqual(runtime.background.spawned, true)

            game:update(0.1, 0.75)
            test.assertNear(runtime.guideActor.movement:getValue(0.75), 0, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(0.75), 0.5, 0.000001)
            game:update(0.1, 1)
            test.assertNear(runtime.playerActor.movement:getValue(1), 1, 0.000001)
            test.assertEqual(runtime.guideActor.effect, "long")
            test.assertEqual(runtime.sounds.longHeld.guide, true)

            game:update(0.1, 2)
            test.assertEqual(runtime.sounds.longHeld.guide, false)
            game:update(0.1, 2.75)
            test.assertNear(runtime.guideActor.movement:getValue(2.75), 0.5, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(2.75), 0.5, 0.000001)
            game:update(0.1, 3)
            test.assertNear(runtime.guideActor.movement:getValue(3), 1, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(3), 0, 0.000001)
            game:keypressed("space")
            test.assertEqual(runtime.playerActor.effect, nil)
            game:update(0.1, 3)
            test.assertEqual(runtime.playerActor.effect, "long")
            game:update(0.1, 4)
            game:keyreleased("space")
            test.assertEqual(runtime.longResult, "GOOD")

            game:update(0.1, 4.75)
            test.assertNear(runtime.guideActor.movement:getValue(4.75), 0.5, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(4.75), 0.5, 0.000001)
            game:update(0.1, 5)
            test.assertNear(runtime.guideActor.movement:getValue(5), 0, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(5), 1, 0.000001)
            test.assertEqual(runtime.guideActor.effect, "tap")
            game:update(0.1, 6.75)
            test.assertNear(runtime.guideActor.movement:getValue(6.75), 0.5, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(6.75), 0.5, 0.000001)
            game:update(0.1, 7)
            game:keypressed("space")
            test.assertNear(runtime.guideActor.movement:getValue(7), 1, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(7), 0, 0.000001)
            test.assertEqual(runtime.playerActor.effect, nil)
            game:keyreleased("space")
            test.assertEqual(runtime.tapResult, "GOOD")
            test.assertEqual(runtime.playerActor.effect, "tap")
        end,
    },
    {
        name = "스피키송 플레이어는 같은 입력 위치에서 누른 시간으로 Tap·Long을 선택한다",
        run = function(test)
            local Runtime = require("projects.rhythm_dotgeo.game.SpeakiSong.Runtime")
            local state = { playerTapCount = 0, playerLongCount = 0 }
            local image = {
                getWidth = function() return 300 end,
                getHeight = function() return 306 end,
            }
            local sounds = {
                configure = function() end,
                resetTapIndex = function() end,
                playTap = function(_, role)
                    if role == "player" then
                        state.playerTapCount = state.playerTapCount + 1
                    end
                end,
                startLong = function(_, role)
                    if role == "player" then
                        state.playerLongCount = state.playerLongCount + 1
                    end
                end,
                releaseLong = function() end,
                update = function() end,
                stop = function() end,
            }
            local runtime = Runtime.new({}, {}, {
                sprites = { get = function() return image end },
                sounds = sounds,
                gameplayConfig = {
                    load = function()
                        return { longHoldThresholdMs = 100 }
                    end,
                },
                config = {
                    load = function()
                        return {
                            actor = {
                                actorHeightRatio = 0.61,
                                maxActorWidthRatio = 0.31,
                                sideMarginRatio = 0.1,
                                minMargin = 25,
                                outsidePadding = 13,
                                longPressBeats = 0.21,
                                longShiftXRatio = 0.036,
                                longShiftYRatio = 0.046,
                                tapDurationBeats = 0.36,
                                tapShiftXRatio = 0.071,
                                tapShiftYRatio = 0.056,
                                tapShakeRatio = 0.013,
                            },
                        }
                    end,
                },
            })
            runtime:startStage({ bpm = 120, events = {} }, 0)

            runtime.tapJudgment:addNote("tap-short", 10)
            runtime.longJudgment:addNote("long-short", 10, 11)
            runtime:keypressed("space", 10)
            test.assertEqual(state.playerTapCount, 0)
            test.assertEqual(state.playerLongCount, 0)
            runtime:keyreleased("space", 10.1)

            test.assertEqual(state.playerTapCount, 1)
            test.assertEqual(state.playerLongCount, 0)
            test.assertEqual(runtime.playerActor.effect, "tap")
            test.assertEqual(runtime.tapResult, "GOOD")

            runtime:update(0, 11.5)
            runtime.tapJudgment:addNote("tap-long", 12)
            runtime.longJudgment:addNote("long-long", 12, 14)
            runtime:keypressed("space", 12)
            runtime:update(0.1, 12)

            test.assertEqual(state.playerLongCount, 1)
            test.assertEqual(state.playerTapCount, 1)
            test.assertEqual(runtime.playerActor.effect, "long")
            test.assertEqual(runtime.longResult, "GOOD")
            runtime:keyreleased("space", 14)
            test.assertEqual(runtime.playerActor.effect, nil)
            test.assertEqual(runtime.longResult, "GOOD")

            runtime:keypressed("space", 20)
            runtime:update(0.1, 20.25)
            test.assertEqual(state.playerLongCount, 2)
            test.assertEqual(state.playerTapCount, 1)
            test.assertEqual(runtime.playerActor.effect, "long")
            runtime:keyreleased("space", 20.5)
            test.assertEqual(runtime.playerActor.effect, nil)
            test.assertEqual(runtime.longResult, "EMPTY_INPUT")
        end,
    },
    {
        name = "스피키송은 Play마다 Config를 다시 읽고 Turn별 Tap 인덱스를 초기화한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local state = {
                loadCount = 0,
                configureCount = 0,
                resets = { guide = 0, player = 0 },
            }
            local sounds = {
                configure = function()
                    state.configureCount = state.configureCount + 1
                end,
                resetTapIndex = function(_, role)
                    state.resets[role] = state.resets[role] + 1
                end,
                playTap = function() end,
                update = function() end,
            }
            local image = {
                getWidth = function() return 300 end,
                getHeight = function() return 306 end,
            }
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
                categoryOptions = {
                    sprites = { get = function() return image end },
                    sounds = sounds,
                    config = {
                        load = function()
                            state.loadCount = state.loadCount + 1
                            return {
                                longStartSound = "hue-start.mp3",
                                longLoopSound = "hue-loop.mp3",
                                longEndSound = "hue-end.mp3",
                                tapSounds = {},
                                actor = {
                                    actorHeightRatio = 0.61,
                                    maxActorWidthRatio = 0.31,
                                    sideMarginRatio = 0.1,
                                    minMargin = 25,
                                    outsidePadding = 13,
                                    longPressBeats = 0.21,
                                    longShiftXRatio = 0.036,
                                    longShiftYRatio = 0.046,
                                    tapDurationBeats = 0.36,
                                    tapShiftXRatio = 0.071,
                                    tapShiftYRatio = 0.056,
                                    tapShakeRatio = 0.013,
                                },
                            }
                        end,
                    },
                },
            })
            local stage = {
                projectId = "rhythm_dotgeo",
                stageId = "reload",
                name = "Reload",
                bpm = 120,
                events = {
                    { id = "spawn", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "speakiSong",
                        startBeat = 0, track = 1, params = {} },
                    { id = "cue", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "doNotNer",
                        startBeat = 0, track = 2,
                        params = { responseDelayBeats = 1 } },
                },
            }

            assert(game:startStage(stage, 0))
            game:update(0, 0.5)
            assert(game:startStage(stage, 0))
            game:update(0, 0.5)

            test.assertEqual(state.loadCount, 2)
            test.assertEqual(state.configureCount, 2)
            test.assertEqual(state.resets.guide, 4)
            test.assertEqual(state.resets.player, 4)
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertNear(runtime.guideActor.settings.actorHeightRatio,
                0.61, 0.000001)
            test.assertNear(runtime.playerActor.settings.tapShakeRatio,
                0.013, 0.000001)
            test.assertNear(runtime.tapDurationBeats, 0.36, 0.000001)
        end,
    },
    {
        name = "스피키송 플레이어 액터는 좌우 반전되어 렌더링된다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
            })
            assert(game:startStage({
                projectId = "rhythm_dotgeo",
                stageId = "draw",
                name = "Draw",
                bpm = 120,
                events = {
                    { id = "spawn", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "speakiSong",
                        startBeat = 0, track = 1, params = {} },
                },
            }, 0))
            local scales = {}
            local previousLove = love
            love = {
                graphics = {
                    clear = function() end,
                    setColor = function() end,
                    printf = function() end,
                    draw = function(_, _, _, _, scaleX)
                        table.insert(scales, scaleX)
                    end,
                },
            }
            local succeeded, errorMessage = pcall(function() game:draw(640, 360) end)
            love = previousLove

            test.assertTrue(succeeded, errorMessage)
            test.assertTrue(scales[2] > 0)
            test.assertTrue(scales[3] < 0)
        end,
    },
    {
        name = "Rhythm Dotgeo는 열리면 Stage 목록을 표시한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
            })

            test.assertEqual(game:getScreen(), "stageSelect")
            local viewModel = game:getViewModel(1280, 720)
            test.assertEqual(#viewModel.stages, 1)
            test.assertEqual(viewModel.stages[1].id, "speaki_song")
            test.assertEqual(viewModel.stages[1].label, "Speaki Song")

            local printed = {}
            local previousLove = love
            love = {
                graphics = {
                    clear = function() end,
                    setColor = function() end,
                    rectangle = function() end,
                    getFont = function()
                        return { getHeight = function() return 16 end }
                    end,
                    printf = function(text)
                        table.insert(printed, text)
                    end,
                },
            }
            local succeeded, errorMessage = pcall(function()
                game:draw(1280, 720)
            end)
            love = previousLove

            test.assertTrue(succeeded, errorMessage)
            test.assertTrue(table.concat(printed, "\n"):find("Speaki Song", 1, true) ~= nil)
        end,
    },
    {
        name = "Rhythm Dotgeo는 실제 Speaki Song Stage를 열 수 있다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = require("projects.rhythm_dotgeo.project")
            local game, createError = ProjectLoader.createGame(project, {
                stageRepository = require("core").StageRepository.new({
                    fileSystem = require("launcher.NativeFileSystem").new(),
                    paths = {
                        stageDirectory = function(projectId)
                            return "projects/" .. projectId .. "/stages"
                        end,
                        stageFile = function(projectId, stageId)
                            return "projects/" .. projectId .. "/stages/"
                                .. stageId .. ".json"
                        end,
                    },
                    json = require("vendor.dkjson"),
                }),
            })
            test.assertTrue(game ~= nil, createError)
            local speakiSong
            for _, stage in ipairs(game:getViewModel().stages) do
                if stage.id == "speaki_song" then
                    speakiSong = stage
                end
            end
            test.assertTrue(speakiSong ~= nil, "Speaki Song Stage가 목록에 없습니다.")

            assert(game:mousepressed(speakiSong.rect.x + 4, speakiSong.rect.y + 4, 1))
            test.assertEqual(game.stage.stageId, "speaki_song")
            test.assertEqual(game.stage.name, "Speaki Song")
            test.assertEqual(#game.stage.events, 5)
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertEqual(#runtime.turnSchedule, 2)
            test.assertEqual(runtime.turnSchedule[1].role, "guide")
            test.assertNear(runtime.turnSchedule[1].startBeat, 7.5, 0.000001)
            test.assertEqual(runtime.turnSchedule[2].role, "player")
            test.assertNear(runtime.turnSchedule[2].startBeat, 15.5, 0.000001)
        end,
    },
    {
        name = "Rhythm Dotgeo 독립 실행은 Stage 음악과 beat를 재생한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local state = { beat = 0 }
            local transport = {
                configureMixtape = function(_, mixtape, musicPath)
                    state.mixtape = mixtape
                    state.musicPath = musicPath
                    return true, nil
                end,
                play = function()
                    state.played = true
                    return true, nil
                end,
                update = function(_, deltaTime)
                    state.updatedDeltaTime = deltaTime
                    state.beat = 1.25
                    return true, nil
                end,
                getBeat = function() return state.beat end,
                isMusicFinished = function() return false end,
                pause = function()
                    state.paused = true
                    return true, nil
                end,
            }
            local game = Game.new(project, {
                stageRepository = createStageRepository(),
                standalone = true,
                transportFactory = function(stage)
                    state.bpm = stage.bpm
                    return transport, nil
                end,
            })
            local stageItem = game:getViewModel().stages[1]

            assert(game:mousepressed(stageItem.rect.x + 4, stageItem.rect.y + 4, 1))
            test.assertEqual(state.bpm, 152)
            test.assertEqual(state.musicPath,
                "projects/rhythm_dotgeo/assets/audio/music/Moai_Doo-Wop.mp3")
            test.assertNear(state.mixtape.beat0Offset, 0.47, 0.000001)
            test.assertEqual(state.played, true)

            game:update(0.5)
            test.assertEqual(state.updatedDeltaTime, 0.5)
            test.assertNear(game.currentBeat, 1.25, 0.000001)

            game:stop()
            test.assertEqual(state.paused, true)
        end,
    },
    {
        name = "Rhythm Dotgeo는 공통 관리 노드를 beat 순서로 실행한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local stage = {
                projectId = "rhythm_dotgeo",
                stageId = "manager_nodes",
                name = "Manager Nodes",
                bpm = 120,
                events = {
                    { id = "disable", type = "setInputEnabled", enabled = false, startBeat = 1 },
                    { id = "end", type = "end", startBeat = 2 },
                    { id = "after", type = "projectEvent",
                        categoryId = "speakiSong", eventId = "unknown", startBeat = 3 },
                },
            }
            local stageRepository = {
                listStages = function() return { "manager_nodes" }, nil end,
                load = function() return stage, nil end,
            }
            local state = { beat = 0 }
            local transport = {
                configureMixtape = function() return true, nil end,
                play = function() return true, nil end,
                update = function() state.beat = 5 return true, nil end,
                getBeat = function() return state.beat end,
                isMusicFinished = function() return false end,
                pause = function() state.paused = true return true, nil end,
                seekBeat = function(_, beat) state.seekBeat = beat return true, nil end,
            }
            local game = Game.new(project, {
                stageRepository = stageRepository,
                standalone = true,
                transportFactory = function() return transport, nil end,
            })
            local stageItem = game:getViewModel().stages[1]
            assert(game:mousepressed(stageItem.rect.x + 4, stageItem.rect.y + 4, 1))

            game:update(1)

            test.assertEqual(game:isInputEnabled(), false)
            test.assertNear(game.currentBeat, 2, 0.000001)
            test.assertEqual(state.paused, true)
            test.assertNear(state.seekBeat, 2, 0.000001)
            test.assertEqual(game.errorMessage, nil)
        end,
    },
    {
        name = "Rhythm Dotgeo Stage 항목을 클릭하면 해당 Stage를 시작한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local stageRepository = createStageRepository()
            local game = Game.new(project, {
                stageRepository = stageRepository,
            })
            local stageItem = game:getViewModel().stages[1]

            local handled = game:mousepressed(
                stageItem.rect.x + 4,
                stageItem.rect.y + 4,
                1
            )

            test.assertEqual(handled, true)
            test.assertEqual(game:getScreen(), "stage")
            test.assertEqual(game.stage.stageId, "speaki_song")
            test.assertEqual(game.currentBeat, 0)
            test.assertEqual(stageRepository.loadCount, 2)
        end,
    },
}
