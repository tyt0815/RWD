local function newFixture(config)
    config = config or {}
    local state = {
        saved = {},
        quitCount = 0,
        previewPlaying = false,
        musicListProjectId = nil,
    }
    local project = config.project
        or { id = "sample", title = "Sample", entryModule = "sample.game" }
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
        musicOnsetDetector = config.musicOnsetDetector or {
            detect = function() return 0, nil end,
        },
        onQuit = function() state.quitCount = state.quitCount + 1 end,
        isControlDown = config.isControlDown,
        isShiftDown = config.isShiftDown,
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

local function createGlobalIdCollisionProject()
    return {
        id = "sample",
        title = "Sample",
        entryModule = "sample.game",
        eventCategories = {
            {
                id = "collision",
                label = "Collision",
                runtimeModule = "sample.game.Collision.Runtime",
                events = {
                    {
                        id = "mixtapeProperties",
                        label = "Project Mixtape Properties",
                        properties = {
                            { id = "first", label = "First", kind = "number", default = 1 },
                            { id = "second", label = "Second", kind = "number", default = 2 },
                            { id = "beat0Offset", label = "Project Offset",
                                kind = "number", default = 3 },
                        },
                    },
                    {
                        id = "editorProperties",
                        label = "Project Editor Properties",
                        properties = {
                            { id = "autoPlay", label = "Project Auto Play",
                                kind = "number", default = 4 },
                        },
                    },
                },
            },
        },
    }
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
        name = "Categories는 Global과 Game Manager 행을 제공한다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "category-list")

            local categories = app:getViewModel().categories
            test.assertEqual(#categories, 2)
            test.assertEqual(categories[1].label, "Global")
            test.assertEqual(categories[2].label, "Game Manager")

            local panel = app.layout.panels[2]
            app:mousemoved(panel.x + 8, panel.y + 40)
            app:wheelmoved(0, -1)
            test.assertEqual(app.scrollAreas.categories:getOffset(), 0)
        end,
    },
    {
        name = "상단 패널 휠은 독립 영역과 Properties Values 공유 영역으로 전달된다",
        run = function(test)
            local app = newFixture()
            local calls = { categories = 0, events = 0, properties = 0 }
            for name, area in pairs(app.scrollAreas) do
                area.scroll = function(_, deltaY)
                    calls[name] = calls[name] + deltaY
                    return true
                end
            end

            local panels = app.layout.panels
            for _, index in ipairs({ 2, 3, 4, 5 }) do
                local panel = panels[index]
                app:mousemoved(panel.x + 8, panel.y + 40)
                app:wheelmoved(0, -1)
            end

            test.assertEqual(calls.categories, -1)
            test.assertEqual(calls.events, -1)
            test.assertEqual(calls.properties, -2)
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
            test.assertEqual(viewModel.properties[1].label, "Snap")
            test.assertEqual(viewModel.properties[1].value, 1)
            test.assertEqual(viewModel.properties[2].label, "Scale")
            test.assertEqual(viewModel.properties[3].label, "Playback Rate")
            test.assertEqual(viewModel.properties[4].label, "Auto Play")
            test.assertEqual(viewModel.properties[4].value, "none")
            test.assertEqual(viewModel.properties[5].label, "Metronome")
            test.assertEqual(viewModel.properties[6].label, "Metronome Period")
            test.assertEqual(viewModel.properties[7].label, "Track")
            test.assertEqual(viewModel.properties[7].value, 10)
            test.assertEqual(viewModel.properties[8].label, "Preview Aspect Width")
            test.assertEqual(viewModel.properties[8].value, 16)
            test.assertEqual(viewModel.properties[9].label, "Preview Aspect Height")
            test.assertEqual(viewModel.properties[9].value, 9)
            test.assertEqual(viewModel.metronomePeriod, 4)

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            viewModel = app:getViewModel()
            test.assertEqual(viewModel.selectedEventId, "mixtapeProperties")
            test.assertEqual(viewModel.properties[1].label, "Music")
            test.assertEqual(viewModel.properties[2].label, "Volume")
            test.assertEqual(viewModel.properties[3].label, "Beat 0 Offset")
            test.assertEqual(viewModel.properties[4].label, "Onset Threshold")
            test.assertEqual(viewModel.properties[4].value, 0.01)
            test.assertEqual(viewModel.properties[5].label, "BPM")
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "Timeline view model은 변경된 Metronome Period를 제공한다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "timeline-period")

            assert(app:getSession():setProperty(
                "editorProperties",
                "metronomePeriod",
                5
            ))
            test.assertEqual(app:getViewModel().metronomePeriod, 5)
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
        name = "Mixtape Properties의 Onset Threshold 행은 Editor 설정을 편집한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "onset-threshold-row")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local thresholdRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(thresholdRect.x + 8, thresholdRect.y + 8, 1)
            clearValueEdit(app)
            app:textinput("0.02")
            app:keypressed("return")

            test.assertEqual(
                app:getSession():getProperty("editorProperties", "onsetThreshold"),
                0.02
            )
            test.assertEqual(app:getViewModel().valueEdit, nil)
        end,
    },
    {
        name = "숫자 Property는 최초 포커스부터 커서 위치에 이어서 입력한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "numeric-property-initial-cursor")

            local scaleRect = EditorLayout.getPropertyValueRect(app.layout, 2)
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
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 5)
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
        name = "Auto Play Property는 공통 ComboBox로 Good을 선택한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "auto-play-property")
            app:executeAction("save")

            local autoPlayRect = EditorLayout.getPropertyValueRect(app.layout, 4)
            app:mousepressed(autoPlayRect.x + 8, autoPlayRect.y + 8, 1)
            local comboBox = app:getViewModel().properties[4].comboBox
            test.assertTrue(comboBox:isOpen())

            local goodRect = EditorLayout.getComboBoxOptionRect(autoPlayRect, 2)
            app:mousepressed(goodRect.x + 8, goodRect.y + 8, 1)
            test.assertEqual(
                app:getSession():getProperty("editorProperties", "autoPlay"),
                "good"
            )
            test.assertEqual(comboBox:isOpen(), false)
            test.assertEqual(app:getSession():isDirty(), true)
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
            local metronomeRect = EditorLayout.getPropertyValueRect(app.layout, 5)
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
        name = "Music 첫 선택은 기본 Offset만 자동 설정하고 Auto 버튼은 다시 분석한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local detectedOffsets = { 0.25, 0.5 }
            local detectCount = 0
            local app = newFixture({
                musicOnsetDetector = {
                    detect = function(_, projectId, music, threshold)
                        detectCount = detectCount + 1
                        test.assertEqual(projectId, "sample")
                        test.assertTrue(music ~= nil)
                        test.assertEqual(threshold, 0.02)
                        return detectedOffsets[detectCount], nil
                    end,
                },
            })
            createStageThroughDialog(app, "music-onset")
            assert(app:getSession():setProperty(
                "editorProperties",
                "onsetThreshold",
                0.02
            ))
            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local musicRect = EditorLayout.getPropertyValueRect(app.layout, 1)

            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            assert(app:getDialog():select("music", "assets/audio/a.ogg"))
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertNear(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                0.25,
                0.000001
            )
            test.assertEqual(detectCount, 1)

            assert(app:getSession():setProperty(
                "mixtapeProperties",
                "beat0Offset",
                0.75
            ))
            app:mousepressed(musicRect.x + 8, musicRect.y + 8, 1)
            assert(app:getDialog():select("music", "assets/audio/b.wav"))
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertEqual(detectCount, 1)
            test.assertNear(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                0.75,
                0.000001
            )

            local autoRect = EditorLayout.getPropertyActionRect(app.layout, 3)
            local offsetRect = EditorLayout.getPropertyValueRect(app.layout, 3)
            app:mousepressed(offsetRect.x + 8, offsetRect.y + 8, 1)
            test.assertTrue(app:getViewModel().valueEdit ~= nil)
            app:mousepressed(
                autoRect.x + autoRect.width / 2,
                autoRect.y + autoRect.height / 2,
                1
            )
            test.assertEqual(detectCount, 2)
            test.assertNear(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                0.5,
                0.000001
            )
            test.assertEqual(app:getViewModel().valueEdit, nil)
        end,
    },
    {
        name = "Music이 없을 때 비활성 Auto 영역은 Offset 편집을 시작하지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "music-onset-disabled")
            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local autoRect = EditorLayout.getPropertyActionRect(app.layout, 3)

            app:mousepressed(
                autoRect.x + autoRect.width / 2,
                autoRect.y + autoRect.height / 2,
                1
            )

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getDialog(), nil)
        end,
    },
    {
        name = "첫 소리 자동 분석 실패는 선택한 Music을 유지하고 오류를 표시한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture({
                musicOnsetDetector = {
                    detect = function()
                        return nil, "onset decode failed"
                    end,
                },
            })
            createStageThroughDialog(app, "music-onset-error")
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
            test.assertEqual(
                app:getSession():getProperty("mixtapeProperties", "beat0Offset"),
                0
            )
            test.assertEqual(app:getDialog():getKind(), "error")
            test.assertContains(app:getDialog().message, "onset decode failed")
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
        name = "Ctrl marquee는 기존 Timeline 선택에 교차 노드를 추가한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local controlDown = false
            local app = newFixture({
                isControlDown = function() return controlDown end,
            })
            createStageThroughDialog(app, "timeline-additive-marquee")
            local first = assert(app:getSession():addTimelineEvent("end", 4, 1))
            local second = assert(app:getSession():addTimelineEvent(
                "setInputEnabled",
                8,
                2
            ))
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local bodyY = timeline.y + 32
            local trackHeight = (timeline.height - 32) / 10

            app:mousepressed(originX + 3 * 32, bodyY + 1, 1)
            app:mousemoved(originX + 4.3 * 32, bodyY + trackHeight - 1)
            app:mousereleased(0, 0, 1)
            test.assertEqual(app:getViewModel().selectedTimelineEventIds[first.id], true)

            controlDown = true
            app:mousepressed(originX + 7 * 32, bodyY + trackHeight + 1, 1)
            app:mousemoved(
                originX + 8.3 * 32,
                bodyY + trackHeight * 2 - 1
            )
            app:mousereleased(0, 0, 1)
            controlDown = false

            local selected = app:getViewModel().selectedTimelineEventIds
            test.assertEqual(selected[first.id], true)
            test.assertEqual(selected[second.id], true)
        end,
    },
    {
        name = "빈 배경 marquee 선택과 다중 drag는 충돌 preview와 원위치 복귀를 처리한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "timeline-group-drag")
            local first = assert(app:getSession():addTimelineEvent("end", 4, 1))
            local second = assert(app:getSession():addTimelineEvent(
                "setInputEnabled",
                8,
                2
            ))
            local third = assert(app:getSession():addTimelineEvent("tapNote", 12, 3))
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local bodyY = timeline.y + 32
            local trackHeight = (timeline.height - 32) / 10

            app:mousepressed(originX + 3 * 32, bodyY + 1, 1)
            app:mousemoved(originX + 8.3 * 32, bodyY + trackHeight * 2 - 1)
            app:mousereleased(0, 0, 1)
            local selected = app:getViewModel().selectedTimelineEventIds
            test.assertEqual(selected[first.id], true)
            test.assertEqual(selected[second.id], true)
            test.assertEqual(selected[third.id], nil)

            local firstRect = EditorLayout.getTimelineEventRect(timeline, first, {
                scale = 1,
                timelineStartBeat = 0,
                trackCount = 10,
            })
            app:mousepressed(firstRect.x + 2, firstRect.y + 2, 1)
            app:mousemoved(
                originX + 8 * 32 + 2,
                EditorLayout.getTimelineTrackCenterY(timeline, 2, 10)
            )
            local collisionView = app:getViewModel()
            test.assertEqual(collisionView.collisionTimelineEventIds[second.id], true)
            test.assertEqual(collisionView.collisionTimelineEventIds[third.id], true)
            test.assertEqual(collisionView.draggingTimelineEventIds[first.id], true)
            app:mousereleased(0, 0, 1)
            local failedMoveView = app:getViewModel()
            test.assertEqual(#failedMoveView.toasts, 1)
            test.assertContains(failedMoveView.toasts[1].message, "overlap")
            test.assertEqual(app:getDialog(), nil)

            local reverted = app:getSession():getTimelineEvents()
            test.assertEqual(reverted[1].startBeat, 4)
            test.assertEqual(reverted[1].track, 1)
            test.assertEqual(reverted[2].startBeat, 8)
            test.assertEqual(reverted[2].track, 2)

            firstRect = EditorLayout.getTimelineEventRect(timeline, reverted[1], {
                scale = 1,
                timelineStartBeat = 0,
                trackCount = 10,
            })
            app:mousepressed(firstRect.x + 2, firstRect.y + 2, 1)
            app:mousemoved(
                originX + 6 * 32 + 2,
                EditorLayout.getTimelineTrackCenterY(timeline, 2, 10)
            )
            test.assertEqual(
                next(app:getViewModel().collisionTimelineEventIds),
                nil
            )
            app:mousereleased(0, 0, 1)

            local moved = app:getSession():getTimelineEvents()
            test.assertEqual(moved[1].startBeat, 6)
            test.assertEqual(moved[1].track, 2)
            test.assertEqual(moved[2].startBeat, 10)
            test.assertEqual(moved[2].track, 3)
            test.assertEqual(moved[3].startBeat, 12)
            test.assertEqual(moved[3].track, 3)
        end,
    },
    {
        name = "Ctrl C X V는 마우스 Snap 위치에 노드와 Properties를 복제하고 Undo Redo한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local controlDown = false
            local shiftDown = false
            local project = require("projects.sample.project")
            local app = newFixture({
                project = project,
                isControlDown = function() return controlDown end,
                isShiftDown = function() return shiftDown end,
            })
            createStageThroughDialog(app, "timeline-clipboard-history")
            local input = assert(app:getSession():addTimelineEvent(
                "setInputEnabled",
                4,
                2
            ))
            assert(app:getSession():setTimelineEventProperty(
                input.id,
                "enabled",
                true
            ))
            local cue = assert(app:getSession():addTimelineEvent(
                "project:sampleGameplay:cueResponse",
                8,
                3,
                { responseDelayBeats = 6 }
            ))
            app.selectedTimelineEventIds = {
                [input.id] = true,
                [cue.id] = true,
            }

            controlDown = true
            app:keypressed("c")
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            app:mousemoved(
                originX + 21.8 * 32,
                EditorLayout.getTimelineTrackCenterY(timeline, 5, 10)
            )
            app:keypressed("v")
            controlDown = false

            local pasted = app:getSession():getTimelineEvents()
            test.assertEqual(#pasted, 4)
            test.assertEqual(pasted[3].startBeat, 21)
            test.assertEqual(pasted[3].track, 5)
            test.assertEqual(pasted[3].enabled, true)
            test.assertEqual(pasted[4].startBeat, 25)
            test.assertEqual(pasted[4].track, 6)
            test.assertEqual(pasted[4].params.responseDelayBeats, 6)
            test.assertTrue(pasted[3].id ~= input.id)
            test.assertTrue(pasted[4].id ~= cue.id)
            test.assertEqual(app.selectedTimelineEventIds[pasted[3].id], true)
            test.assertEqual(app.selectedTimelineEventIds[pasted[4].id], true)

            controlDown = true
            app:keypressed("z")
            test.assertEqual(#app:getSession():getTimelineEvents(), 2)
            shiftDown = true
            app:keypressed("z")
            shiftDown = false
            test.assertEqual(#app:getSession():getTimelineEvents(), 4)
            app.selectedTimelineEventIds = {
                [pasted[3].id] = true,
                [pasted[4].id] = true,
            }

            app:keypressed("x")
            controlDown = false
            test.assertEqual(#app:getSession():getTimelineEvents(), 2)
            controlDown = true
            app:keypressed("z")
            controlDown = false
            test.assertEqual(#app:getSession():getTimelineEvents(), 4)

            app.selectedTimelineEventIds = { [input.id] = true }
            app:keypressed("delete")
            test.assertEqual(#app:getSession():getTimelineEvents(), 3)
            controlDown = true
            shiftDown = true
            app:keypressed("z")
            shiftDown = false
            controlDown = false
            test.assertEqual(#app:getSession():getTimelineEvents(), 3)

            assert(app:getSession():setProperty("mixtapeProperties", "bpm", 150))
            controlDown = true
            app:keypressed("z")
            test.assertEqual(app:getSession():getBpm(), 120)
            shiftDown = true
            app:keypressed("z")
            shiftDown = false
            controlDown = false
            test.assertEqual(app:getSession():getBpm(), 150)
        end,
    },
    {
        name = "Timeline 노드는 클릭과 drag로 선택하고 Ctrl 클릭 후 Delete로 다중 삭제한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local controlDown = false
            local app = newFixture({
                isControlDown = function() return controlDown end,
            })
            createStageThroughDialog(app, "timeline-event-selection")
            local first = assert(app:getSession():addTimelineEvent("end", 4, 1))
            local second = assert(app:getSession():addTimelineEvent(
                "setInputEnabled",
                8,
                2
            ))
            local third = assert(app:getSession():addTimelineEvent("tapNote", 12, 3))
            app:executeAction("save")
            local eventView = {
                scale = 1,
                timelineStartBeat = 0,
                trackCount = 10,
            }
            local firstRect = EditorLayout.getTimelineEventRect(
                app.layout.timeline,
                first,
                eventView
            )
            local secondRect = EditorLayout.getTimelineEventRect(
                app.layout.timeline,
                second,
                eventView
            )

            app:mousepressed(firstRect.x + 2, firstRect.y + 2, 1)
            test.assertEqual(
                app:getViewModel().selectedTimelineEventIds[first.id],
                true
            )
            app:mousemoved(firstRect.x + 34, firstRect.y + 2)
            test.assertEqual(
                app:getViewModel().selectedTimelineEventIds[first.id],
                true
            )
            app:mousereleased(0, 0, 1)

            controlDown = true
            app:mousepressed(secondRect.x + 2, secondRect.y + 2, 1)
            controlDown = false
            local selected = app:getViewModel().selectedTimelineEventIds
            test.assertEqual(selected[first.id], true)
            test.assertEqual(selected[second.id], true)
            test.assertEqual(selected[third.id], nil)

            app:keypressed("delete")

            local events = app:getSession():getTimelineEvents()
            test.assertEqual(#events, 1)
            test.assertEqual(events[1].id, third.id)
            test.assertEqual(next(app:getViewModel().selectedTimelineEventIds), nil)
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "Set Input Enabled 선택값을 Properties Values에서 설정해 새 노드에 적용한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "input-event-default")
            app:executeAction("save")

            local categoryRect = EditorLayout.getCategoryRowRect(app.layout, 2)
            app:mousepressed(categoryRect.x + 8, categoryRect.y + 8, 1)
            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)

            local viewModel = app:getViewModel()
            test.assertEqual(viewModel.properties[1].label, "Enabled")
            test.assertEqual(viewModel.properties[1].value, false)
            local enabledRect = EditorLayout.getPropertyValueRect(app.layout, 1)
            app:mousepressed(enabledRect.x + 8, enabledRect.y + 8, 1)
            test.assertEqual(app:getViewModel().properties[1].value, true)
            test.assertEqual(app:getSession():isDirty(), false)

            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local trackY = EditorLayout.getTimelineTrackCenterY(timeline, 2, 10)
            app:mousepressed(originX + 4 * 32, trackY, 2)

            local placed = app:getSession():getTimelineEvents()[1]
            test.assertEqual(placed.type, "setInputEnabled")
            test.assertEqual(placed.enabled, true)
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "두 번째 End 우클릭 배치는 거부하고 error toast를 표시한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "single-end-toast")
            assert(app:getSession():addTimelineEvent("end", 4, 1))
            local categoryRect = EditorLayout.getCategoryRowRect(app.layout, 2)
            app:mousepressed(categoryRect.x + 8, categoryRect.y + 8, 1)
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local trackY = EditorLayout.getTimelineTrackCenterY(timeline, 3, 10)

            app:mousepressed(originX + 12 * 32, trackY, 2)

            test.assertEqual(#app:getSession():getTimelineEvents(), 1)
            test.assertEqual(#app:getViewModel().toasts, 1)
            test.assertContains(app:getViewModel().toasts[1].message, "one End")
            test.assertEqual(app:getDialog(), nil)
        end,
    },
    {
        name = "우클릭 배치 충돌은 노드를 만들지 않고 우상단 error toast를 표시한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "placement-collision-toast")
            assert(app:getSession():addTimelineEvent("end", 4, 2))
            local categoryRect = EditorLayout.getCategoryRowRect(app.layout, 2)
            app:mousepressed(categoryRect.x + 8, categoryRect.y + 8, 1)
            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local trackY = EditorLayout.getTimelineTrackCenterY(timeline, 2, 10)

            app:mousepressed(originX + 4 * 32, trackY, 2)

            local viewModel = app:getViewModel()
            test.assertEqual(#app:getSession():getTimelineEvents(), 1)
            test.assertEqual(app:getDialog(), nil)
            test.assertEqual(#viewModel.toasts, 1)
            test.assertEqual(viewModel.toasts[1].kind, "error")
            test.assertContains(viewModel.toasts[1].message, "overlap")

            for index = 2, 6 do
                app:showToast("Error " .. index, "error")
            end
            local stacked = app:getViewModel().toasts
            test.assertEqual(#stacked, 5)
            test.assertEqual(stacked[1].message, "Error 6")
            test.assertEqual(stacked[5].message, "Error 2")
            app:update(3.1)
            test.assertEqual(#app:getViewModel().toasts, 0)
        end,
    },
    {
        name = "Game Manager Event를 우클릭 배치하고 Snap beat와 Track으로 드래그한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "game-manager-events")
            assert(app:getSession():setProperty("editorProperties", "snap", 4))

            local categoryRect = EditorLayout.getCategoryRowRect(app.layout, 2)
            app:mousepressed(categoryRect.x + 8, categoryRect.y + 8, 1)
            test.assertEqual(app:getViewModel().selectedCategoryId, "gameManager")
            test.assertEqual(app:getViewModel().propertyEvents[1].label, "End")
            test.assertEqual(app:getViewModel().propertyEvents[2].label, "Set Input Enabled")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local trackY = EditorLayout.getTimelineTrackCenterY(timeline, 3, 10)
            app:mousepressed(originX + 5.1 * 32, trackY, 2)

            local event = app:getSession():getTimelineEvents()[1]
            test.assertEqual(event.type, "setInputEnabled")
            test.assertEqual(event.startBeat, 4)
            test.assertEqual(event.track, 3)
            test.assertEqual(event.enabled, false)

            local node = EditorLayout.getTimelineEventRect(timeline, event, {
                scale = 1,
                timelineStartBeat = 0,
                trackCount = 10,
            })
            app:mousepressed(node.x + node.width / 2, node.y + node.height / 2, 1)
            app:mousemoved(originX + 11.9 * 32,
                EditorLayout.getTimelineTrackCenterY(timeline, 5, 10))
            app:mousereleased(0, 0, 1)

            event = app:getSession():getTimelineEvents()[1]
            test.assertEqual(event.startBeat, 8)
            test.assertEqual(event.track, 5)
        end,
    },
    {
        name = "Set Input Enabled 노드 더블클릭 모달은 노드별 Enabled를 수정한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "input-event-property")
            local event = assert(app:getSession():addTimelineEvent(
                "setInputEnabled",
                4,
                1
            ))
            local node = EditorLayout.getTimelineEventRect(app.layout.timeline, event, {
                scale = 1,
                timelineStartBeat = 0,
                trackCount = 10,
            })

            app:mousepressed(node.x + 2, node.y + 2, 1, false, 2)
            test.assertEqual(app:getDialog():getKind(), "timelineEventProperties")
            test.assertEqual(app:getDialog():getSelection("enabled"), "false")
            assert(app:getDialog():select("enabled", "true"))
            app:getDialog():submit("confirm")
            app:update(0)

            test.assertEqual(app:getSession():getTimelineEvents()[1].enabled, true)
        end,
    },
    {
        name = "Project Event 우클릭 배치는 현재 Response Delay 기본값으로 충돌 검사한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local project = require("projects.sample.project")
            local app = newFixture({ project = project })
            createStageThroughDialog(app, "project-event-current-default")
            app.selectedCategoryId = "sampleGameplay"
            app.selectedEventId = "cueResponse"
            app.eventDefaults["project:sampleGameplay:cueResponse"] = {
                responseDelayBeats = 8,
            }

            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            local trackY = EditorLayout.getTimelineTrackCenterY(timeline, 1, 10)
            for beat = 0, 4 do
                app:mousepressed(originX + beat * 32 + 1, trackY, 2)
            end

            local events = app:getSession():getTimelineEvents()
            test.assertEqual(#events, 5)
            for _, event in ipairs(events) do
                test.assertEqual(event.params.responseDelayBeats, 8)
            end
        end,
    },
    {
        name = "Project mixtapeProperties는 전역 Auto 버튼을 표시하지 않는다",
        run = function(test)
            local app = newFixture({ project = createGlobalIdCollisionProject() })
            createStageThroughDialog(app, "project-mixtape-controls")
            app.selectedCategoryId = "collision"
            app.selectedEventId = "mixtapeProperties"

            local properties = app:getViewModel().properties
            test.assertEqual(properties[3].actionButton, nil)
        end,
    },
    {
        name = "Project editorProperties는 전역 Auto Play ComboBox를 표시하지 않는다",
        run = function(test)
            local app = newFixture({ project = createGlobalIdCollisionProject() })
            createStageThroughDialog(app, "project-editor-controls")
            app.selectedCategoryId = "collision"
            app.selectedEventId = "editorProperties"

            local properties = app:getViewModel().properties
            test.assertEqual(properties[1].comboBox, nil)
        end,
    },
    {
        name = "Project mixtapeProperties의 같은 값 클릭은 편집을 유지한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture({ project = createGlobalIdCollisionProject() })
            createStageThroughDialog(app, "project-mixtape-edit")
            app.selectedCategoryId = "collision"
            app.selectedEventId = "mixtapeProperties"
            app:getViewModel()
            app:beginValueEdit(
                "project:collision:mixtapeProperties",
                "beat0Offset"
            )
            local actionRect = EditorLayout.getPropertyActionRect(app.layout, 3)

            app:mousepressed(
                actionRect.x + actionRect.width / 2,
                actionRect.y + actionRect.height / 2,
                1
            )

            test.assertTrue(app:getViewModel().valueEdit ~= nil)
        end,
    },
    {
        name = "Project mixtapeProperties 클릭은 전역 음악 분석을 실행하지 않는다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local detectCount = 0
            local app = newFixture({
                project = createGlobalIdCollisionProject(),
                musicOnsetDetector = {
                    detect = function()
                        detectCount = detectCount + 1
                        return 0.25, nil
                    end,
                },
            })
            createStageThroughDialog(app, "project-mixtape-action")
            assert(app:getSession():setProperty(
                "mixtapeProperties",
                "music",
                "assets/audio/a.ogg"
            ))
            app.selectedCategoryId = "collision"
            app.selectedEventId = "mixtapeProperties"
            app:getViewModel()
            local actionRect = EditorLayout.getPropertyActionRect(app.layout, 3)

            app:mousepressed(
                actionRect.x + actionRect.width / 2,
                actionRect.y + actionRect.height / 2,
                1
            )

            test.assertEqual(detectCount, 0)
            test.assertTrue(app:getViewModel().valueEdit ~= nil)
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
            test.assertEqual(app:getViewModel().anchorBeat, 0)
            test.assertEqual(app:getViewModel().playbackBeat, nil)

            app:executeAction("play")
            test.assertNear(app:getViewModel().beat, 0, 0.000001)
            test.assertEqual(app:getViewModel().playbackBeat, 0)
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
        name = "End가 없는 Stage는 Music duration에서 종료하고 toast를 표시한다",
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

            test.assertEqual(app:getViewModel().playing, false)
            test.assertEqual(#app:getViewModel().toasts, 1)
            test.assertContains(app:getViewModel().toasts[1].message, "Music ended")

            app:update(0.25)
            test.assertNear(app:getViewModel().beat, beatAfterDuration, 0.000001)
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
        name = "Timeline 숫자 영역 클릭과 drag는 Snap 간격으로 playhead를 옮긴다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "timeline-drag")
            assert(app:getSession():setProperty("editorProperties", "snap", 4))
            app:executeAction("save")
            test.assertEqual(
                app:getSession():getDocument():toTable().editorSettings.snap,
                4
            )
            local timeline = app.layout.timeline
            local pixelsPerBeat = EditorLayout.getPixelsPerBeat(1)
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)

            app:mousepressed(originX + 5.9 * pixelsPerBeat, timeline.y + 16, 1)
            test.assertNear(app:getViewModel().beat, 4, 0.000001)
            test.assertEqual(app.timelineDrag, "playhead")

            app:mousemoved(originX + 6 * pixelsPerBeat, timeline.y + 16)
            test.assertNear(app:getViewModel().beat, 8, 0.000001)
            app:mousereleased(originX + 6 * pixelsPerBeat, timeline.y + 16, 1)
            app:mousemoved(originX + 2 * pixelsPerBeat, timeline.y + 16)
            test.assertNear(app:getViewModel().beat, 8, 0.000001)

            app:mousepressed(originX + pixelsPerBeat, timeline.y + 40, 1)
            test.assertNear(app:getViewModel().beat, 8, 0.000001)

            app:mousepressed(timeline.x + 200, timeline.y + 80, 3)
            app:mousemoved(timeline.x + 136, timeline.y + 80, -64, 0)
            test.assertNear(app:getSession():getTimelineStartBeat(), 2, 0.000001)
            app:mousereleased(timeline.x + 136, timeline.y + 80, 3)
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "Playhead edge scroll은 양방향으로 움직이고 마우스와의 거리에 따라 빨라진다",
        run = function(test)
            local leftApp = newFixture()
            createStageThroughDialog(leftApp, "timeline-edge-left")
            leftApp:getSession().timelineStartBeat = 10
            local leftTimeline = leftApp.layout.timeline
            leftApp:mousepressed(leftTimeline.x + 1, leftTimeline.y + 16, 1)
            leftApp:update(0.25)
            test.assertTrue(leftApp:getSession():getTimelineStartBeat() < 10)

            local function rightScroll(extraDistance)
                local app = newFixture()
                createStageThroughDialog(app, "timeline-edge-right")
                app:getSession().timelineStartBeat = 10
                local timeline = app.layout.timeline
                local edgeX = timeline.x + timeline.width - 1
                app:mousepressed(edgeX, timeline.y + 16, 1)
                app:mousemoved(edgeX + extraDistance, timeline.y + 16)
                local before = app:getSession():getTimelineStartBeat()
                app:update(0.25)
                return app:getSession():getTimelineStartBeat() - before
            end

            local closeDelta = rightScroll(0)
            local farDelta = rightScroll(320)
            test.assertTrue(closeDelta > 0)
            test.assertTrue(farDelta > closeDelta)
        end,
    },
    {
        name = "F는 Play Pause를 전환하고 R은 beat 0, Ctrl S는 Stage를 저장한다",
        run = function(test)
            local controlDown = false
            local app = newFixture({
                isControlDown = function() return controlDown end,
            })
            createStageThroughDialog(app, "timeline-shortcuts")
            assert(app:getSession():seekTimeline(4))

            app:keypressed("f")
            test.assertEqual(app:getSession():isPlaying(), true)
            app:keypressed("f", nil, true)
            test.assertEqual(app:getSession():isPlaying(), true)
            app:keypressed("f")
            test.assertEqual(app:getSession():isPlaying(), false)

            assert(app:getSession():seekTimeline(4))
            app:getSession().timelineStartBeat = 10
            app:keypressed("f")
            app:keypressed("r")
            test.assertEqual(app:getSession():isPlaying(), false)
            test.assertEqual(app:getViewModel().beat, 0)
            test.assertEqual(app:getSession():getTimelineStartBeat(), 0)

            test.assertEqual(app:getSession():isDirty(), true)
            controlDown = true
            app:keypressed("s")
            test.assertEqual(app:getSession():isDirty(), false)
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
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            app.layout = EditorLayout.getLayout(1200, 800)
            createStageThroughDialog(app, "scaled-auto-follow")
            assert(app:getSession():setProperty("editorProperties", "scale", 2))
            assert(app:executeAction("play"))

            app:update(10)

            test.assertNear(app:getSession():getBeat(), 20, 0.000001)
            test.assertNear(
                app:getSession():getTimelineStartBeat(),
                7,
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
            local playheadX = EditorLayout.getTimelineBeatOriginX(
                app.layout.timeline,
                viewModel.scale
            ) + (viewModel.beat - viewModel.timelineStartBeat) * pixelsPerBeat
            test.assertEqual(
                EditorLayout.getVisibleBeatCount(app.layout, viewModel.scale),
                2
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

            local scaleRect = EditorLayout.getPropertyValueRect(app.layout, 2)
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
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 5)
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
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 5)
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
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 5)
            app:mousepressed(bpmRect.x + 12, bpmRect.y + 12, 1)
            clearValueEdit(app)
            app:textinput("90")
            app:mousepressed(app.layout.panels[2].x + 12, 100, 1)

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():getBpm(), 90)
        end,
    },
    {
        name = "Timeline 클릭은 active Value를 확정한 뒤 Timeline 동작도 계속 처리한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local app = newFixture()
            createStageThroughDialog(app, "blur-inline-bpm-timeline")

            local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
            app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
            local bpmRect = EditorLayout.getPropertyValueRect(app.layout, 5)
            app:mousepressed(bpmRect.x + 12, bpmRect.y + 12, 1)
            clearValueEdit(app)
            app:textinput("90")

            local timeline = app.layout.timeline
            local originX = EditorLayout.getTimelineBeatOriginX(timeline, 1)
            app:mousepressed(originX + 2 * 32, timeline.y + 40, 1)

            test.assertEqual(app:getViewModel().valueEdit, nil)
            test.assertEqual(app:getSession():getBpm(), 90)
            test.assertEqual(app.timelineDrag.kind, "selection")
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
