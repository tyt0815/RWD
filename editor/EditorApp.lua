local EditorSession = require("editor.EditorSession")
local EditorDialog = require("editor.ui.EditorDialog")
local EditorLayout = require("editor.ui.EditorLayout")
local EditorMenu = require("editor.menu.EditorMenu")
local ProjectCatalog = require("editor.project.ProjectCatalog")
local StageStore = require("editor.stage.StageStore")
local TestPlayer = require("editor.playback.TestPlayer")

local EditorApp = {}
EditorApp.__index = EditorApp

function EditorApp.new(options)
    options = options or {}
    local projectCatalog = options.projectCatalog or ProjectCatalog.new({
        createGame = options.createGame,
    })
    local stageStore = options.stageStore or StageStore.new()
    local testPlayer = options.testPlayer or TestPlayer.new({
        createGame = function(project)
            return projectCatalog:createGame(project)
        end,
    })
    local session = options.session or EditorSession.new({
        projectCatalog = projectCatalog,
        stageStore = stageStore,
        testPlayer = testPlayer,
    })

    return setmetatable({
        session = session,
        onQuit = options.onQuit or function() end,
        dialog = nil,
        hoveredAction = nil,
        layout = EditorLayout.getLayout(1200, 800),
    }, EditorApp)
end

function EditorApp:getSession()
    return self.session
end

function EditorApp:getDialog()
    return self.dialog
end

function EditorApp:getViewModel()
    return {
        hasStage = self.session:hasStage(),
        playing = self.session:isPlaying(),
        dirty = self.session:isDirty(),
        bpm = self.session:getBpm(),
        beat = self.session:getBeat(),
        timelineStartBeat = self.session:getTimelineStartBeat(),
        menuItems = EditorMenu.getItems(self.session),
        hoveredAction = self.hoveredAction,
    }
end

function EditorApp:showError(message)
    self.dialog = EditorDialog.error(message)
end

function EditorApp:openNewDialog()
    local projects, errorMessage = self.session:listProjects()
    if not projects or #projects == 0 then
        self:showError(errorMessage or "No compatible Projects found.")
        return
    end
    self.dialog = EditorDialog.newStage(projects)
end

function EditorApp:openOpenDialog()
    local projects, errorMessage = self.session:listProjects()
    if not projects or #projects == 0 then
        self:showError(errorMessage or "No compatible Projects found.")
        return
    end
    local stageIds, stageError = self.session:listStages(projects[1].id)
    if not stageIds then
        self:showError(stageError)
        return
    end
    self.dialog = EditorDialog.openStage(projects, stageIds)
end

function EditorApp:continueAction(action)
    if action == "new" then
        self:openNewDialog()
    elseif action == "open" then
        self:openOpenDialog()
    elseif action == "quit" then
        self.session:pause()
        self.onQuit()
    end
end

function EditorApp:requestGuarded(action)
    if self.session:isDirty() then
        self.dialog = EditorDialog.unsaved(action)
    else
        self:continueAction(action)
    end
end

function EditorApp:executeAction(action)
    if action == "new" or action == "open" or action == "quit" then
        self:requestGuarded(action)
    elseif action == "save" then
        local saved, errorMessage = self.session:save()
        if not saved then self:showError(errorMessage) end
    elseif action == "saveAs" then
        local document = self.session:getDocument()
        self.dialog = EditorDialog.saveAs(document:getStageId(), document:getName())
    elseif action == "play" then
        local started, errorMessage = self.session:play()
        if not started then self:showError(errorMessage) end
    elseif action == "pause" then
        self.session:pause()
    end
end

