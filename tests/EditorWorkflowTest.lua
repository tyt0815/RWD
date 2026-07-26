local function newFixture(config)
    config = config or {}
    local state = {
        saved = {},
        quitCount = 0,
        previewPlaying = false,
        musicListProjectId = nil,
    }
    local project = { id = "sample", title = "Sample", entryModule = "sample.game" }
    local catalog = {
        listProjects = function() return { project }, nil end,
        getProject = function(_, projectId)
            if projectId == "sample" then return project, nil end
            return nil, "missing project"
        end,
        createGame = function() return {}, nil end,
    }
    local store = config.stageStore or {
        listStages = function() return { "tutorial" }, nil end,
        stageExists = function(_, _, stageId) return state.saved[stageId] ~= nil, nil end,
        load = function(_, _, stageId)
            local data = state.saved[stageId]
            if not data then return nil, "missing Stage" end
            return data, nil
        end,
        save = function(_, data, overwrite)
            if config.saveError then return nil, config.saveError end
            if state.saved[data.stageId] and not overwrite then
                return nil, "already exists", "STAGE_EXISTS"
            end
            state.saved[data.stageId] = data
            return true, nil
        end,
    }
    local testPlayer = {
        start = function()
            if config.previewError then return nil, config.previewError end
            state.previewPlaying = true
            return true, nil
        end,
        stop = function() state.previewPlaying = false end,
        update = function()
            if config.previewUpdateError then return nil, config.previewUpdateError end
            return true, nil
        end,
        draw = function() return true, nil end,
    }
    local musicCatalog = {
        list = function(_, projectId)
            state.musicListProjectId = projectId
            if config.musicError then return nil, config.musicError end
            return config.musicFiles or {
                "assets/audio/a.ogg",
                "assets/audio/b.wav",
            }, nil
        end,
    }
    local EditorSession = require("editor.EditorSession")
    local session = EditorSession.new({
        projectCatalog = catalog,
        stageStore = store,
        testPlayer = testPlayer,
        transportFactory = config.transportFactory,
        metronome = config.metronome,
    })
    local EditorApp = require("editor.EditorApp")
    local app = EditorApp.new({
        projectCatalog = catalog,
        musicCatalog = musicCatalog,
        stageStore = store,
        testPlayer = testPlayer,
        session = session,
        onQuit = function() state.quitCount = state.quitCount + 1 end,
    })
    return app, state
end

local function createStageThroughDialog(app, stageId)
    app:executeAction("new")
    local dialog = app:getDialog()
    assert(dialog:select("projectId", "sample"))
    assert(dialog:setValue("stageId", stageId))
    assert(dialog:setValue("name", "Stage " .. stageId))
    assert(dialog:setValue("bpm", "120"))
    dialog:submit("confirm")
    app:update(0)
end

local function clearValueEdit(app)
    while app:getViewModel().valueEdit.text ~= "" do
        app:keypressed("backspace")
    end
end

