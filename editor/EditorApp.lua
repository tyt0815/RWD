local EditorSession = require("editor.EditorSession")
local EditorDialog = require("editor.ui.EditorDialog")
local EditorLayout = require("editor.ui.EditorLayout")
local EditorMenu = require("editor.menu.EditorMenu")
local MusicCatalog = require("editor.project.MusicCatalog")
local ProjectCatalog = require("editor.project.ProjectCatalog")
local PropertyCatalog = require("editor.properties.PropertyCatalog")
local StageStore = require("editor.stage.StageStore")
local TestPlayer = require("editor.playback.TestPlayer")

local EditorApp = {}
EditorApp.__index = EditorApp

function EditorApp.new(options)
    options = options or {}
    local projectCatalog = options.projectCatalog or ProjectCatalog.new({
        createGame = options.createGame,
    })
    local musicCatalog = options.musicCatalog or MusicCatalog.new()
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
        musicCatalog = musicCatalog,
        onQuit = options.onQuit or function() end,
        dialog = nil,
        selectedEventId = "editorProperties",
        valueEdit = nil,
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
    local properties = {}
    local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
    if selectedEvent then
        for _, property in ipairs(selectedEvent.properties) do
            local value
            if self.session:hasStage() then
                value = self.session:getProperty(selectedEvent.id, property.id)
            end
            table.insert(properties, {
                id = property.id,
                label = property.label,
                kind = property.kind,
                value = value,
            })
        end
    end

    return {
        hasStage = self.session:hasStage(),
        playing = self.session:isPlaying(),
        dirty = self.session:isDirty(),
        propertyEvents = PropertyCatalog.getEvents(),
        selectedEventId = self.selectedEventId,
        properties = properties,
        valueEdit = self.valueEdit,
        beat = self.session:getBeat(),
        timelineStartBeat = self.session:getTimelineStartBeat(),
        menuItems = EditorMenu.getItems(self.session),
        hoveredAction = self.hoveredAction,
    }
end

function EditorApp:showError(message)
    self.dialog = EditorDialog.error(message)
end

function EditorApp:beginValueEdit(groupId, propertyId)
    self.valueEdit = {
        groupId = groupId,
        propertyId = propertyId,
        text = tostring(self.session:getProperty(groupId, propertyId)),
        replaceOnInput = true,
        invalid = false,
    }
end

function EditorApp:commitValueEdit()
    if not self.valueEdit then return true end

    local changed, errorMessage = self.session:setProperty(
        self.valueEdit.groupId,
        self.valueEdit.propertyId,
        tonumber(self.valueEdit.text)
    )
    if not changed then
        self.valueEdit.invalid = true
        return nil, errorMessage
    end

    self.valueEdit = nil
    return true, nil
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

function EditorApp:openMusicDialog()
    local project = self.session:getProject()
    local files, errorMessage = self.musicCatalog:list(project.id)
    if not files then
        self:showError(errorMessage)
        return
    end

    local currentMusic = self.session:getProperty("mixtapeProperties", "music")
    self.dialog = EditorDialog.music(files, currentMusic)
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
        if self.valueEdit then
            local committed, commitError = self:commitValueEdit()
            if not committed then return nil, commitError end
        end
        local started, errorMessage = self.session:play()
        if not started then self:showError(errorMessage) end
        return started, errorMessage
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
    elseif kind == "music" and result.buttonId == "confirm" then
        local value = result.selections.music
        if value == "" then value = nil end
        local changed, errorMessage = self.session:setProperty(
            "mixtapeProperties",
            "music",
            value
        )
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
    local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
    local propertyCount = selectedEvent and #selectedEvent.properties or 0
    local propertyRow = EditorLayout.hitTestPropertyValue(
        self.layout,
        propertyCount,
        x,
        y
    )
    if self.valueEdit then
        local clickedProperty = propertyRow and selectedEvent.properties[propertyRow] or nil
        if clickedProperty
            and self.valueEdit.groupId == selectedEvent.id
            and self.valueEdit.propertyId == clickedProperty.id then
            return true
        end
        local committed = self:commitValueEdit()
        if not committed then return true end
    end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    if item and item.enabled then
        self:executeAction(item.action)
        return true
    end

    if self.session:hasStage() then
        local propertyEvents = PropertyCatalog.getEvents()
        local eventRow = EditorLayout.hitTestEvent(self.layout, #propertyEvents, x, y)
        if eventRow then
            self.selectedEventId = propertyEvents[eventRow].id
            return true
        end
    end

    if self.session:hasStage() and not self.session:isPlaying() and propertyRow then
        local property = selectedEvent.properties[propertyRow]
        if property.kind == "number" then
            self:beginValueEdit(selectedEvent.id, property.id)
        elseif property.kind == "boolean" then
            local currentValue = self.session:getProperty(selectedEvent.id, property.id)
            local changed, errorMessage = self.session:setProperty(
                selectedEvent.id,
                property.id,
                not currentValue
            )
            if not changed then self:showError(errorMessage) end
        elseif property.kind == "music" then
            self:openMusicDialog()
        end
        return true
    end
    return true
end

function EditorApp:textinput(text)
    if self.dialog then
        self.dialog:textinput(text)
    elseif self.valueEdit and not self.session:isPlaying() then
        local numericText = text:gsub("[^%d%.%-]", "")
        if numericText ~= "" then
            if self.valueEdit.replaceOnInput then
                self.valueEdit.text = numericText
            else
                self.valueEdit.text = self.valueEdit.text .. numericText
            end
            self.valueEdit.replaceOnInput = false
            self.valueEdit.invalid = false
        end
    end
    return true
end

function EditorApp:keypressed(key)
    if self.dialog then
        self.dialog:keypressed(key)
    elseif self.valueEdit and not self.session:isPlaying() then
        if key == "backspace" then
            self.valueEdit.text = self.valueEdit.text:sub(1, -2)
            self.valueEdit.replaceOnInput = false
            self.valueEdit.invalid = false
        elseif key == "return" or key == "kpenter" then
            self:commitValueEdit()
        elseif key == "escape" then
            self.valueEdit = nil
        end
    end
    return true
end

return EditorApp
