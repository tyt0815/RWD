local VALID_STAGE = {
    schemaVersion = 3,
    projectId = "sample",
    stageId = "tutorial",
    name = "Tutorial",
    bpm = 120,
    events = {},
}

local OTHER_STAGE = {
    schemaVersion = 3,
    projectId = "other",
    stageId = "replacement",
    name = "Replacement",
    bpm = 100,
    events = {},
}

local function newFixture(options)
    options = options or {}
    local customTransportFactory = options.transportFactory
    local stored = options.stored
    local project = options.project
        or { id = "sample", title = "Sample", entryModule = "sample.game" }
    local otherProject = { id = "other", title = "Other", entryModule = "other.game" }
    local catalog = {
        listProjects = function()
            return { project, otherProject }, nil
        end,
        getProject = function(_, projectId)
            if projectId == "sample" then return project, nil end
            if projectId == "other" then return otherProject, nil end
            return nil, "missing project"
        end,
        createGame = function()
            return {}, nil
        end,
    }
    local store = {
        listStages = function()
            return { "tutorial" }, nil
        end,
        stageExists = function(_, _, stageId)
            return stageId == "existing", nil
        end,
        load = function()
            if options.loadError then return nil, options.loadError end
            return stored, nil
        end,
        save = function(_, data, overwrite)
            if options.saveError then return nil, options.saveError end
            if options.conflict and not overwrite then
                return nil, "already exists", "STAGE_EXISTS"
            end
            if options.onSave then options.onSave(data, overwrite) end
            options.lastSaved = data
            return true, nil
        end,
    }
    local testPlayerState = { stopCount = 0 }
    options.testPlayerState = testPlayerState
    local testPlayer = {
        playing = false,
        start = function(self, projectValue, stage, startBeat, autoPlay)
            if options.previewError then return nil, options.previewError end
            testPlayerState.project = projectValue
            testPlayerState.stage = stage
            testPlayerState.startBeat = startBeat
            testPlayerState.autoPlay = autoPlay
            options.startCount = (options.startCount or 0) + 1
            testPlayerState.startCount = (testPlayerState.startCount or 0) + 1
            self.game = { instance = options.startCount }
            self.playing = true
            return true, nil
        end,
        stop = function(self)
            testPlayerState.stopCount = testPlayerState.stopCount + 1
            self.game = nil
            self.playing = false
        end,
        update = function(_, deltaTime)
            testPlayerState.lastDeltaTime = deltaTime
            if options.updateError then return nil, options.updateError end
            return true, nil
        end,
        draw = function(_, rect)
            testPlayerState.drawRect = rect
            if options.drawError then return nil, options.drawError end
            return true, nil
        end,
    }
    local transportState = {
        beat = 0,
        bpm = nil,
        pauseCount = 0,
        playing = false,
    }
    options.transportState = transportState
    options.transportFactory = customTransportFactory or function(bpm)
        transportState.bpm = bpm
        transportState.creationCount = (transportState.creationCount or 0) + 1
        local transport = {
            configureMixtape = function(_, mixtape, resolvedMusicPath)
                transportState.configureCount = (transportState.configureCount or 0) + 1
                transportState.mixtape = mixtape
                transportState.resolvedMusicPath = resolvedMusicPath
                if transportState.configureError then
                    return nil, transportState.configureError
                end
                return true, nil
            end,
            play = function(_, playbackRate)
                transportState.playCount = (transportState.playCount or 0) + 1
                transportState.playbackRate = playbackRate or 1
                if transportState.playError then return nil, transportState.playError end
                transportState.playing = true
                return true, nil
            end,
            pause = function()
                transportState.pauseCount = transportState.pauseCount + 1
                transportState.playing = false
                return true, nil
            end,
            update = function(_, deltaTime)
                transportState.lastDeltaTime = deltaTime
                if transportState.updateError then return nil, transportState.updateError end
                if transportState.playing then
                    transportState.beat = transportState.beat
                        + deltaTime * transportState.playbackRate * transportState.bpm / 60
                end
                return true, nil
            end,
            getBeat = function()
                return transportState.beat
            end,
            isPlaying = function()
                return transportState.playing
            end,
            isMusicFinished = function()
                return transportState.musicFinished == true
            end,
            setBpm = function(_, bpmValue)
                transportState.candidateBpm = bpmValue
                if transportState.setBpmError then
                    return nil, transportState.setBpmError
                end
                transportState.bpm = bpmValue
                return true, nil
            end,
            seekBeat = function(_, beat)
                transportState.seekCount = (transportState.seekCount or 0) + 1
                transportState.seekBeat = beat
                if transportState.playing then
                    return nil, "Cannot seek while playback is running."
                end
                if transportState.seekError then
                    return nil, transportState.seekError
                end
                transportState.beat = beat
                return true, nil
            end,
        }
        transportState.transport = transport
        return transport, nil
    end
    local metronomeState = { pauseCount = 0, playing = false }
    options.metronomeState = metronomeState
    options.metronome = options.metronome or {
        play = function(_, bpm, period, beat, playbackRate)
            metronomeState.playCount = (metronomeState.playCount or 0) + 1
            metronomeState.bpm = bpm
            metronomeState.period = period
            metronomeState.beat = beat
            metronomeState.playbackRate = playbackRate
            if metronomeState.playError then return nil, metronomeState.playError end
            metronomeState.playing = true
            return true, nil
        end,
        update = function(_, beat)
            metronomeState.updateCount = (metronomeState.updateCount or 0) + 1
            metronomeState.updateBeat = beat
            if metronomeState.updateError then return nil, metronomeState.updateError end
            return true, nil
        end,
        pause = function()
            metronomeState.pauseCount = metronomeState.pauseCount + 1
            metronomeState.playing = false
            return true, nil
        end,
    }
    return catalog, store, testPlayer, options
