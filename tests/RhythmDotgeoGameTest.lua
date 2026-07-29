local function createStageStore()
    local stages = {
        speaki_song = {
            schemaVersion = 2,
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
            test.assertEqual(category.events[3].label, "네르지마세요")
            test.assertEqual(category.events[4].label, "좌피키")
            test.assertEqual(category.events[5].label, "우피키")
        end,
    },
    {
        name = "스피키송 노드는 액터를 소환하고 턴과 큐 응답 상태를 실행한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, { stageStore = createStageStore() })
            local stage = {
                projectId = "rhythm_dotgeo",
                stageId = "effects",
                name = "Effects",
                bpm = 120,
                events = {
                    { id = "spawn", type = "projectEvent", eventId = "speakiSong",
                        startBeat = 0, track = 1, params = {} },
                    { id = "long", type = "projectEvent", eventId = "heue",
                        startBeat = 1, track = 1,
                        params = { responseDelayBeats = 2, longNoteLengthBeats = 1 } },
                    { id = "tap", type = "projectEvent", eventId = "doNotNer",
                        startBeat = 5, track = 1,
                        params = { responseDelayBeats = 2 } },
                    { id = "player", type = "projectEvent", eventId = "playerTurn",
                        startBeat = 9, track = 1, params = {} },
                },
            }
            assert(game:startStage(stage, 0))
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertEqual(runtime.guideActor.spawned, true)
            test.assertEqual(runtime.playerActor.spawned, true)
            test.assertEqual(runtime.background.spawned, true)
            game:update(0.1, 1)
            test.assertEqual(runtime.guideActor.effect, "long")

            game:update(0.1, 3)
            game:keypressed("space")
            test.assertEqual(runtime.playerActor.effect, "long")
            game:update(0.1, 4)
            game:keyreleased("space")
            test.assertEqual(runtime.longResult, "GOOD")

            game:update(0.1, 5)
            test.assertEqual(runtime.guideActor.effect, "tap")
            game:update(0.1, 7)
            game:keypressed("space")
            test.assertEqual(runtime.tapResult, "GOOD")
            test.assertEqual(runtime.playerActor.effect, "tap")

            game:update(0.1, 9.25)
            test.assertNear(runtime.guideActor.movement:getValue(9.25), 0.5, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(9.25), 0, 0.000001)
        end,
    },
    {
        name = "스피키송 우피키는 좌우 반전되어 렌더링된다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local project = require("projects.rhythm_dotgeo.project")
            local game = Game.new(project, { stageStore = createStageStore() })
            assert(game:startStage({
                projectId = "rhythm_dotgeo",
                stageId = "draw",
                name = "Draw",
                bpm = 120,
                events = {
                    { id = "spawn", type = "projectEvent", eventId = "speakiSong",
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
            local game = Game.new(project, { stageStore = createStageStore() })

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
            local game, createError = ProjectLoader.createGame(project)
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
                stageStore = createStageStore(),
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
                    { id = "after", type = "projectEvent", eventId = "unknown", startBeat = 3 },
                },
            }
            local stageStore = {
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
                stageStore = stageStore,
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
            local stageStore = createStageStore()
            local game = Game.new(project, { stageStore = stageStore })
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
            test.assertEqual(stageStore.loadCount, 2)
        end,
    },
}
