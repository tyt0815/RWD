local VALID_STAGE = {
    schemaVersion = 2,
    projectId = "sample",
    stageId = "tutorial",
    name = "Tutorial",
    bpm = 120,
    events = {},
}

local OTHER_STAGE = {
    schemaVersion = 2,
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
    local project = { id = "sample", title = "Sample", entryModule = "sample.game" }
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
        start = function(self)
            if options.previewError then return nil, options.previewError end
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
        draw = function()
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
                transportState.mixtape = mixtape
                transportState.resolvedMusicPath = resolvedMusicPath
                if transportState.configureError then
                    return nil, transportState.configureError
                end
                return true, nil
            end,
            play = function(_, playbackRate)
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
            setBpm = function(_, bpmValue)
                transportState.candidateBpm = bpmValue
                if transportState.setBpmError then
                    return nil, transportState.setBpmError
                end
                transportState.bpm = bpmValue
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
            metronomeState.bpm = bpm
            metronomeState.period = period
            metronomeState.beat = beat
            metronomeState.playbackRate = playbackRate
            if metronomeState.playError then return nil, metronomeState.playError end
            metronomeState.playing = true
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
            test.assertEqual(session:getTimelineStartBeat(), 4)
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
            test.assertEqual(clockSession:getTimelineStartBeat(), 4)
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
        name = "Play와 Pause는 beat를 보존하고 TestPlayer를 전환한다",
        run = function(test)
            local session, testPlayer, state = newSession()
            assert(session:createStage("sample", "preview", "Preview", 120))
            assert(session:play())
            local firstGame = testPlayer.game
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 2, 0.000001)
            test.assertEqual(testPlayer.playing, true)
            session:pause()
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 2, 0.000001)
            test.assertEqual(testPlayer.playing, false)

            assert(session:play())
            test.assertEqual(state.startCount, 2)
            test.assertTrue(testPlayer.game ~= firstGame)
            test.assertNear(session:getBeat(), 2, 0.000001)
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
        name = "타임라인은 플레이헤드를 4박자 단위로 자동 추적한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "follow", "Follow", 120))
            assert(session:play())
            assert(session:update(7, 12))
            test.assertNear(session:getBeat(), 14, 0.000001)
            test.assertEqual(session:getTimelineStartBeat(), 4)
        end,
    },
    {
        name = "EditorSession은 Project 음악 경로와 resolved Mixtape를 Transport에 전달한다",
        run = function(test)
            local stage = {
                schemaVersion = 2,
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
}
