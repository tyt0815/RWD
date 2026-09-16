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
        name = "스피키 위치 복귀는 두 액터를 돌려놓고 중간 재생과 다음 턴을 유지한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local game = Game.new(require("projects.rhythm_dotgeo.project"), {
                stageRepository = createStageRepository(),
            })
            local stage = { schemaVersion = 3, projectId = "rhythm_dotgeo",
                stageId = "return", name = "Return", bpm = 120, events = {
                    { id = "spawn", type = "projectEvent", categoryId = "speakiSong",
                        eventId = "speakiSong", startBeat = 0, track = 1, params = {} },
                    { id = "cue", type = "projectEvent", categoryId = "speakiSong",
                        eventId = "doNotNer", startBeat = 1, track = 2,
                        params = { responseDelayBeats = 2 } },
                    { id = "return", type = "projectEvent", categoryId = "speakiSong",
                        eventId = "returnActors", startBeat = 4, track = 1, params = {} },
                    { id = "next", type = "projectEvent", categoryId = "speakiSong",
                        eventId = "doNotNer", startBeat = 6, track = 2,
                        params = { responseDelayBeats = 2 } },
                } }
            for _, target in ipairs({ 4, 4.25, 4.5, 5.75, 6, 8 }) do
                assert(game:startStage(stage, 0))
                for _, beat in ipairs({ 1, 3, 4 }) do game:update(0, beat) end
                game:update(0, target)
                local runtime = game:getCategoryRuntime("speakiSong")
                local guide = runtime.guideActor.movement:getValue(target)
                local player = runtime.playerActor.movement:getValue(target)
                local crepe = runtime.crepeActor:getMotion(target, 0.09)
                if target < 5.5 then
                    test.assertNear(crepe, 0.325, 0.000001)
                    local _, _, walking = runtime.crepeActor:getPlayback(target, target / 2)
                    test.assertEqual(walking, false)
                    test.assertEqual(runtime.guideActor.bounceEnabled, false)
                    test.assertEqual(runtime.playerActor.bounceEnabled, false)
                else
                    local _, _, walking = runtime.crepeActor:getPlayback(target, target / 2)
                    test.assertEqual(walking, true)
                    test.assertEqual(runtime.guideActor.bounceEnabled, true)
                    test.assertEqual(runtime.playerActor.bounceEnabled, true)
                end
                if target <= 4.5 then
                    test.assertNear(guide, math.max(0, 1 - (target - 4) / 0.5), 0.000001)
                    test.assertNear(player, 0, 0.000001)
                elseif target == 6 then
                    test.assertNear(guide, 0, 0.000001)
                    test.assertNear(player, 1, 0.000001)
                end
                assert(game:startStage(stage, target))
                runtime = game:getCategoryRuntime("speakiSong")
                test.assertNear(runtime.crepeActor:getMotion(target, 0.09), crepe, 0.000001)
                test.assertNear(runtime.guideActor.movement:getValue(target), guide, 0.000001)
                test.assertNear(runtime.playerActor.movement:getValue(target), player, 0.000001)
                assert(game:startStage(stage, 0))
                game:update(0, target)
                test.assertNear(runtime.crepeActor:getMotion(target, 0.09), crepe, 0.000001)
                test.assertNear(runtime.guideActor.movement:getValue(target), guide, 0.000001)
                test.assertNear(runtime.playerActor.movement:getValue(target), player, 0.000001)
            end
            stage.events[3].startBeat = 2
            stage.events[4].startBeat = 2.75
            assert(game:startStage(stage, 2.3))
            local runtime = game:getCategoryRuntime("speakiSong")
            test.assertNear(runtime.guideActor.movement:getValue(2.3), 0, 0.000001)
            test.assertNear(runtime.playerActor.movement:getValue(2.3), 0.55, 0.000001)
            stage.events[3].startBeat = 4
            stage.events[4] = nil
            assert(game:startStage(stage, 100.12))
            runtime = game:getCategoryRuntime("speakiSong")
            test.assertEqual(runtime.guideActor.bounceEnabled, false)
            test.assertEqual(runtime.playerActor.bounceEnabled, false)
            local _, _, walking = runtime.crepeActor:getPlayback(100.12, 50.06)
            test.assertEqual(walking, false)
        end,
    },
    {
        name = "스피키 idle은 바닥을 고정하고 매 박자 눌렸다 복원된다",
        run = function(test)
            local Actor = require("projects.rhythm_dotgeo.game.SpeakiSong.SpeakiActor")
            local previousGraphics = love.graphics
            local drawn
            love.graphics = {
                setColor = function() end,
                draw = function(image, x, y, angle, sx, sy, ox, oy)
                    drawn = { x = x, y = y, sx = sx, sy = sy, oy = oy }
                end,
            }
            local succeeded, errorMessage = xpcall(function()
                local image = {
                    getWidth = function() return 300 end,
                    getHeight = function() return 306 end,
                }
                for _, size in ipairs({ { 1280, 720 }, { 480, 270 } }) do
                    for _, side in ipairs({ "left", "right" }) do
                        local actor = Actor.new({
                            side = side, flipHorizontal = side == "right",
                            sprites = { get = function() return image end },
                            settings = {
                                actorHeightRatio = 0.52, maxActorWidthRatio = 0.3,
                                minMargin = 24, sideMarginRatio = 0.09, outsidePadding = 12,
                                tapDurationBeats = 0.5, tapShakeRatio = 0,
                                tapShiftXRatio = 0, tapShiftYRatio = 0,
                                longPressBeats = 0.5, longShiftXRatio = 0, longShiftYRatio = 0,
                            },
                        })
                        actor:spawn()
                        actor:draw(size[1], size[2], 0)
                        local rest = drawn
                        local function sample(beat, ratio)
                            actor:draw(size[1], size[2], beat)
                            test.assertNear(drawn.sy, rest.sy * ratio, 0.000001)
                            test.assertNear(drawn.y + (306 - drawn.oy) * drawn.sy,
                                size[2] * 0.92, 0.000001)
                            test.assertNear(drawn.x, rest.x, 0.000001)
                            test.assertNear(drawn.sx, rest.sx, 0.000001)
                        end
                        sample(0.12, 0.88)
                        sample(0.36, 0.94)
                        sample(0.6, 1)
                        sample(1, 1)
                        sample(25.12, 0.88)
                        sample(25.12, 0.88)
                        sample(0.12, 0.88)
                        actor:tap(0)
                        sample(0.12, 1)
                        actor:update(0.6)
                        sample(1.12, 0.88)
                        actor:startLong(1, 2)
                        sample(1.12, 1)
                        actor:stopLong()
                        sample(1.12, 0.88)
                        actor.bounceEnabled = false
                        sample(2.12, 1)
                        actor.bounceEnabled = true
                        sample(3.12, 0.88)
                    end
                end
            end, debug.traceback)
            love.graphics = previousGraphics
            if not succeeded then error(errorMessage, 0) end
        end,
    },
    {
        name = "크레페는 중앙에서 왼쪽 4박 이후 8박씩 대칭 왕복한다",
        run = function(test)
            local Actor = require("projects.rhythm_dotgeo.game.SpeakiSong.CrepeActor")
            local previousGraphics = love.graphics
            local draws = {}
            love.graphics = {
                newImage = function(path)
                    return { path = path, setFilter = function() end,
                        getWidth = function() return 500 end,
                        getHeight = function() return 500 end }
                end,
                setColor = function() end,
                draw = function(...) table.insert(draws, { ... }) end,
            }
            local succeeded, errorMessage = xpcall(function()
                local actor = Actor.new(nil, function() return false end)
                draws = {}
                actor:draw(1280, 720, 2, 1)
                test.assertNear(draws[1][2], 640, 0.000001)
                test.assertEqual(draws[1][1].path, "projects/rhythm_dotgeo/assets/image/crepe_walk_0.png")
                local idleActor = Actor.new(nil, function() return true end)
                test.assertEqual(#idleActor.idleFrames, 40)
                local incomplete = Actor.new(nil, function(path)
                    return not path:find("crepe_idle_39.png", 1, true)
                end)
                test.assertEqual(#incomplete.idleFrames, 0)
                draws = {}
                idleActor:draw(1280, 720, 1, 40 / 30)
                test.assertEqual(draws[1][1].path,
                    "projects/rhythm_dotgeo/assets/image/crepe_idle_0.png")
                idleActor:setMovementStart(8, 4)
                for frame = 0, 39 do
                    draws = {}
                    idleActor:draw(1280, 720, 1, (frame + 0.5) / 30)
                    test.assertNear(draws[1][2], 640, 0.000001)
                    test.assertEqual(draws[1][1].path,
                        "projects/rhythm_dotgeo/assets/image/crepe_idle_" .. frame .. ".png")
                end
                draws = {}
                idleActor:draw(1280, 720, 8, 4)
                test.assertEqual(draws[1][1].path, "projects/rhythm_dotgeo/assets/image/crepe_walk_0.png")
                test.assertNear(idleActor:getMotion(12, 0.09), 0.3, 0.000001)
                test.assertNear(idleActor:getMotion(20, 0.09), 0.7, 0.000001)
                test.assertNear(idleActor:getMotion(2, 0.09), 0.5, 0.000001)
                idleActor:setMovementStart(nil)
                test.assertNear(idleActor:getMotion(100, 0.09), 0.5, 0.000001)
                idleActor:setMovementStart(0, 0)
                idleActor:stopMovement(2, 1)
                test.assertNear(idleActor:getMotion(3, 0.09), 0.4, 0.000001)
                draws = {}
                idleActor:draw(1280, 720, 3, 1.5)
                test.assertEqual(draws[1][1].path,
                    "projects/rhythm_dotgeo/assets/image/crepe_idle_15.png")
                test.assertNear(draws[1][2], 512, 0.000001)
                test.assertNear(idleActor:getMotion(1, 0.09), 0.45, 0.000001)
                idleActor:resumeMovement(4, 2)
                test.assertNear(idleActor:getMotion(4, 0.09), 0.4, 0.000001)
                test.assertNear(idleActor:getMotion(6, 0.09), 0.3, 0.000001)
                idleActor:stopMovement(6.125, 3.0625)
                local _, _, flip = idleActor:getMotion(7, 0.09)
                test.assertEqual(flip, -1)
                idleActor:resumeMovement(8, 4)
                test.assertNear(idleActor:getMotion(3, 0.09), 0.4, 0.000001)
                test.assertNear(idleActor:getMotion(8, 0.09), 0.30625, 0.000001)
                idleActor:setMovementStart(0, 0)
                test.assertNear(idleActor:getMotion(3, 0.09), 0.35, 0.000001)
                for _, size in ipairs({ { 1280, 720 }, { 480, 270 } }) do
                    for _, sample in ipairs({ { 0.12, 0.88 }, { 0.36, 0.94 }, { 0.6, 1 },
                        { 1.12, 0.88 }, { 0.12, 0.88 } }) do
                        draws = {}
                        actor:draw(size[1], size[2], sample[1], sample[1] / 2)
                        local draw = draws[1]
                        local scale = size[2] * 0.32 / 500
                        test.assertNear(draw[6], scale * sample[2], 0.000001)
                        test.assertNear(draw[3] + 250 * draw[6], size[2] * 0.76, 0.000001)
                    end
                end
                actor:setMovementStart(0, 0)
                actor:stopMovement(2, 1)
                draws = {}
                actor:draw(1280, 720, 2.12, 1.06)
                test.assertNear(draws[1][6], 720 * 0.32 / 500, 0.000001)
                actor:resumeMovement(3, 1.5)
                draws = {}
                actor:draw(1280, 720, 3.12, 1.56)
                test.assertNear(draws[1][6], 720 * 0.32 / 500 * 0.88, 0.000001)
                actor:setMovementStart(0, 0)
                test.assertEqual(#actor.frames, 24)
                for frame = 0, 23 do
                    draws = {}
                    actor:draw(1280, 720, 0, (frame + 0.5) / 30)
                    test.assertEqual(draws[1][1].path,
                        "projects/rhythm_dotgeo/assets/image/crepe_walk_" .. frame .. ".png")
                end
                for _, sample in ipairs({ { 0.799, 23 }, { 0.8, 0 }, { 0.8, 0 },
                    { 0, 0 }, { 1 / 30, 1 } }) do
                    draws = {}
                    actor:draw(1280, 720, 0, sample[1])
                    test.assertEqual(draws[1][1].path,
                        "projects/rhythm_dotgeo/assets/image/crepe_walk_" .. sample[2] .. ".png")
                end
                for _, size in ipairs({ { 1280, 720 }, { 480, 270 }, { 300, 720 } }) do
                    local halfWidth = math.min(size[2] * 0.32, size[1] * 0.3) / 2
                    for _, sample in ipairs({ { 0, 0.5, -1 }, { 2, 0.4, -1 },
                        { 3.999, 0.30005, -1 }, { 4, 0.3, 1 }, { 4.5, 0.325, 1 },
                        { 8, 0.5, 1 }, { 12, 0.7, -1 }, { 20, 0.3, 1 },
                        { 10000, 0.5, -1 }, { 4, 0.3, 1 }, { 0, 0.5, -1 } }) do
                        local position, direction = actor:getMotion(sample[1], halfWidth / size[1])
                        test.assertNear(position, sample[2], 0.000001)
                        test.assertEqual(direction, sample[3])
                        draws = {}
                        actor:draw(size[1], size[2], sample[1], sample[1] / 2)
                        test.assertEqual(#draws, 1)
                        test.assertNear(draws[1][2], sample[2] * size[1], 0.000001)
                        test.assertNear(draws[1][3] + 250 * draws[1][6], size[2] * 0.6 + halfWidth, 0.000001)
                        test.assertEqual(draws[1][1].path,
                            "projects/rhythm_dotgeo/assets/image/crepe_walk_" .. (math.floor(sample[1] / 2 * 30) % 24) .. ".png")
                    end
                    local left = actor:getMotion(4, halfWidth / size[1]) * size[1] - halfWidth
                    local right = size[1] - actor:getMotion(12, halfWidth / size[1]) * size[1] - halfWidth
                    test.assertNear(left, right, 0.000001)
                    test.assertTrue(left > 0)
                end
                for _, sample in ipairs({ { 4, 1 }, { 4.0625, 0.5 }, { 4.125, 0 },
                    { 4.25, -1 }, { 12, -1 }, { 12.125, 0 }, { 12.25, 1 } }) do
                    local _, _, flip = actor:getMotion(sample[1], 0.09)
                    test.assertNear(flip, sample[2], 0.000001)
                end
            end, debug.traceback)
            love.graphics = previousGraphics
            if not succeeded then error(errorMessage, 0) end
        end,
    },
    {
        name = "크레페는 첫 자동 Turn부터 걷고 새 Stage에서 중앙 대기로 초기화된다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local game = Game.new(require("projects.rhythm_dotgeo.project"), {
                stageRepository = createStageRepository(),
            })
            local stage = { projectId = "rhythm_dotgeo", stageId = "walk",
                name = "Walk", bpm = 120, events = {
                    { id = "cue", type = "projectEvent", categoryId = "speakiSong",
                        eventId = "doNotNer", startBeat = 8, track = 1,
                        params = { responseDelayBeats = 4 } },
                } }
            for _, startBeat in ipairs({ 0, 9, 20, 0 }) do
                assert(game:startStage(stage, startBeat))
                local actor = game:getCategoryRuntime("speakiSong").crepeActor
                test.assertEqual(actor.movementStartBeat, 7.5)
                test.assertEqual(actor.movementStartSeconds, 3.75)
                test.assertNear(actor:getMotion(7, 0.09), 0.5, 0.000001)
                test.assertNear(actor:getMotion(11.5, 0.09), 0.3, 0.000001)
                test.assertNear(actor:getMotion(19.5, 0.09), 0.7, 0.000001)
            end
            stage.events = {}
            assert(game:startStage(stage, 0))
            local actor = game:getCategoryRuntime("speakiSong").crepeActor
            test.assertEqual(actor.movementStartBeat, nil)
            test.assertNear(actor:getMotion(100, 0.09), 0.5, 0.000001)
        end,
    },
    {
        name = "크레페 애니메이션 시간은 Stage BPM에서 초로 변환한다",
        run = function(test)
            local Game = require("projects.rhythm_dotgeo.game.Game")
            local game = Game.new(require("projects.rhythm_dotgeo.project"), {
                stageRepository = createStageRepository(),
            })
            for _, bpm in ipairs({ 120, 152, 240 }) do
                assert(game:startStage({ projectId = "rhythm_dotgeo", stageId = "frames",
                    name = "Frames", bpm = bpm, events = {} }, bpm / 60 * 0.8))
                local runtime = game:getCategoryRuntime("speakiSong")
                runtime.background.spawned = true
                runtime.background.draw = function() end
                runtime.guideActor.draw = function() end
                runtime.playerActor.draw = function() end
                local captured
                runtime.crepeActor.draw = function(_, _, _, _, seconds) captured = seconds end
                runtime:draw(1280, 720)
                test.assertNear(captured, 0.8, 0.000001)
            end
        end,
    },
    {
        name = "스피키송 배경 이미지는 화면을 채우도록 표시한다",
        run = function(test)
            local Background = require("projects.rhythm_dotgeo.game.SpeakiSong.Background")
            local Sprites = require("projects.rhythm_dotgeo.game.SpeakiSong.Sprites")
            local loadedPaths = {}
            local sprites = Sprites.new({
                newImage = function(path)
                    table.insert(loadedPaths, path)
                    return {
                        setFilter = function() end,
                        getWidth = function() return 640 end,
                        getHeight = function() return 480 end,
                    }
                end,
            })
            test.assertEqual(#loadedPaths, 4)
            test.assertTrue(table.concat(loadedPaths, "\n"):find("ghost_basic.png", 1, true) ~= nil)

            local previousGraphics = love.graphics
            local color, drawn
            love.graphics = {
                setColor = function(...)
                    color = { ... }
                end,
                draw = function(...)
                    drawn = { ... }
                end,
            }
            local succeeded, errorMessage = xpcall(function()
                local background = Background.new(sprites)
                background:spawn()
                background:draw(1280, 720)
                test.assertEqual(table.concat(color, ","), "1,1,1,1")
                test.assertEqual(drawn[1], sprites:get("background"))
                test.assertEqual(drawn[2], 640)
                test.assertEqual(drawn[3], 360)
                test.assertEqual(drawn[5], 2)
                test.assertEqual(drawn[6], 2)
            end, debug.traceback)
            love.graphics = previousGraphics
            if not succeeded then error(errorMessage, 0) end
        end,
    },
    {
        name = "스피키송 턴 대기 액터는 화면 가장자리에 조금만 걸친다",
        run = function(test)
            local Actor = require("projects.rhythm_dotgeo.game.SpeakiSong.SpeakiActor")
            local previousGraphics = love.graphics
            local centerX, scaleX
            love.graphics = {
                setColor = function() end,
                draw = function(_, x, _, _, scale) centerX, scaleX = x, scale end,
            }
            local succeeded, errorMessage = xpcall(function()
                local image = {
                    getWidth = function() return 300 end,
                    getHeight = function() return 306 end,
                }
                for _, size in ipairs({ { 1280, 720 }, { 480, 270 } }) do
                    for _, side in ipairs({ "left", "right" }) do
                        local actor = Actor.new({
                            side = side,
                            flipHorizontal = side == "right",
                            sprites = { get = function() return image end },
                            settings = {
                                actorHeightRatio = 0.52, maxActorWidthRatio = 0.3,
                                minMargin = 24, sideMarginRatio = 0.09, outsidePadding = 12,
                            },
                        })
                        actor:spawn()
                        actor:moveOutside(true, 0, 0.5)
                        actor:draw(size[1], size[2], 0.5)
                        local halfWidth = 300 * math.abs(scaleX) / 2
                        if side == "left" then
                            test.assertNear(centerX - halfWidth, -12, 0.000001)
                        else
                            test.assertNear(centerX + halfWidth, size[1] + 12, 0.000001)
                        end
                        actor:moveOutside(false, 1, 0.5)
                        actor:draw(size[1], size[2], 1.5)
                        test.assertTrue(centerX - halfWidth >= 0)
                        test.assertTrue(centerX + halfWidth <= size[1])
                    end
                end
            end, debug.traceback)
            love.graphics = previousGraphics
            if not succeeded then error(errorMessage, 0) end
        end,
    },
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
            test.assertEqual(#category.events, 4)
            test.assertEqual(category.events[4].id, "returnActors")
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
                    rectangle = function() end,
                    printf = function() end,
                    draw = function(_, _, _, _, scaleX)
                        table.insert(scales, scaleX)
                    end,
                },
            }
            local succeeded, errorMessage = pcall(function() game:draw(640, 360) end)
            love = previousLove

            test.assertTrue(succeeded, errorMessage)
            test.assertTrue(#scales > 3)
            for index = 1, #scales - 1 do
                test.assertTrue(scales[index] > 0)
            end
            test.assertTrue(scales[#scales] < 0)
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