end

local function newSession(options)
    local EditorSession = require("editor.EditorSession")
    local catalog, store, testPlayer, state = newFixture(options)
    return EditorSession.new({
        projectCatalog = catalog,
        stageStore = store,
        testPlayer = testPlayer,
        transportFactory = state.transportFactory,
        metronome = state.metronome,
    }), testPlayer, state
end

return {
    {
        name = "EditorSession은 동명 Project Event를 Category ID로 구분한다",
        run = function(test)
            local project = {
                id = "sample",
                title = "Sample",
                entryModule = "sample.game",
                eventCategories = {
                    {
                        id = "first",
                        label = "First",
                        events = {
                            {
                                id = "spawn",
                                label = "First Spawn",
                                singleton = true,
                                properties = {
                                    {
                                        id = "firstValue",
                                        kind = "number",
                                        default = 1,
                                    },
                                },
                            },
                        },
                    },
                    {
                        id = "second",
                        label = "Second",
                        events = {
                            {
                                id = "spawn",
                                label = "Second Spawn",
                                singleton = true,
                                properties = {
                                    {
                                        id = "secondValue",
                                        kind = "number",
                                        default = 2,
                                    },
                                },
                            },
                        },
                    },
                },
            }
            local stage = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "category-events",
                name = "Category Events",
                bpm = 120,
                events = {
                    {
                        id = "event-001",
                        type = "projectEvent",
                        categoryId = "second",
                        eventId = "spawn",
                        startBeat = 0,
                        track = 1,
                        params = { secondValue = 2 },
                    },
                },
            }
            local session = newSession({ project = project, stored = stage })
            assert(session:openStage("sample", "category-events"))
            test.assertEqual(
                session:getTimelineEvents()[1].projectDefinition.label,
                "Second Spawn"
            )

            local added = assert(session:addTimelineEvent(
                "project:first:spawn",
                2,
                1,
                { firstValue = 1 }
            ))
            test.assertEqual(added.categoryId, "first")
            test.assertEqual(added.eventId, "spawn")

            local duplicate, errorMessage, errorCode = session:addTimelineEvent(
                "project:first:spawn",
                4,
                1,
                { firstValue = 1 }
            )
            test.assertEqual(duplicate, nil)
            test.assertContains(errorMessage, "only one Event")
            test.assertEqual(errorCode, "PROJECT_EVENT_EXISTS")
        end,
    },
    {
        name = "에디터 세션은 Stage 없이 시작한다",
        run = function(test)
            local session = newSession()
            test.assertEqual(session:hasStage(), false)
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(session:isPlaying(), false)
            test.assertEqual(session:listProjects()[1].id, "sample")
            test.assertEqual(session:listStages("sample")[1], "tutorial")
        end,
    },
    {
        name = "새 Stage 생성은 현재 Project와 dirty Stage를 설정한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "new-stage", "New Stage", 128))
            test.assertEqual(session:getProject().id, "sample")
            test.assertEqual(session:getDocument():getStageId(), "new-stage")
            test.assertEqual(session:getBpm(), 128)
            test.assertEqual(#session:getDocument():toTable().events, 0)
            test.assertEqual(session:isDirty(), true)
        end,
    },
    {
        name = "기존 Stage Open은 clean 상태와 0 beat로 교체한다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            test.assertEqual(session:getDocument():getStageId(), "tutorial")
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(session:getBeat(), 0)
        end,
    },
    {
        name = "Open 실패는 현재 Stage와 dirty 상태를 보존한다",
        run = function(test)
            local session, testPlayer = newSession({ loadError = "broken Stage" })
            assert(session:createStage("sample", "current", "Current", 120))
            assert(session:play())
            assert(session:update(7, 12))
            local currentProject = session:getProject()
            local currentDocument = session:getDocument()
            local currentGame = testPlayer.game

            local opened, errorMessage = session:openStage("other", "broken")
            test.assertEqual(opened, nil)
            test.assertContains(errorMessage, "broken Stage")
            test.assertEqual(session:getProject(), currentProject)
            test.assertEqual(session:getProject().id, "sample")
            test.assertEqual(session:getDocument(), currentDocument)
            test.assertEqual(session:getDocument():getStageId(), "current")
            test.assertEqual(session:isDirty(), true)
            test.assertNear(session:getBeat(), 14, 0.000001)
            test.assertEqual(session:getTimelineStartBeat(), 6)
            test.assertEqual(session:isPlaying(), true)
            test.assertEqual(testPlayer.playing, true)
            test.assertEqual(testPlayer.game, currentGame)

            local transportCreationCount = 0
            local currentTransportState = { beat = 0, playing = false }
            local function failingReplacementTransportFactory(bpm)
                transportCreationCount = transportCreationCount + 1
                if transportCreationCount == 2 then
                    return nil, "replacement transport failed"
                end
                currentTransportState.bpm = bpm
                return {
                    configureMixtape = function() return true, nil end,
                    play = function()
                        currentTransportState.playing = true
                        return true, nil
                    end,
                    pause = function()
                        currentTransportState.playing = false
                        return true, nil
                    end,
                    update = function(_, deltaTime)
                        if currentTransportState.playing then
                            currentTransportState.beat = currentTransportState.beat
                                + deltaTime * currentTransportState.bpm / 60
                        end
                        return true, nil
                    end,
                    getBeat = function() return currentTransportState.beat end,
                    isPlaying = function() return currentTransportState.playing end,
                    setBpm = function(_, value)
                        currentTransportState.bpm = value
                        return true, nil
                    end,
                }, nil
            end
            local clockSession, clockTestPlayer = newSession({
                stored = OTHER_STAGE,
                transportFactory = failingReplacementTransportFactory,
            })
            assert(clockSession:createStage("sample", "current", "Current", 120))
            assert(clockSession:play())
            assert(clockSession:update(7, 12))
            local clockProject = clockSession:getProject()
            local clockDocument = clockSession:getDocument()
            local clockGame = clockTestPlayer.game

            local replaced, replacementError = clockSession:openStage(
                "other",
                "replacement"
            )
            test.assertEqual(replaced, nil)
            test.assertContains(replacementError, "replacement transport failed")
            test.assertEqual(transportCreationCount, 2)
            test.assertEqual(clockSession:getProject(), clockProject)
            test.assertEqual(clockSession:getDocument(), clockDocument)
            test.assertEqual(clockSession:isDirty(), true)
            test.assertNear(clockSession:getBeat(), 14, 0.000001)
            test.assertEqual(clockSession:getTimelineStartBeat(), 6)
            test.assertEqual(clockSession:isPlaying(), true)
            test.assertEqual(clockTestPlayer.playing, true)
            test.assertEqual(clockTestPlayer.game, clockGame)
        end,
    },
    {
        name = "Save 성공은 dirty를 해제하고 실패는 유지한다",
        run = function(test)
            local session, _, state = newSession()
            assert(session:createStage("sample", "saved", "Saved", 120))
            assert(session:save())
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(state.lastSaved.stageId, "saved")

            local failingSession = newSession({ saveError = "disk failed" })
            assert(failingSession:createStage("sample", "failed", "Failed", 120))
            local saved, errorMessage = failingSession:save()
            test.assertEqual(saved, nil)
            test.assertContains(errorMessage, "disk failed")
            test.assertEqual(failingSession:isDirty(), true)
        end,
    },
    {
        name = "Save As는 성공 후에만 ID와 이름을 교체한다",
        run = function(test)
            local session = newSession({ conflict = true })
            assert(session:createStage("sample", "source", "Source", 120))
            local currentProject = session:getProject()
            local saved, _, errorCode = session:saveAs("copy", "Copy", false)
            test.assertEqual(saved, nil)
            test.assertEqual(errorCode, "STAGE_EXISTS")
            test.assertEqual(session:getDocument():getStageId(), "source")
            test.assertEqual(session:getDocument():getName(), "Source")
            test.assertEqual(session:isDirty(), true)
            test.assertEqual(session:getProject(), currentProject)

            local successOptions = {}
            local successSession
            successOptions.onSave = function(data)
                test.assertEqual(data.stageId, "copy")
                test.assertEqual(data.name, "Copy")
                test.assertEqual(successSession:getDocument():getStageId(), "source")
                test.assertEqual(successSession:getDocument():getName(), "Source")
            end
            successSession = newSession(successOptions)
            assert(successSession:createStage("sample", "source", "Source", 120))
            local successProject = successSession:getProject()
            assert(successSession:saveAs("copy", "Copy", false))
            test.assertEqual(successSession:getDocument():getStageId(), "copy")
            test.assertEqual(successSession:getDocument():getName(), "Copy")
            test.assertEqual(successSession:isDirty(), false)
            test.assertEqual(successSession:getProject(), successProject)
        end,
    },
    {
        name = "BPM 변경은 Document와 Transport를 함께 변경한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "tempo", "Tempo", 120))
            assert(session:setBpm(90))
            test.assertEqual(session:getBpm(), 90)
            session:play()
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 1.5, 0.000001)

            local sameSession = newSession({ stored = VALID_STAGE })
            assert(sameSession:openStage("sample", "tutorial"))
            assert(sameSession:setBpm(120))
            test.assertEqual(sameSession:getBpm(), 120)
            test.assertEqual(sameSession:isDirty(), false)

            local failingSession, _, failingState = newSession({ stored = VALID_STAGE })
            assert(failingSession:openStage("sample", "tutorial"))
            failingState.transportState.setBpmError = "transport BPM failed"
            local changed, errorMessage = failingSession:setBpm(90)
            test.assertEqual(changed, nil)
            test.assertContains(errorMessage, "transport BPM failed")
            test.assertEqual(failingState.transportState.candidateBpm, 90)
            test.assertEqual(failingState.transportState.bpm, 120)
            test.assertEqual(failingSession:getBpm(), 120)
            test.assertEqual(failingSession:isDirty(), false)
        end,
    },
    {
        name = "Pause 뒤 Play는 일시정지 위치가 아닌 기준 beat에서 다시 시작한다",
        run = function(test)
            local session, testPlayer, state = newSession()
            assert(session:createStage("sample", "preview", "Preview", 120))
            assert(session:seekTimeline(4))
            assert(session:play())
            local firstGame = testPlayer.game
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 6, 0.000001)
            test.assertEqual(session:getAnchorBeat(), 4)
            test.assertEqual(testPlayer.playing, true)
            session:pause()
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 6, 0.000001)
            test.assertEqual(testPlayer.playing, false)

            assert(session:play())
            test.assertEqual(state.startCount, 2)
            test.assertTrue(testPlayer.game ~= firstGame)
            test.assertNear(session:getBeat(), 4, 0.000001)
        end,
    },
    {
        name = "Project preview는 Editor 설정 종횡비로 영역 중앙에 맞춘다",
        run = function(test)
            local session, _, state = newSession()
            assert(session:createStage("sample", "aspect", "Aspect", 120))
            assert(session:setProperty("editorProperties", "previewAspectWidth", 4))
            assert(session:setProperty("editorProperties", "previewAspectHeight", 3))
            assert(session:play())

            assert(session:drawPreview({ x = 100, y = 20, width = 500, height = 200 }))
            test.assertEqual(state.testPlayerState.drawRect.x, 217)
            test.assertEqual(state.testPlayerState.drawRect.y, 20)
            test.assertEqual(state.testPlayerState.drawRect.width, 266)
            test.assertEqual(state.testPlayerState.drawRect.height, 200)

            assert(session:drawPreview({ x = 100, y = 20, width = 200, height = 500 }))
            test.assertEqual(state.testPlayerState.drawRect.x, 100)
            test.assertEqual(state.testPlayerState.drawRect.y, 195)
            test.assertEqual(state.testPlayerState.drawRect.width, 200)
            test.assertEqual(state.testPlayerState.drawRect.height, 150)
        end,
    },
    {
        name = "Project preview 실패는 재생을 중지한다",
        run = function(test)
            local startSession = newSession({ previewError = "preview start failed" })
            assert(startSession:createStage("sample", "start-error", "Start Error", 120))
            local started, startError = startSession:play()
            test.assertEqual(started, nil)
            test.assertContains(startError, "preview start failed")
            test.assertEqual(startSession:isPlaying(), false)

            local session = newSession({ updateError = "preview update failed" })
            assert(session:createStage("sample", "error", "Error", 120))
            assert(session:play())
            local updated, errorMessage = session:update(0.1, 16)
            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "preview update failed")
            test.assertEqual(session:isPlaying(), false)

            local drawSession = newSession({ drawError = "preview draw failed" })
            assert(drawSession:createStage("sample", "draw-error", "Draw Error", 120))
            assert(drawSession:play())
            local drawn, drawError = drawSession:drawPreview({})
            test.assertEqual(drawn, nil)
            test.assertContains(drawError, "preview draw failed")
            test.assertEqual(drawSession:isPlaying(), false)

            assert(drawSession:play())
            drawSession:handlePreviewError()
            test.assertEqual(drawSession:isPlaying(), false)
        end,
    },
    {
        name = "타임라인 auto-follow는 fractional 시작 beat를 유지한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "follow", "Follow", 120))
            assert(session:play())
            assert(session:update(7.25, 12))
            test.assertNear(session:getBeat(), 14.5, 0.000001)
            test.assertNear(session:getTimelineStartBeat(), 6.5, 0.000001)
        end,
    },
    {
        name = "타임라인 zoom은 Scale 경계와 cursor anchor를 보존한다",
        run = function(test)
            local noStageSession = newSession()
            local noStageChanged, noStageError = noStageSession:zoomTimeline(100, 1)
            test.assertEqual(noStageChanged, nil)
            test.assertContains(noStageError, "No Stage")

            local zoomInSession = newSession({ stored = VALID_STAGE })
            assert(zoomInSession:openStage("sample", "tutorial"))
            assert(zoomInSession:zoomTimeline(0, 1))
            test.assertNear(
                zoomInSession:getProperty("editorProperties", "scale"),
                1.25,
                0.000001
            )
            test.assertEqual(zoomInSession:isDirty(), true)
            test.assertNear(
                zoomInSession:getDocument():toTable().editorSettings.scale,
                1.25,
                0.000001
            )
            assert(zoomInSession:zoomTimeline(0, -1))
            test.assertNear(
                zoomInSession:getProperty("editorProperties", "scale"),
                1,
                0.000001
            )
            test.assertEqual(zoomInSession:getDocument():toTable().editorSettings, nil)

            local zoomOutSession = newSession({ stored = VALID_STAGE })
            assert(zoomOutSession:openStage("sample", "tutorial"))
            assert(zoomOutSession:zoomTimeline(0, -1))
            test.assertNear(
                zoomOutSession:getProperty("editorProperties", "scale"),
                0.8,
                0.000001
            )

            local anchorSession = newSession({ stored = VALID_STAGE })
            assert(anchorSession:openStage("sample", "tutorial"))
            anchorSession.timelineStartBeat = 4
            local cursorOffsetX = 320
            local oldCursorBeat = 4 + cursorOffsetX / 32 - 1
            assert(anchorSession:zoomTimeline(cursorOffsetX, 1))
            local newScale = anchorSession:getProperty("editorProperties", "scale")
            local newCursorBeat = anchorSession:getTimelineStartBeat()
                + cursorOffsetX / (32 * newScale) - 1
            test.assertNear(newScale, 1.25, 0.000001)
            test.assertNear(newCursorBeat, oldCursorBeat, 0.000001)

            local clampedStartSession = newSession({ stored = VALID_STAGE })
            assert(clampedStartSession:openStage("sample", "tutorial"))
            assert(clampedStartSession:zoomTimeline(320, -1))
            test.assertEqual(clampedStartSession:getTimelineStartBeat(), 0)

            local maximumSession = newSession({
                stored = {
                    schemaVersion = 3,
                    projectId = "sample",
                    stageId = "maximum-scale",
                    name = "Maximum Scale",
                    bpm = 120,
                    editorSettings = { scale = 8 },
                    events = {},
                },
            })
            assert(maximumSession:openStage("sample", "maximum-scale"))
            assert(maximumSession:zoomTimeline(100, 1))
            test.assertEqual(maximumSession:getProperty("editorProperties", "scale"), 8)

            local minimumSession = newSession({
                stored = {
                    schemaVersion = 3,
                    projectId = "sample",
                    stageId = "minimum-scale",
                    name = "Minimum Scale",
                    bpm = 120,
                    editorSettings = { scale = 0.25 },
                    events = {},
                },
            })
            assert(minimumSession:openStage("sample", "minimum-scale"))
            assert(minimumSession:zoomTimeline(100, -1))
            test.assertEqual(minimumSession:getProperty("editorProperties", "scale"), 0.25)
        end,
    },
    {
        name = "타임라인 seek는 Snap을 적용하고 pan은 beat 0 경계를 지킨다",
        run = function(test)
            local noStageSession = newSession()
            local noStageSeek, seekError = noStageSession:seekTimeline(2)
            test.assertEqual(noStageSeek, nil)
            test.assertContains(seekError, "No Stage")

            local session, _, options = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:seekTimeline(3.5))
            test.assertNear(session:getBeat(), 4, 0.000001)
            test.assertNear(options.transportState.seekBeat, 4, 0.000001)

            session.timelineStartBeat = 4
            assert(session:panTimeline(64, 32))
            test.assertNear(session:getTimelineStartBeat(), 2, 0.000001)
            assert(session:panTimeline(96, 32))
            test.assertEqual(session:getTimelineStartBeat(), 0)
            assert(session:panTimeline(-64, 32))
            test.assertNear(session:getTimelineStartBeat(), 2, 0.000001)
            test.assertEqual(session:isDirty(), false)
        end,
    },
    {
        name = "Play 중 wheel zoom과 직접 Scale 편집은 timeline 시작 위치 계약을 지킨다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            session.timelineStartBeat = 4.5
            assert(session:setProperty("editorProperties", "scale", 2))
            test.assertEqual(session:getTimelineStartBeat(), 4.5)

            assert(session:play())
            assert(session:zoomTimeline(64, 1))
            test.assertNear(
                session:getProperty("editorProperties", "scale"),
                2.5,
                0.000001
            )
            test.assertEqual(session:isPlaying(), true)
        end,
    },
    {
        name = "EditorSession은 Project 음악 경로와 resolved Mixtape를 Transport에 전달한다",
        run = function(test)
            local stage = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "music",
                name = "Music",
                bpm = 120,
                mixtape = {
                    music = "assets/audio/song.ogg",
                    volume = 0.5,
                    beat0Offset = -0.25,
                },
                events = {},
            }
            local session, _, state = newSession({ stored = stage })
            assert(session:openStage("sample", "music"))
            assert(session:play())

            test.assertEqual(state.transportState.resolvedMusicPath,
                "projects/sample/assets/audio/song.ogg")
            test.assertEqual(state.transportState.mixtape.music, "assets/audio/song.ogg")
            test.assertEqual(state.transportState.mixtape.volume, 0.5)
            test.assertEqual(state.transportState.mixtape.beat0Offset, -0.25)
        end,
    },
    {
        name = "EditorSession property getter와 setter는 StageDocument에 위임한다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))

            assert(session:setProperty("editorProperties", "playbackRate", 0.5))
            assert(session:setProperty("mixtapeProperties", "volume", 0.25))
            assert(session:setProperty("mixtapeProperties", "bpm", 90))

            test.assertEqual(session:getProperty("editorProperties", "playbackRate"), 0.5)
            test.assertEqual(session:getProperty("mixtapeProperties", "volume"), 0.25)
            test.assertEqual(session:getProperty("mixtapeProperties", "bpm"), 90)
            test.assertEqual(session:isDirty(), true)
        end,
    },
    {
        name = "EditorSession은 선택된 Auto Play를 TestPlayer 시작에 전달한다",
        run = function(test)
            local session, _, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:setProperty("editorProperties", "autoPlay", "bad"))
            assert(session:play())

            test.assertEqual(state.testPlayerState.autoPlay, "bad")
            test.assertEqual(state.testPlayerState.startBeat, 0)
        end,
    },
    {
        name = "EditorSession은 Playback Rate를 Transport와 TestPlayer에 적용한다",
        run = function(test)
            local session, _, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("playbackRate", 0.5))
            assert(session:play())
            assert(session:update(0.2, 16))

            test.assertNear(state.transportState.lastDeltaTime, 0.2, 0.000001)
            test.assertNear(state.testPlayerState.lastDeltaTime, 0.1, 0.000001)
            test.assertEqual(state.transportState.playbackRate, 0.5)
        end,
    },
    {
        name = "EditorSession은 선택된 Metronome을 현재 설정으로 시작한다",
        run = function(test)
            local session, _, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:getDocument():setEditorSetting("metronomePeriod", 3))
            assert(session:getDocument():setEditorSetting("playbackRate", 0.5))
            assert(session:play())

            test.assertEqual(state.metronomeState.playing, true)
            test.assertEqual(state.metronomeState.bpm, 120)
            test.assertEqual(state.metronomeState.period, 3)
            test.assertEqual(state.metronomeState.beat, 0)
            test.assertEqual(state.metronomeState.playbackRate, 0.5)
        end,
    },
    {
        name = "EditorSession update는 Transport의 현재 beat를 Metronome에 전달한다",
        run = function(test)
            local session, _, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:play())

            assert(session:update(0.25, 16))

            test.assertEqual(state.metronomeState.updateCount, 1)
            test.assertNear(state.metronomeState.updateBeat, 0.5, 0.000001)
        end,
    },
    {
        name = "EditorSession은 Metronome update 실패 시 재생을 정리한다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:play())
            state.metronomeState.updateError = "metronome update failed"
            state.transportState.pauseCount = 0
            state.metronomeState.pauseCount = 0
            state.testPlayerState.stopCount = 0

            local updated, errorMessage = session:update(0.25, 16)

            test.assertEqual(updated, nil)
            test.assertEqual(errorMessage, "metronome update failed")
            test.assertEqual(state.transportState.pauseCount, 1)
            test.assertEqual(state.metronomeState.pauseCount, 1)
            test.assertEqual(state.testPlayerState.stopCount, 1)
            test.assertEqual(session:isPlaying(), false)
            test.assertEqual(state.metronomeState.playing, false)
            test.assertEqual(testPlayer.playing, false)
        end,
    },
    {
        name = "EditorSession update는 TestPlayer 실패 시 이전 beat로 rollback한다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:play())
            assert(session:update(0.5, 16))
            local previousBeat = session:getBeat()
            state.updateError = "preview update failed"

            local updated, errorMessage = session:update(0.25, 16)

            test.assertEqual(updated, nil)
            test.assertEqual(errorMessage, "preview update failed")
            test.assertNear(session:getBeat(), previousBeat, 0.000001)
            test.assertEqual(state.transportState.seekCount, 1)
            test.assertNear(state.transportState.seekBeat, previousBeat, 0.000001)
            test.assertEqual(state.transportState.playing, false)
            test.assertEqual(state.metronomeState.playing, false)
            test.assertEqual(testPlayer.playing, false)
        end,
    },
    {
        name = "EditorSession은 TestPlayer와 beat rollback 오류를 모두 보존한다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:play())
            state.updateError = "preview update failed"
            state.transportState.seekError = "seek rollback failed"

            local updated, errorMessage = session:update(0.25, 16)

            test.assertEqual(updated, nil)
            test.assertEqual(
                errorMessage,
                "preview update failed Rollback failed: seek rollback failed"
            )
            test.assertEqual(state.transportState.seekCount, 1)
            test.assertEqual(state.transportState.playing, false)
            test.assertEqual(state.metronomeState.playing, false)
            test.assertEqual(testPlayer.playing, false)
        end,
    },
    {
        name = "EditorSession Play 재진입은 상태를 바꾸지 않는 성공이다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            assert(session:play())
            assert(session:update(0.25, 16))
            local previousBeat = session:getBeat()
            local previousGame = testPlayer.game
            local configureCount = state.transportState.configureCount
            local transportPlayCount = state.transportState.playCount
            local testPlayerStartCount = state.testPlayerState.startCount
            local metronomePlayCount = state.metronomeState.playCount
            local transportPauseCount = state.transportState.pauseCount
            local metronomePauseCount = state.metronomeState.pauseCount
            local testPlayerStopCount = state.testPlayerState.stopCount

            local played, errorMessage = session:play()

            test.assertEqual(played, true)
            test.assertEqual(errorMessage, nil)
            test.assertNear(session:getBeat(), previousBeat, 0.000001)
            test.assertEqual(session:isPlaying(), true)
            test.assertEqual(testPlayer.game, previousGame)
            test.assertEqual(state.transportState.configureCount, configureCount)
            test.assertEqual(state.transportState.playCount, transportPlayCount)
            test.assertEqual(state.testPlayerState.startCount, testPlayerStartCount)
            test.assertEqual(state.metronomeState.playCount, metronomePlayCount)
            test.assertEqual(state.transportState.pauseCount, transportPauseCount)
            test.assertEqual(state.metronomeState.pauseCount, metronomePauseCount)
            test.assertEqual(state.testPlayerState.stopCount, testPlayerStopCount)
        end,
    },
    {
        name = "EditorSession 시작 실패는 모든 재생 구성 요소를 정리한다",
        run = function(test)
            local cases = {
                { target = "preview", errorMessage = "preview failed" },
                { target = "transport", errorMessage = "transport failed" },
                { target = "metronome", errorMessage = "metronome failed" },
            }

            for _, case in ipairs(cases) do
                local options = { stored = VALID_STAGE }
                if case.target == "preview" then options.previewError = case.errorMessage end
                local session, testPlayer, state = newSession(options)
                assert(session:openStage("sample", "tutorial"))
                assert(session:getDocument():setEditorSetting("metronome", true))
                if case.target == "transport" then
                    state.transportState.playError = case.errorMessage
                elseif case.target == "metronome" then
                    state.metronomeState.playError = case.errorMessage
                end
                state.transportState.pauseCount = 0
                state.metronomeState.pauseCount = 0
                state.testPlayerState.stopCount = 0

                local played, errorMessage = session:play()

                test.assertEqual(played, nil)
                test.assertContains(errorMessage, case.errorMessage)
                test.assertEqual(state.transportState.pauseCount, 1)
                test.assertEqual(state.metronomeState.pauseCount, 1)
                test.assertEqual(state.testPlayerState.stopCount, 1)
                test.assertEqual(state.transportState.playing, false)
                test.assertEqual(state.metronomeState.playing, false)
                test.assertEqual(testPlayer.playing, false)
                test.assertEqual(session:isPlaying(), false)
            end
        end,
    },
    {
        name = "Music decode 시작 실패는 Transport Metronome TestPlayer를 한 번씩 정리한다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:getDocument():setEditorSetting("metronome", true))
            state.transportState.playError = "Failed to decode Project music."
            state.transportState.pauseCount = 0
            state.metronomeState.pauseCount = 0
            state.testPlayerState.stopCount = 0

            local played, playError = session:play()

            test.assertEqual(played, nil)
            test.assertContains(playError, "decode")
            test.assertEqual(state.transportState.pauseCount, 1)
            test.assertEqual(state.metronomeState.pauseCount, 1)
            test.assertEqual(state.testPlayerState.stopCount, 1)
            test.assertEqual(state.transportState.playing, false)
            test.assertEqual(state.metronomeState.playing, false)
            test.assertEqual(testPlayer.playing, false)
            test.assertEqual(session:isPlaying(), false)
        end,
    },
    {
        name = "End Event에 도달하면 정확한 beat에서 에디터 재생을 끝낸다",
        run = function(test)
            local stage = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "ending",
                name = "Ending",
                bpm = 120,
                events = {
                    { id = "event-001", type = "end", startBeat = 2, track = 1 },
                },
            }
            local session, testPlayer = newSession({ stored = stage })
            assert(session:openStage("sample", "ending"))
            assert(session:play())

            assert(session:update(2, 16))

            test.assertEqual(session:isPlaying(), false)
            test.assertEqual(testPlayer.playing, false)
            test.assertNear(session:getBeat(), 2, 0.000001)
        end,
    },
    {
        name = "Set Input Enabled Event는 기본 true 입력 상태를 노드 값으로 변경한다",
        run = function(test)
            local stage = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "input-state",
                name = "Input State",
                bpm = 120,
                events = {
                    {
                        id = "event-001",
                        type = "setInputEnabled",
                        startBeat = 2,
                        track = 1,
                        enabled = false,
                    },
                    {
                        id = "event-002",
                        type = "setInputEnabled",
                        startBeat = 4,
                        track = 1,
                        enabled = true,
                    },
                },
            }
            local session = newSession({ stored = stage })
            assert(session:openStage("sample", "input-state"))
            test.assertEqual(session:isInputEnabled(), true)
            assert(session:play())
            assert(session:update(1, 16))
            test.assertEqual(session:isInputEnabled(), false)
            assert(session:update(1, 16))
            test.assertEqual(session:isInputEnabled(), true)

            session:pause()
            assert(session:seekTimeline(3))
            assert(session:play())
            test.assertEqual(session:isInputEnabled(), false)
        end,
    },
    {
        name = "End가 없으면 Music 종료 시 Stage를 끝내고 End가 있으면 유지한다",
        run = function(test)
            local session, testPlayer, state = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:play())
            state.transportState.musicFinished = true

            local updated, errorMessage, status = session:update(0.25, 16)

            test.assertEqual(updated, true)
            test.assertEqual(errorMessage, nil)
            test.assertEqual(status, "musicEnded")
            test.assertEqual(session:isPlaying(), false)
            test.assertEqual(testPlayer.playing, false)

            local stageWithEnd = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "music-before-end",
                name = "Music Before End",
                bpm = 120,
                events = {
                    { id = "end", type = "end", startBeat = 8, track = 1 },
                },
            }
            local endSession, _, endState = newSession({ stored = stageWithEnd })
            assert(endSession:openStage("sample", "music-before-end"))
            assert(endSession:play())
            endState.transportState.musicFinished = true
            local endUpdated, _, endStatus = endSession:update(0.25, 16)
            test.assertEqual(endUpdated, true)
            test.assertEqual(endStatus, nil)
            test.assertEqual(endSession:isPlaying(), true)
        end,
    },
    {
        name = "Timeline Event 배치는 기존 노드 영역과 겹치면 거부한다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:addTimelineEvent("end", 4, 2))

            local added, errorMessage, errorCode = session:addTimelineEvent(
                "setInputEnabled",
                4,
                2
            )

            test.assertEqual(added, nil)
            test.assertContains(errorMessage, "overlap")
            test.assertEqual(errorCode, "TIMELINE_EVENT_OVERLAP")
            test.assertEqual(#session:getTimelineEvents(), 1)
        end,
    },
    {
        name = "Timeline Event API는 Snap과 Track 범위를 적용한다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            assert(session:setProperty("editorProperties", "snap", 4))

            local event = assert(session:addTimelineEvent("setInputEnabled", 7.9, 3))
            test.assertEqual(event.startBeat, 4)
            test.assertEqual(event.track, 3)
            assert(session:moveTimelineEvent(event.id, 10.1, 10))
            local moved = session:getTimelineEvents()[1]
            test.assertEqual(moved.startBeat, 8)
            test.assertEqual(moved.track, 10)

            local invalid, errorMessage = session:moveTimelineEvent(event.id, 4, 11)
            test.assertEqual(invalid, nil)
            test.assertContains(errorMessage, "track")
        end,
    },
    {
        name = "Metronome false Play는 SoundData와 Source를 만들지 않는다",
        run = function(test)
            local state = { soundDataCount = 0, sourceCount = 0 }
            local metronome = require("editor.playback.MetronomePlayback").new({
                soundDataFactory = function()
                    state.soundDataCount = state.soundDataCount + 1
                    return { setSample = function() end }
                end,
                sourceFactory = function()
                    state.sourceCount = state.sourceCount + 1
                    return {}
                end,
            })
            local session = newSession({
                stored = VALID_STAGE,
                metronome = metronome,
            })
            assert(session:openStage("sample", "tutorial"))

            assert(session:play())

            test.assertEqual(
                session:getProperty("editorProperties", "metronome"),
                false
            )
            test.assertEqual(state.soundDataCount, 0)
            test.assertEqual(state.sourceCount, 0)
        end,
    },
}