return {
    {
        name = "Stage가 없으면 보이지 않는 Event 행 클릭을 무시한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)

            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            test.assertEqual(app:getViewModel().selectedEventId, "editorProperties")

            createStageThroughDialog(app, "default-property-event")
            test.assertEqual(app:getViewModel().selectedEventId, "editorProperties")
        end,
    },
    {
        name = "Property Events는 Editor Properties를 기본 선택하고 선택만으로 dirty가 되지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "property-events")
            app:executeAction("save")

            local viewModel = app:getViewModel()
            test.assertEqual(viewModel.propertyEvents[1].label, "Editor Properties")
            test.assertEqual(viewModel.propertyEvents[2].label, "Mixtape Properties")
            test.assertEqual(viewModel.selectedEventId, "editorProperties")
            test.assertEqual(viewModel.properties[1].label, "Scale")
            test.assertEqual(viewModel.properties[2].label, "Playback Rate")
            test.assertEqual(viewModel.properties[3].label, "Metronome")
            test.assertEqual(viewModel.properties[4].label, "Metronome Period")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            viewModel = app:getViewModel()
            test.assertEqual(viewModel.selectedEventId, "mixtapeProperties")
            test.assertEqual(viewModel.properties[1].label, "Music")
            test.assertEqual(viewModel.properties[2].label, "Volume")
            test.assertEqual(viewModel.properties[3].label, "Beat 0 Offset")
            test.assertEqual(viewModel.properties[4].label, "BPM")
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "숫자 Property는 음수를 포함해 인라인 편집한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "numeric-property")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local offsetRect = EditorLayout.getPropertyValueRect(app.layout, 3)
            app:mousepressed(offsetRect.x + 8, offsetRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("-0.5")
            app:keypressed("return")

            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                -0.5
            )
            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getDialog(), nil)
        end,
    },
    {
        name = "숫자 Property는 최초 포커스부터 커서 위치에 이어서 입력한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "numeric-property-initial-cursor")

            local scaleRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(scaleRect.x + 8, scaleRect.y + 8, 1)
            app:textinput("2")

            test.assertEqual(app:getViewModel().valueEdit.text, "12")
            test.assertEqual(app:getViewModel().valueEdit.cursorPosition, 2)
        end,
    },
    {
        name = "숫자 Property는 커서를 이동해 중간 삽입과 삭제를 처리한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "numeric-property-cursor")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(bpmRect.x + 8, bpmRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("135")

            app:keypressed("left")
            app:textinput("2")
            test.assertEqual(app:getViewModel().valueEdit.text, "1325")
            test.assertEqual(app:getViewModel().valueEdit.cursorPosition, 3)

            app:keypressed("backspace")
            test.assertEqual(app:getViewModel().valueEdit.text, "135")
            test.assertEqual(app:getViewModel().valueEdit.cursorPosition, 2)

            app:keypressed("delete")
            test.assertEqual(app:getViewModel().valueEdit.text, "13")
            test.assertEqual(app:getViewModel().valueEdit.cursorPosition, 2)

            app:keypressed("left")
            app:keypressed("right")
            app:textinput("5")
            app:keypressed("return")
            test.assertEqual(app:getSession():getProperty("mixtapeProperties", "bpm"), 135)
        end,
    },
    {
        name = "숫자 Property 커서는 포커스 직후부터 깜빡인다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "numeric-property-cursor-blink")

            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 2)
            app:mousepressed(bpmRect.x + 8, bpmRect.y + 8, 1)
            test.assertEqual(app:getViewModel().valueEdit.cursorVisible, true)

            app:update(0.49)
            test.assertEqual(app:getViewModel().valueEdit.cursorVisible, true)
            app:update(0.02)
            test.assertEqual(app:getViewModel().valueEdit.cursorVisible, false)
            app:update(0.5)
            test.assertEqual(app:getViewModel().valueEdit.cursorVisible, true)

            app:keypressed("left")
            test.assertEqual(app:getViewModel().valueEdit.cursorVisible, true)
        end,
    },
    {
        name = "boolean Property는 클릭 즉시 전환한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "boolean-property")
            app:executeAction("save")

            test.assertEqual(
                app:getSession():getProperty("editorProperties", "metronome"),
                false
            )
            local metronomeRect = EditorLayout.getPropertyValueRect(app.layout, 3)
            app:mousepressed(metronomeRect.x + 8, metronomeRect.y + 8, 1)

            test.assertEqual(
                app:getSession():getProperty("editorProperties", "metronome"),
                true
            )
            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "invalid 숫자 Property는 편집 상태를 유지하고 값을 적용하지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "invalid-property")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local volumeRect = EditorLayout.getPropertyValueRect(app.layout, 2)
            app:mousepressed(volumeRect.x + 8, volumeRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("2")
            app:keypressed("return")

            local valueEdit = app:getViewModel().valueEdit
            test.assertEqual(valueEdit.propertyId, "volume")
            test.assertEqual(valueEdit.invalid, true)
            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "volume"),
                1
            )
            test.assertEqual(app:getDialog(), nil)
        end,
    },
    {
        name = "Music Property 클릭은 현재 Project 파일 목록으로 선택 모달을 연다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app, state = newFixture()
            createStageThroughDialog(app, "music-property")
            app:executeAction("save")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local musicRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)

            test.assertEqual(state.musicListProjectId, "sample")
            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getDialog():getKind(), "music")
            test.assertEqual(app:getDialog():getSelection("music"), "")
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "Music Apply는 선택 파일을 설정하고 None Apply는 nil로 지운다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "music-apply")
            app:executeAction("save")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local musicRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            assert(app:getDialog():select("music", "assets/audio/a.ogg"))
            app:getDialog():submit("confirm")
            app:update(0)

            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "music"),
                "assets/audio/a.ogg"
            )
            test.assertEqual(app:getSession():isDirty(), true)

            app:executeAction("save")
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            test.assertEqual(
                app:getDialog():getSelection("music"),
                "assets/audio/a.ogg"
            )
            assert(app:getDialog():select("music", ""))
            app:getDialog():submit("confirm")
            app:update(0)

            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "music"),
                nil
            )
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "Music Cancel은 값과 dirty 상태를 바꾸지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "music-cancel")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local musicRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            assert(app:getDialog():select("music", "assets/audio/b.wav"))
            app:getDialog():submit("confirm")
            app:update(0)
            app:executeAction("save")

            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            assert(app:getDialog():select("music", ""))
            app:getDialog():submit("cancel")
            app:update(0)

            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "music"),
                "assets/audio/b.wav"
            )
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "Music 목록 실패는 Stage를 바꾸지 않고 error 모달을 연다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture({ musicError = "music listing failed" })
            createStageThroughDialog(app, "music-error")
            app:executeAction("save")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local musicRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)

            test.assertEqual(app:getDialog():getKind(), "error")
            test.assertContains(app:getDialog().message, "music listing failed")
            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "music"),
                nil
            )
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "New dialog creates a dirty Stage",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "new-stage")
            test.assertEqual(app:getSession():getDocument():getStageId(), "new-stage")
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "Save menu persists Stage and clears dirty indicator",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "saved-stage")
            app:executeAction("save")
            test.assertTrue(state.saved["saved-stage"] ~= nil)
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "dirty New handles Save Discard and Cancel branches",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "current")
            app:executeAction("new")
            test.assertEqual(app:getDialog():getKind(), "unsaved")
            app:getDialog():submit("cancel")
            app:update(0)
            test.assertEqual(app:getSession():getDocument():getStageId(), "current")
            test.assertEqual(app:getDialog(), nil)

            local discardApp = newFixture()
            createStageThroughDialog(discardApp, "discard-current")
            discardApp:executeAction("new")
            discardApp:getDialog():submit("discard")
            discardApp:update(0)
            test.assertEqual(discardApp:getDialog():getKind(), "newStage")

            local saveApp, saveState = newFixture()
            createStageThroughDialog(saveApp, "save-current")
            saveApp:executeAction("new")
            saveApp:getDialog():submit("save")
            saveApp:update(0)
            test.assertTrue(saveState.saved["save-current"] ~= nil)
            test.assertEqual(saveApp:getDialog():getKind(), "newStage")
        end,
    },
    {
        name = "dirty Open handles Save Discard and Cancel branches",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "current")
            app:executeAction("open")
            app:getDialog():submit("discard")
            app:update(0)
            test.assertEqual(app:getDialog():getKind(), "openStage")

            local cancelApp = newFixture()
            createStageThroughDialog(cancelApp, "cancel-open")
            cancelApp:executeAction("open")
            cancelApp:getDialog():submit("cancel")
            cancelApp:update(0)
            test.assertEqual(cancelApp:getDialog(), nil)
            test.assertEqual(cancelApp:getSession():getDocument():getStageId(), "cancel-open")

            local saveApp, saveState = newFixture()
            createStageThroughDialog(saveApp, "save-open")
            saveApp:executeAction("open")
            saveApp:getDialog():submit("save")
            saveApp:update(0)
            test.assertTrue(saveState.saved["save-open"] ~= nil)
            test.assertEqual(saveApp:getDialog():getKind(), "openStage")
        end,
    },
    {
        name = "Save As conflict overwrites the requested ID",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "source")
            state.saved.copy = { occupied = true }
            app:executeAction("saveAs")
            assert(app:getDialog():setValue("stageId", "copy"))
            assert(app:getDialog():setValue("name", "Copy"))
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertEqual(app:getDialog():getKind(), "overwrite")
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertEqual(app:getSession():getDocument():getStageId(), "copy")
        end,
    },
    {
        name = "Music 없음에서도 Play와 Pause는 beat와 Project preview를 제어한다",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "preview")
            app:executeAction("play")
            test.assertEqual(app:getViewModel().playing, true)
            test.assertEqual(state.previewPlaying, true)
            app:update(0.25)
            test.assertNear(app:getViewModel().beat, 0.5, 0.000001)
            app:executeAction("pause")
            test.assertEqual(app:getViewModel().playing, false)
            test.assertEqual(state.previewPlaying, false)
            app:update(0.25)
            test.assertNear(app:getViewModel().beat, 0.5, 0.000001)
        end,
    },
    {
        name = "Music decode 실패는 preview를 정리하고 view model에 error dialog를 표시한다",
        run = function(test)
            local Core = require("core")
            local transport
            local metronomeState = { playing = false, pauseCount = 0 }
            local app, state = newFixture({
                transportFactory = function(bpm)
                    transport = assert(Core.PlaybackTransport.new({
                        bpm = bpm,
                        musicPlayback = Core.MusicPlayback.new({
                            sourceFactory = function()
                                error("Failed to decode Project music.")
                            end,
                        }),
                    }))
                    return transport, nil
                end,
                metronome = {
                    play = function()
                        metronomeState.playing = true
                        return true, nil
                    end,
                    pause = function()
                        metronomeState.pauseCount = metronomeState.pauseCount + 1
                        metronomeState.playing = false
                        return true, nil
                    end,
                },
            })
            createStageThroughDialog(app, "decode-error")
            assert(app:getSession():setProperty(
                "mixtapeProperties",
                "music",
                "assets/audio/broken.wav"
            ))
            assert(app:getSession():setProperty(
                "editorProperties",
                "metronome",
                true
            ))
            metronomeState.pauseCount = 0

            local played, playError = app:executeAction("play")
            local viewModel = app:getViewModel()

            test.assertEqual(played, nil)
            test.assertContains(playError, "decode")
            test.assertEqual(viewModel.dialog and viewModel.dialog.kind, "error")
            test.assertContains(viewModel.dialog.message, "decode")
            test.assertEqual(state.previewPlaying, false)
            test.assertEqual(transport:isPlaying(), false)
            test.assertEqual(metronomeState.playing, false)
            test.assertEqual(metronomeState.pauseCount, 1)
        end,
    },
    {
        name = "Music duration 이후에도 view model beat는 계속 증가한다",
        run = function(test)
            local Core = require("core")
            local sourceState = { playing = false, stopped = false }
            local app = newFixture({
                transportFactory = function(bpm)
                    local playback = Core.MusicPlayback.new({
                        sourceFactory = function()
                            return {
                                getDuration = function() return 0.1 end,
                                setVolume = function() end,
                                setPitch = function() end,
                                seek = function() end,
                                tell = function() return 0 end,
                                play = function() sourceState.playing = true end,
                                pause = function() sourceState.playing = false end,
                                stop = function()
                                    sourceState.playing = false
                                    sourceState.stopped = true
                                end,
                            }
                        end,
                    })
                    return Core.PlaybackTransport.new({
                        bpm = bpm,
                        musicPlayback = playback,
                    })
                end,
            })
            createStageThroughDialog(app, "music-duration")
            assert(app:getSession():setProperty(
                "mixtapeProperties",
                "music",
                "assets/audio/short.wav"
            ))
            assert(app:executeAction("play"))

            app:update(0.1)
            local beatAfterDuration = app:getViewModel().beat
            test.assertEqual(sourceState.stopped, true)
            test.assertNear(beatAfterDuration, 0.2, 0.000001)

            app:update(0.25)
            test.assertTrue(app:getViewModel().beat > beatAfterDuration)
            test.assertNear(app:getViewModel().beat, 0.7, 0.000001)
            test.assertEqual(app:getViewModel().playing, true)
        end,
    },
    {
        name = "wheel zoom 뒤 Save한 JSON은 non-default Scale만 희소 저장한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = { files = {} }
            function fileSystem:list() return {}, nil end
            function fileSystem:read(path) return self.files[path], nil end
            function fileSystem:exists(path) return self.files[path] ~= nil end
            function fileSystem:isFile(path) return self.files[path] ~= nil end
            function fileSystem:writeAtomic(path, contents)
                self.files[path] = contents
                return true, nil
            end
            local app = newFixture({
                stageStore = StageStore.new(fileSystem, json),
            })
            createStageThroughDialog(app, "sparse-scale")
            local timeline = app.layout.timeline
            app:mousemoved(timeline.x, timeline.y)
            app:wheelmoved(0, 1)
            app:executeAction("save")

            local path = "projects/sample/stages/sparse-scale.json"
            local decoded = assert(json.decode(fileSystem.files[path]))
            test.assertNear(decoded.editorSettings.scale, 1.25, 0.000001)
            test.assertEqual(decoded.editorSettings.metronome, nil)
            test.assertEqual(decoded.editorSettings.metronomePeriod, nil)
            test.assertEqual(decoded.editorSettings.playbackRate, nil)
            test.assertEqual(decoded.mixtape, nil)
        end,
    },
    {
        name = "wheel zoom은 마지막 mouse 위치가 timeline 안일 때만 적용된다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "wheel-hover")
            app:executeAction("save")
            local timeline = app.layout.timeline

            app:wheelmoved(0, 1)
            test.assertEqual(
                app:getSession():getProperty("editorProperties", "scale"),
                1
            )

            app:mousemoved(timeline.x + 320, timeline.y - 1)
            test.assertEqual(app.mouseX, timeline.x + 320)
            test.assertEqual(app.mouseY, timeline.y - 1)
            app:wheelmoved(0, 1)
            test.assertEqual(
                app:getSession():getProperty("editorProperties", "scale"),
                1
            )

            app:mousemoved(timeline.x + timeline.width, timeline.y + 20)
            app:wheelmoved(0, 1)
            test.assertEqual(
                app:getSession():getProperty("editorProperties", "scale"),
                1
            )

            app:mousemoved(timeline.x + 320, timeline.y + 20)
            app:wheelmoved(0, 1)
            test.assertNear(
                app:getSession():getProperty("editorProperties", "scale"),
                1.25,
                0.000001
            )
            test.assertNear(app:getSession():getTimelineStartBeat(), 2, 0.000001)
            test.assertEqual(app:getSession():isDirty(), true)

            app:executeAction("new")
            test.assertEqual(app:getDialog():getKind(), "unsaved")
            app:mousemoved(timeline.x + 320, timeline.y + 20)
            app:wheelmoved(0, 1)
            test.assertNear(
                app:getSession():getProperty("editorProperties", "scale"),
                1.25,
                0.000001
            )
        end,
    },
    {
        name = "wheel zoom은 Play 중 허용되고 no Stage 오류를 modal로 표시한다",
        run = function(test)
            local noStageApp = newFixture()
            local noStageTimeline = noStageApp.layout.timeline
            noStageApp:mousemoved(
                noStageTimeline.x + 20,
                noStageTimeline.y + 20
            )
            noStageApp:wheelmoved(0, 1)
            test.assertEqual(noStageApp:getDialog():getKind(), "error")

            local app = newFixture()
            createStageThroughDialog(app, "playing-wheel")
            assert(app:executeAction("play"))
            local timeline = app.layout.timeline
            app:mousemoved(timeline.x + 64, timeline.y + 20)
            app:wheelmoved(0, -1)

            test.assertNear(
                app:getSession():getProperty("editorProperties", "scale"),
                0.8,
                0.000001
            )
            test.assertEqual(app:getSession():isPlaying(), true)
        end,
    },
    {
        name = "Scale 기반 visible count가 Play auto-follow에 반영된다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "scaled-auto-follow")
            assert(app:getSession():setProperty("editorProperties", "scale", 2))
            assert(app:executeAction("play"))

            app:update(10)

            test.assertNear(app:getSession():getBeat(), 20, 0.000001)
            test.assertNear(
                app:getSession():getTimelineStartBeat(),
                6,
                0.000001
            )
        end,
    },
    {
        name = "최소 너비와 최대 Scale의 auto-follow는 playhead를 timeline 안에 둔다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "narrow-auto-follow")
            app.layout = EditorLayout.getLayout(800, 600)
            assert(app:getSession():setProperty("editorProperties", "scale", 8))
            assert(app:executeAction("play"))

            app:update(2)

            local viewModel = app:getViewModel()
            local pixelsPerBeat = EditorLayout.getPixelsPerBeat(viewModel.scale)
            local playheadX = (viewModel.beat - viewModel.timelineStartBeat)
                * pixelsPerBeat
            test.assertEqual(
                EditorLayout.getVisibleBeatCount(app.layout, viewModel.scale),
                3
            )
            test.assertTrue(playheadX >= 0)
            test.assertTrue(playheadX < app.layout.timeline.width)
        end,
    },
    {
        name = "Values에서 Scale 직접 편집은 timeline 시작 beat를 바꾸지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "direct-scale-edit")
            app:getSession().timelineStartBeat = 4.5

            local scaleRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(scaleRect.x + 8, scaleRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("2")
            app:keypressed("return")

            test.assertEqual(
                app:getSession():getProperty("editorProperties", "scale"),
                2
            )
            test.assertEqual(app:getSession():getTimelineStartBeat(), 4.5)
        end,
    },
    {
        name = "Play는 유효한 active value edit를 확정하고 정리한 뒤 시작한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "play-valid-edit")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local offsetRect = EditorLayout.getPropertyValueRect(app.layout, 3)
            app:mousepressed(offsetRect.x + 8, offsetRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("-0.5")

            local started, errorMessage = app:executeAction("play")

            test.assertEqual(started, true)
            test.assertEqual(errorMessage, nil)
            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                -0.5
            )
            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():isPlaying(), true)
        end,
    },
    {
        name = "Play는 invalid active value edit를 유지하고 시작하지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "play-invalid-edit")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local volumeRect = EditorLayout.getPropertyValueRect(app.layout, 2)
            app:mousepressed(volumeRect.x + 8, volumeRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("2")

            local started, errorMessage = app:executeAction("play")

            test.assertEqual(started, nil)
            test.assertContains(errorMessage, "volume")
            test.assertEqual(app:getViewModel().valueEdit.propertyId, "volume")
            test.assertEqual(app:getViewModel().valueEdit.invalid, true)
            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "volume"),
                1
            )
            test.assertEqual(app:getSession():isPlaying(), false)
            test.assertEqual(app:getDialog(), nil)
        end,
    },
    {
        name = "Play 중 text와 key 입력은 stale value edit를 변경하지 않는다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "playing-value-input")
            app:executeAction("play")
            app:beginValueEdit("editorProperties", "scale")
            local valueEdit = app:getViewModel().valueEdit

            app:textinput("2")
            app:keypressed("backspace")
            app:keypressed("escape")

            test.assertEqual(app:getViewModel().valueEdit, valueEdit)
            test.assertEqual(valueEdit.text, "1")
            test.assertEqual(valueEdit.invalid, false)
        end,
    },
    {
        name = "BPM Value is edited through the general Property row without opening a dialog",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "inline-bpm")
            app:executeAction("save")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(bpmRect.x + 12, bpmRect.y + 12, 1)

            test.assertEqual(app:getDialog(), nil)
            test.assertEqual(app:getViewModel().valueEdit.propertyId, "bpm")
            test.assertEqual(app:getViewModel().valueEdit.text, "120")

            clearValueEdit(app)
            app:textinput("135")
            test.assertEqual(app:getViewModel().valueEdit.text, "135")
            app:keypressed("return")

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():getBpm(), 135)
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "Invalid inline BPM stays active and Escape cancels the general value edit",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "invalid-inline-bpm")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(bpmRect.x + 12, bpmRect.y + 12, 1)
            clearValueEdit(app)
            app:textinput("0")
            app:keypressed("return")

            test.assertEqual(app:getDialog(), nil)
            test.assertEqual(app:getViewModel().valueEdit.invalid, true)
            test.assertEqual(app:getSession():getBpm(), 120)

            app:keypressed("escape")
            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():getBpm(), 120)
        end,
    },
    {
        name = "Clicking outside a Property Value commits the inline edit",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "blur-inline-bpm")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(bpmRect.x + 12, bpmRect.y + 12, 1)
            clearValueEdit(app)
            app:textinput("90")
            app:mousepressed(app.layout.panels[2].x + 12, 100, 1)

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():getBpm(), 90)
        end,
    },
    {
        name = "Play 중에는 숨겨진 Property Values를 편집하지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "playing-properties")
            app:executeAction("play")

            local valueRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(valueRect.x + 8, valueRect.y + 8, 1)

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(
                app:getSession():getProperty("editorProperties", "scale"),
                1
            )
        end,
    },
    {
        name = "Preview update failure returns to an error dialog",
        run = function(test)
            local app = newFixture({ previewUpdateError = "preview exploded" })
            createStageThroughDialog(app, "preview-error")
            app:executeAction("play")
            app:update(0.1)
            test.assertEqual(app:getSession():isPlaying(), false)
            test.assertEqual(app:getDialog():getKind(), "error")
        end,
    },
    {
        name = "dirty Quit handles Save Discard Cancel and save failure",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "quit-stage")
            app:executeAction("quit")
            app:getDialog():submit("save")
            app:update(0)
            test.assertTrue(state.saved["quit-stage"] ~= nil)
            test.assertEqual(state.quitCount, 1)

            local cancelApp, cancelState = newFixture()
            createStageThroughDialog(cancelApp, "cancel-quit")
            cancelApp:executeAction("quit")
            cancelApp:getDialog():submit("cancel")
            cancelApp:update(0)
            test.assertEqual(cancelState.quitCount, 0)
            test.assertEqual(cancelApp:getDialog(), nil)

            local discardApp, discardState = newFixture()
            createStageThroughDialog(discardApp, "discard-quit")
            discardApp:executeAction("quit")
            discardApp:getDialog():submit("discard")
            discardApp:update(0)
            test.assertEqual(discardState.quitCount, 1)

            local failingApp, failingState = newFixture({ saveError = "save failed" })
            createStageThroughDialog(failingApp, "failed-quit")
            failingApp:executeAction("quit")
            failingApp:getDialog():submit("save")
            failingApp:update(0)
            test.assertEqual(failingState.quitCount, 0)
            test.assertEqual(failingApp:getDialog():getKind(), "error")
            test.assertEqual(failingApp:getSession():isDirty(), true)
        end,
    },
}