function EditorApp:processDialogResult()
    if not self.dialog then return end
    local result = self.dialog:consumeResult()
    if not result then return end
    local kind = self.dialog:getKind()
    if result.buttonId == "cancel" or result.buttonId == "ok" then
        self.dialog = nil
        return
    end

    if kind == "newStage" and result.buttonId == "confirm" then
        local created, errorMessage = self.session:createStage(
            result.selections.projectId,
            result.values.stageId,
            result.values.name,
            tonumber(result.values.bpm)
        )
        self.dialog = nil
        if not created then self:showError(errorMessage) end
    elseif kind == "openStage" and result.buttonId == "confirm" then
        local opened, errorMessage = self.session:openStage(
            result.selections.projectId,
            result.selections.stageId
        )
        self.dialog = nil
        if not opened then self:showError(errorMessage) end
    elseif kind == "saveAs" and result.buttonId == "confirm" then
        local saved, errorMessage, errorCode = self.session:saveAs(
            result.values.stageId,
            result.values.name,
            false
        )
        self.dialog = nil
        if not saved and errorCode == "STAGE_EXISTS" then
            self.dialog = EditorDialog.overwrite({
                stageId = result.values.stageId,
                name = result.values.name,
            })
        elseif not saved then
            self:showError(errorMessage)
        end
    elseif kind == "overwrite" and result.buttonId == "confirm" then
        local saved, errorMessage = self.session:saveAs(
            result.context.stageId,
            result.context.name,
            true
        )
        self.dialog = nil
        if not saved then self:showError(errorMessage) end
    elseif kind == "editBpm" and result.buttonId == "confirm" then
        local changed, errorMessage = self.session:setBpm(tonumber(result.values.bpm))
        self.dialog = nil
        if not changed then self:showError(errorMessage) end
    elseif kind == "unsaved" then
        local pendingAction = result.context.pendingAction
        if result.buttonId == "discard" then
            self.dialog = nil
            self:continueAction(pendingAction)
        elseif result.buttonId == "save" then
            local saved, errorMessage = self.session:save()
            self.dialog = nil
            if saved then
                self:continueAction(pendingAction)
            else
                self:showError(errorMessage)
            end
        end
    elseif kind == "error" then
        self.dialog = nil
    end
end

function EditorApp:update(deltaTime)
    self:processDialogResult()
    if self.dialog then return end
    local visibleBeatCount = EditorLayout.getVisibleBeatCount(self.layout)
    local updated, errorMessage = self.session:update(deltaTime, visibleBeatCount)
    if not updated then self:showError(errorMessage) end
end

function EditorApp:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    local previewError
    self.layout = EditorLayout.draw(width, height, self:getViewModel(), function(rect)
        local drawn, errorMessage = self.session:drawPreview(rect)
        if not drawn then previewError = errorMessage end
    end)
    if previewError and not self.dialog then self:showError(previewError) end
    if self.dialog then self.dialog:draw(width, height) end
end

function EditorApp:mousemoved(x, y)
    if self.dialog then return true end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    self.hoveredAction = item and item.enabled and item.action or nil
    return true
end

function EditorApp:mousepressed(x, y, button)
    if button ~= 1 then return true end
    if self.dialog then
        local previousProject = self.dialog:getSelection("projectId")
        self.dialog:mousepressed(x, y)
        local currentProject = self.dialog:getSelection("projectId")
        if self.dialog:getKind() == "openStage" and currentProject ~= previousProject then
            local stageIds, errorMessage = self.session:listStages(currentProject)
            if stageIds then
                local options = {}
                for _, stageId in ipairs(stageIds) do
                    table.insert(options, { value = stageId, label = stageId })
                end
                self.dialog:setSelectorOptions("stageId", options)
            else
                self:showError(errorMessage)
            end
        end
        return true
    end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    if item and item.enabled then
        self:executeAction(item.action)
        return true
    end
    if self.session:hasStage() and not self.session:isPlaying()
        and EditorLayout.hitTestBpmValue(self.layout, x, y) then
        self.dialog = EditorDialog.editBpm(self.session:getBpm())
    end
    return true
end

function EditorApp:textinput(text)
    if self.dialog then self.dialog:textinput(text) end
    return true
end

function EditorApp:keypressed(key)
    if self.dialog then self.dialog:keypressed(key) end
    return true
end

return EditorApp
