local function newFixture(config)
    config = config or {}
    local state = { saved = {}, quitCount = 0, previewPlaying = false }
    local project = { id = "sample", title = "Sample", entryModule = "sample.game" }
    local catalog = {
        listProjects = function() return { project }, nil end,
        getProject = function(_, projectId)
            if projectId == "sample" then return project, nil end
            return nil, "missing project"
        end,
        createGame = function() return {}, nil end,
    }
    local store = {
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
    local EditorApp = require("editor.EditorApp")
    local app = EditorApp.new({
        projectCatalog = catalog,
        stageStore = store,
        testPlayer = testPlayer,
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

return {
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
        name = "Play and Pause change TestPlayer preview state",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "preview")
            app:executeAction("play")
            test.assertEqual(app:getViewModel().playing, true)
            test.assertEqual(state.previewPlaying, true)
            app:executeAction("pause")
            test.assertEqual(app:getViewModel().playing, false)
            test.assertEqual(state.previewPlaying, false)
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
