local EditorSession = require("editor.EditorSession")
local EditorDialog = require("editor.ui.EditorDialog")
local EditorLayout = require("editor.ui.EditorLayout")
local EditorMenu = require("editor.menu.EditorMenu")
local MusicCatalog = require("editor.project.MusicCatalog")
local MusicOnsetDetector = require("editor.project.MusicOnsetDetector")
local ProjectCatalog = require("editor.project.ProjectCatalog")
local PropertyCatalog = require("editor.properties.PropertyCatalog")
local TimelineEventGeometry = require("editor.timeline.TimelineEventGeometry")
local TimelineSnap = require("editor.timeline.TimelineSnap")
local StageStore = require("editor.stage.StageStore")
local TestPlayer = require("editor.playback.TestPlayer")
local Core = require("core")
local TextInput = Core.UI.TextInput
local Button = Core.UI.Button
local ScrollArea = Core.UI.ScrollArea

local EditorApp = {}
EditorApp.__index = EditorApp

local TIMELINE_EDGE_SCROLL_THRESHOLD = 32
local TIMELINE_EDGE_SCROLL_BASE_BEATS_PER_SECOND = 8
local TIMELINE_EDGE_SCROLL_ACCELERATION = 8
local TIMELINE_EDGE_SCROLL_MAX_BEATS_PER_SECOND = 64

local function getCategories()
    return PropertyCatalog.getCategories()
end

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
        musicOnsetDetector = options.musicOnsetDetector or MusicOnsetDetector.new(),
        onQuit = options.onQuit or function() end,
        isControlDown = options.isControlDown or function()
            return love.keyboard.isDown("lctrl", "rctrl")
        end,
        dialog = nil,
        selectedCategoryId = "global",
        selectedEventId = "editorProperties",
        selectedTimelineEventIds = {},
        hoveredTimelineEventId = nil,
        eventDefaults = {
            setInputEnabled = { enabled = false },
        },
        valueEdit = nil,
        hoveredAction = nil,
        beat0AutoButton = Button.new({
            id = "detectBeat0Offset",
            label = "Auto",
            enabled = false,
        }),
        timelineDrag = nil,
        scrollAreas = {
            categories = ScrollArea.new({ step = EditorLayout.getRowHeight() }),
            events = ScrollArea.new({ step = EditorLayout.getRowHeight() }),
            properties = ScrollArea.new({ step = EditorLayout.getRowHeight() }),
        },
        layout = EditorLayout.getLayout(1920, 1080),
    }, EditorApp)
end

function EditorApp:getSession()
    return self.session
end

function EditorApp:getDialog()
    return self.dialog
end

function EditorApp:updateBeat0AutoButton()
    local music
    if self.session:hasStage() then
        music = self.session:getProperty("mixtapeProperties", "music")
    end
    self.beat0AutoButton:setEnabled(
        music ~= nil and not self.session:isPlaying()
    )
end

function EditorApp:updatePanelScrollAreas()
    local viewportHeight = EditorLayout.getPanelContentRect(
        self.layout.panels[2]
    ).height
    local categoryCount = self.session:hasStage()
        and #PropertyCatalog.getCategories() or 0
    local eventCount = self.session:hasStage()
        and #PropertyCatalog.getEvents(self.selectedCategoryId) or 0
    local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
    local propertyCount = self.session:hasStage() and selectedEvent
        and #selectedEvent.properties or 0

    self.scrollAreas.categories:setDimensions(
        EditorLayout.getRowContentHeight(categoryCount),
        viewportHeight
    )
    self.scrollAreas.events:setDimensions(
        EditorLayout.getRowContentHeight(eventCount),
        viewportHeight
    )
    self.scrollAreas.properties:setDimensions(
        EditorLayout.getRowContentHeight(propertyCount),
        viewportHeight
    )
end

function EditorApp:getViewModel()
    self:updatePanelScrollAreas()
    local properties = {}
    local scale = 1
    local metronomePeriod = 4
    local trackCount = 10
    if self.session:hasStage() then
        scale = self.session:getProperty("editorProperties", "scale")
        metronomePeriod = self.session:getProperty(
            "editorProperties",
            "metronomePeriod"
        )
        trackCount = self.session:getProperty("editorProperties", "trackCount")
    end
    local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
    self:updateBeat0AutoButton()
    if selectedEvent then
        for _, property in ipairs(selectedEvent.properties) do
            local groupId = property.groupId or selectedEvent.id
            local value
            if selectedEvent.timelineType then
                local defaults = self.eventDefaults[selectedEvent.timelineType]
                if defaults then value = defaults[property.id] end
            elseif self.session:hasStage() then
                value = self.session:getProperty(groupId, property.id)
            end
            local viewProperty = {
                id = property.id,
                label = property.label,
                kind = property.kind,
                groupId = groupId,
                value = value,
            }
            if selectedEvent.id == "mixtapeProperties"
                and property.id == "beat0Offset" then
                viewProperty.actionButton = self.beat0AutoButton
            end
            table.insert(properties, viewProperty)
        end
    end

    local timelineEvents = self.session:getTimelineEvents()
    local draggingTimelineEventIds = {}
    local collisionTimelineEventIds = {}
    local timelineSelectionBox
    if type(self.timelineDrag) == "table" then
        if self.timelineDrag.kind == "events" then
            draggingTimelineEventIds = self.selectedTimelineEventIds
            collisionTimelineEventIds = self.timelineDrag.collisionIds or {}
            for _, event in ipairs(timelineEvents) do
                local position = self.timelineDrag.positions
                    and self.timelineDrag.positions[event.id]
                if position then
                    event.startBeat = position.startBeat
                    event.track = position.track
                end
            end
        elseif self.timelineDrag.kind == "selection" then
            local startX = self.timelineDrag.startX
            local startY = self.timelineDrag.startY
            local currentX = self.timelineDrag.currentX
            local currentY = self.timelineDrag.currentY
            timelineSelectionBox = {
                x = math.min(startX, currentX),
                y = math.min(startY, currentY),
                width = math.abs(currentX - startX),
                height = math.abs(currentY - startY),
            }
        end
    end
    for _, event in ipairs(timelineEvents) do
        local definition = PropertyCatalog.getTimelineEvent(event.type)
        event.label = definition and definition.label or event.type
        event.color = definition and definition.color or nil
    end

    return {
        hasStage = self.session:hasStage(),
        playing = self.session:isPlaying(),
        dirty = self.session:isDirty(),
        categories = self.session:hasStage() and getCategories() or {},
        selectedCategoryId = self.selectedCategoryId,
        propertyEvents = PropertyCatalog.getEvents(self.selectedCategoryId),
        selectedEventId = self.selectedEventId,
        properties = properties,
        valueEdit = self.valueEdit,
        dialog = self.dialog,
        beat = self.session:getBeat(),
        anchorBeat = self.session:getAnchorBeat(),
        playbackBeat = self.session:isPlaying() and self.session:getBeat() or nil,
        timelineStartBeat = self.session:getTimelineStartBeat(),
        scale = scale,
        metronomePeriod = metronomePeriod,
        trackCount = trackCount,
        timelineEvents = timelineEvents,
        selectedTimelineEventIds = self.selectedTimelineEventIds,
        draggingTimelineEventIds = draggingTimelineEventIds,
        collisionTimelineEventIds = collisionTimelineEventIds,
        timelineSelectionBox = timelineSelectionBox,
        hoveredTimelineEventId = self.hoveredTimelineEventId,
        menuItems = EditorMenu.getItems(self.session),
        hoveredAction = self.hoveredAction,
        scrollAreas = self.scrollAreas,
    }
end

function EditorApp:autoDetectBeat0Offset()
    local project = self.session:getProject()
    local music = self.session:getProperty("mixtapeProperties", "music")
    if not project or not music then
        return nil, "Select Music before detecting its first sound."
    end

    local threshold = self.session:getProperty(
        "editorProperties",
        "onsetThreshold"
    )
    local onset, errorMessage = self.musicOnsetDetector:detect(
        project.id,
        music,
        threshold
    )
    if onset == nil then return nil, errorMessage end
    return self.session:setProperty(
        "mixtapeProperties",
        "beat0Offset",
        onset
    )
end

function EditorApp:showError(message)
    self.dialog = EditorDialog.error(message)
end

function EditorApp:beginValueEdit(groupId, propertyId)
    local text = tostring(self.session:getProperty(groupId, propertyId))
    self.valueEdit = TextInput.new(text, {
        filter = function(input)
            return input:gsub("[^%d%.%-]", "")
        end,
    })
    self.valueEdit.groupId = groupId
    self.valueEdit.propertyId = propertyId
    self.valueEdit.invalid = false
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

    if kind == "timelineEventProperties" and result.buttonId == "confirm" then
        local changed, errorMessage = self.session:setTimelineEventProperty(
            result.context.eventId,
            "enabled",
            result.selections.enabled == "true"
        )
        self.dialog = nil
        if not changed then self:showError(errorMessage) end
    elseif kind == "newStage" and result.buttonId == "confirm" then
        local created, errorMessage = self.session:createStage(
            result.selections.projectId,
            result.values.stageId,
            result.values.name,
            tonumber(result.values.bpm)
        )
        self.dialog = nil
        if created then self.selectedTimelineEventIds = {} end
        if not created then self:showError(errorMessage) end
    elseif kind == "openStage" and result.buttonId == "confirm" then
        local opened, errorMessage = self.session:openStage(
            result.selections.projectId,
            result.selections.stageId
        )
        self.dialog = nil
        if opened then self.selectedTimelineEventIds = {} end
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
        local shouldAutoDetect = value ~= nil
            and self.session:getProperty("mixtapeProperties", "beat0Offset") == 0
        local changed, errorMessage = self.session:setProperty(
            "mixtapeProperties",
            "music",
            value
        )
        self.dialog = nil
        if not changed then
            self:showError(errorMessage)
        elseif shouldAutoDetect then
            local detected, detectError = self:autoDetectBeat0Offset()
            if not detected then self:showError(detectError) end
        end
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

function EditorApp:seekTimelineAtX(x)
    local timeline = self.layout.timeline
    local scale = self.session:getProperty("editorProperties", "scale")
    local beatOriginX = EditorLayout.getTimelineBeatOriginX(timeline, scale)
    local contentWidth = math.max(
        0,
        timeline.x + timeline.width - beatOriginX
    )
    local offsetX = math.max(0, math.min(contentWidth, x - beatOriginX))
    local beat = self.session:getTimelineStartBeat()
        + offsetX / EditorLayout.getPixelsPerBeat(scale)
    local changed, errorMessage = self.session:seekTimeline(beat)
    if not changed then
        self.timelineDrag = nil
        self:showError(errorMessage)
        return nil, errorMessage
    end
    return true, nil
end

function EditorApp:getTimelinePosition(x, y)
    local timeline = self.layout.timeline
    local scale = self.session:getProperty("editorProperties", "scale")
    local trackCount = self.session:getProperty("editorProperties", "trackCount")
    local track = EditorLayout.getTimelineTrackAtY(timeline, y, trackCount)
    if not track then return nil, nil end
    local beat = self.session:getTimelineStartBeat()
        + (x - EditorLayout.getTimelineBeatOriginX(timeline, scale))
            / EditorLayout.getPixelsPerBeat(scale)
    return math.max(0, beat), track
end

function EditorApp:getTimelineEventAt(x, y)
    if not self.session:hasStage() then return nil end
    return EditorLayout.hitTestTimelineEvent(
        self.layout.timeline,
        self.session:getTimelineEvents(),
        {
            scale = self.session:getProperty("editorProperties", "scale"),
            timelineStartBeat = self.session:getTimelineStartBeat(),
            trackCount = self.session:getProperty("editorProperties", "trackCount"),
        },
        x,
        y
    )
end

local function rectanglesIntersect(first, second)
    return first.x < second.x + second.width
        and second.x < first.x + first.width
        and first.y < second.y + second.height
        and second.y < first.y + first.height
end

local function copySelection(selection)
    local copy = {}
    for eventId, selected in pairs(selection) do
        if selected then copy[eventId] = true end
    end
    return copy
end

function EditorApp:updateTimelineSelection(x, y)
    local drag = self.timelineDrag
    drag.currentX = x
    drag.currentY = y
    local selectionRect = {
        x = math.min(drag.startX, x),
        y = math.min(drag.startY, y),
        width = math.abs(x - drag.startX),
        height = math.abs(y - drag.startY),
    }
    local selected = copySelection(drag.baseSelection)
    local view = {
        scale = self.session:getProperty("editorProperties", "scale"),
        timelineStartBeat = self.session:getTimelineStartBeat(),
        trackCount = self.session:getProperty("editorProperties", "trackCount"),
    }
    for _, event in ipairs(self.session:getTimelineEvents()) do
        local eventRect = EditorLayout.getTimelineEventRect(
            self.layout.timeline,
            event,
            view
        )
        if rectanglesIntersect(selectionRect, eventRect) then
            selected[event.id] = true
        end
    end
    self.selectedTimelineEventIds = selected
end

function EditorApp:beginTimelineEventDrag(eventId)
    local origins = {}
    for _, event in ipairs(self.session:getTimelineEvents()) do
        if self.selectedTimelineEventIds[event.id] then
            origins[event.id] = {
                startBeat = event.startBeat,
                track = event.track,
            }
        end
    end
    self.timelineDrag = {
        kind = "events",
        anchorEventId = eventId,
        origins = origins,
        positions = origins,
        collisionIds = {},
    }
end

function EditorApp:updateTimelineEventDrag(x, y)
    local drag = self.timelineDrag
    drag.hasMoved = true
    local timeline = self.layout.timeline
    local scale = self.session:getProperty("editorProperties", "scale")
    local snap = self.session:getProperty("editorProperties", "snap")
    local trackCount = self.session:getProperty("editorProperties", "trackCount")
    local beat = self.session:getTimelineStartBeat()
        + (x - EditorLayout.getTimelineBeatOriginX(timeline, scale))
            / EditorLayout.getPixelsPerBeat(scale)
    beat = TimelineSnap.snapBeat(math.max(0, beat), snap)
    local track = EditorLayout.getTimelineTrackAtY(timeline, y, trackCount)
    if not track then
        track = y < timeline.y + 32 and 1 or trackCount
    end

    local anchor = drag.origins[drag.anchorEventId]
    local deltaBeat = beat - anchor.startBeat
    local deltaTrack = track - anchor.track
    local minimumBeat = math.huge
    local minimumTrack = math.huge
    local maximumTrack = -math.huge
    for _, origin in pairs(drag.origins) do
        minimumBeat = math.min(minimumBeat, origin.startBeat)
        minimumTrack = math.min(minimumTrack, origin.track)
        maximumTrack = math.max(maximumTrack, origin.track)
    end
    deltaBeat = math.max(deltaBeat, -minimumBeat)
    deltaTrack = math.max(1 - minimumTrack, math.min(
        trackCount - maximumTrack,
        deltaTrack
    ))

    local positions = {}
    local proposedEvents = self.session:getTimelineEvents()
    for eventId, origin in pairs(drag.origins) do
        positions[eventId] = {
            startBeat = origin.startBeat + deltaBeat,
            track = origin.track + deltaTrack,
        }
    end
    for _, event in ipairs(proposedEvents) do
        local position = positions[event.id]
        if position then
            event.startBeat = position.startBeat
            event.track = position.track
        end
    end
    drag.positions = positions
    drag.collisionIds = TimelineEventGeometry.findCollisionIds(
        proposedEvents,
        self.selectedTimelineEventIds
    )
end

function EditorApp:updateTimelineEdgeScroll(deltaTime)
    if self.timelineDrag ~= "playhead" or self.mouseX == nil then return true end

    local timeline = self.layout.timeline
    local direction = 0
    if self.mouseX <= timeline.x + TIMELINE_EDGE_SCROLL_THRESHOLD then
        direction = 1
    elseif self.mouseX >= timeline.x + timeline.width
        - TIMELINE_EDGE_SCROLL_THRESHOLD then
        direction = -1
    end
    if direction == 0 then return true end

    local scale = self.session:getProperty("editorProperties", "scale")
    local pixelsPerBeat = EditorLayout.getPixelsPerBeat(scale)
    local playheadX = EditorLayout.getTimelineBeatOriginX(timeline, scale)
        + (self.session:getBeat() - self.session:getTimelineStartBeat())
            * pixelsPerBeat
    local distanceBeats = math.abs(self.mouseX - playheadX) / pixelsPerBeat
    local speed = math.min(
        TIMELINE_EDGE_SCROLL_MAX_BEATS_PER_SECOND,
        TIMELINE_EDGE_SCROLL_BASE_BEATS_PER_SECOND
            + distanceBeats * TIMELINE_EDGE_SCROLL_ACCELERATION
    )
    local moved, errorMessage = self.session:panTimeline(
        direction * speed * pixelsPerBeat * deltaTime,
        pixelsPerBeat
    )
    if not moved then
        self.timelineDrag = nil
        self:showError(errorMessage)
        return nil, errorMessage
    end
    return self:seekTimelineAtX(self.mouseX)
end

function EditorApp:update(deltaTime)
    self:processDialogResult()
    if self.dialog then
        self.dialog:update(deltaTime)
        return
    end
    if not self:updateTimelineEdgeScroll(deltaTime) then return end
    if self.valueEdit and not self.session:isPlaying() then
        self.valueEdit:update(deltaTime)
    end
    local scale = self.session:hasStage()
        and self.session:getProperty("editorProperties", "scale")
        or 1
    local visibleBeatCount = EditorLayout.getVisibleBeatCount(self.layout, scale)
    local updated, errorMessage = self.session:update(deltaTime, visibleBeatCount)
    if not updated then self:showError(errorMessage) end
end

function EditorApp:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    self.layout = EditorLayout.getLayout(width, height)
    self:updatePanelScrollAreas()
    local previewError
    self.layout = EditorLayout.draw(width, height, self:getViewModel(), function(rect)
        local drawn, errorMessage = self.session:drawPreview(rect)
        if not drawn then previewError = errorMessage end
    end)
    if previewError and not self.dialog then self:showError(previewError) end
    if self.dialog then self.dialog:draw(width, height) end
end

function EditorApp:mousemoved(x, y, deltaX)
    local movementX = deltaX
    if movementX == nil then
        movementX = self.mouseX and x - self.mouseX or 0
    end
    self.mouseX = x
    self.mouseY = y
    if self.dialog then return true end

    if self.timelineDrag == "playhead" then
        self:seekTimelineAtX(x)
        return true
    elseif type(self.timelineDrag) == "table"
        and self.timelineDrag.kind == "events" then
        self:updateTimelineEventDrag(x, y)
        return true
    elseif type(self.timelineDrag) == "table"
        and self.timelineDrag.kind == "selection" then
        self:updateTimelineSelection(x, y)
        return true
    elseif self.timelineDrag == "pan" then
        local scale = self.session:getProperty("editorProperties", "scale")
        local changed, errorMessage = self.session:panTimeline(
            movementX,
            EditorLayout.getPixelsPerBeat(scale)
        )
        if not changed then
            self.timelineDrag = nil
            self:showError(errorMessage)
        end
        return true
    end

    self.hoveredTimelineEventId = nil
    if self.session:hasStage() then
        local hoveredEvent = self:getTimelineEventAt(x, y)
        self.hoveredTimelineEventId = hoveredEvent and hoveredEvent.id or nil
    end

    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    self.hoveredAction = item and item.enabled and item.action or nil
    return true
end

function EditorApp:wheelmoved(_, deltaY)
    if self.dialog or self.mouseX == nil or self.mouseY == nil then return true end

    local timeline = self.layout.timeline
    if self.mouseX >= timeline.x
        and self.mouseX < timeline.x + timeline.width
        and self.mouseY >= timeline.y
        and self.mouseY < timeline.y + timeline.height then
        local changed, errorMessage = self.session:zoomTimeline(
            self.mouseX - timeline.x,
            deltaY
        )
        if not changed then self:showError(errorMessage) end
        return true
    end

    self:updatePanelScrollAreas()
    for index, panel in ipairs(self.layout.panels) do
        if self.mouseX >= panel.x and self.mouseX < panel.x + panel.width
            and self.mouseY >= panel.y and self.mouseY < panel.y + panel.height then
            if index == 2 then
                self.scrollAreas.categories:scroll(deltaY)
            elseif index == 3 then
                self.scrollAreas.events:scroll(deltaY)
            elseif (index == 4 or index == 5) and not self.session:isPlaying() then
                self.scrollAreas.properties:scroll(deltaY)
            end
            break
        end
    end
    return true
end

function EditorApp:mousepressed(x, y, button, _, presses)
    if self.dialog then
        if button ~= 1 then return true end
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

    local timeline = self.layout.timeline
    local insideTimeline = x >= timeline.x
        and x < timeline.x + timeline.width
        and y >= timeline.y
        and y < timeline.y + timeline.height
    if button == 3 and self.session:hasStage() and insideTimeline then
        self.timelineDrag = "pan"
        return true
    end
    if button == 2 and self.session:hasStage()
        and not self.session:isPlaying() and insideTimeline then
        local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
        local beat, track = self:getTimelinePosition(x, y)
        if selectedEvent and selectedEvent.timelineType and beat and track then
            local added, errorMessage = self.session:addTimelineEvent(
                selectedEvent.timelineType,
                beat,
                track
            )
            if not added then
                self:showError(errorMessage)
            else
                local defaults = self.eventDefaults[selectedEvent.timelineType]
                if defaults then
                    for propertyId, value in pairs(defaults) do
                        local changed, propertyError =
                            self.session:setTimelineEventProperty(
                                added.id,
                                propertyId,
                                value
                            )
                        if not changed then
                            self:showError(propertyError)
                            break
                        end
                    end
                end
            end
        end
        return true
    end
    if button ~= 1 then return true end
    if self.session:hasStage() and not self.session:isPlaying() and insideTimeline then
        local timelineEvent = self:getTimelineEventAt(x, y)
        if timelineEvent then
            if self.isControlDown() then
                if self.selectedTimelineEventIds[timelineEvent.id] then
                    self.selectedTimelineEventIds[timelineEvent.id] = nil
                else
                    self.selectedTimelineEventIds[timelineEvent.id] = true
                end
                return true
            end
            if not self.selectedTimelineEventIds[timelineEvent.id] then
                self.selectedTimelineEventIds = { [timelineEvent.id] = true }
            end
            local definition = PropertyCatalog.getTimelineEvent(timelineEvent.type)
            if (presses or 1) >= 2 and definition
                and #definition.nodeProperties > 0 then
                self.dialog = EditorDialog.timelineEventProperties(
                    timelineEvent,
                    definition
                )
            else
                self:beginTimelineEventDrag(timelineEvent.id)
            end
            return true
        end
        if y >= timeline.y + 32 then
            local baseSelection = self.isControlDown()
                and copySelection(self.selectedTimelineEventIds)
                or {}
            self.selectedTimelineEventIds = copySelection(baseSelection)
            self.timelineDrag = {
                kind = "selection",
                startX = x,
                startY = y,
                currentX = x,
                currentY = y,
                baseSelection = baseSelection,
            }
            return true
        end
        self.selectedTimelineEventIds = {}
    end
    if self.session:hasStage()
        and not self.session:isPlaying()
        and EditorLayout.hitTestTimelineHeader(timeline, x, y) then
        self.mouseX = x
        self.mouseY = y
        self.timelineDrag = "playhead"
        self:seekTimelineAtX(x)
        return true
    end
    local selectedEvent = PropertyCatalog.getEvent(self.selectedEventId)
    local propertyCount = selectedEvent and #selectedEvent.properties or 0
    local propertyOffset = self.scrollAreas.properties:getOffset()
    local propertyRow = EditorLayout.hitTestPropertyValue(
        self.layout,
        propertyCount,
        x,
        y,
        propertyOffset
    )
    self:updateBeat0AutoButton()
    local actionClicked = false
    if self.selectedEventId == "mixtapeProperties" and button == 1 then
        local actionRect = EditorLayout.getPropertyActionRect(
            self.layout,
            3,
            propertyOffset
        )
        actionClicked = self.beat0AutoButton:contains(actionRect, x, y)
    end
    if self.valueEdit then
        local clickedProperty = propertyRow and selectedEvent.properties[propertyRow] or nil
        if not actionClicked
            and clickedProperty
            and self.valueEdit.groupId
                == (clickedProperty.groupId or selectedEvent.id)
            and self.valueEdit.propertyId == clickedProperty.id then
            return true
        end
        local committed = self:commitValueEdit()
        if not committed then return true end
    end
    if actionClicked then
        if self.beat0AutoButton.enabled then
            local detected, errorMessage = self:autoDetectBeat0Offset()
            if not detected then self:showError(errorMessage) end
        end
        return true
    end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    if item and item.enabled then
        self:executeAction(item.action)
        return true
    end

    if self.session:hasStage() then
        local categories = PropertyCatalog.getCategories()
        local categoryRow = EditorLayout.hitTestCategory(
            self.layout,
            #categories,
            x,
            y,
            self.scrollAreas.categories:getOffset()
        )
        if categoryRow then
            self.selectedCategoryId = categories[categoryRow].id
            local events = PropertyCatalog.getEvents(self.selectedCategoryId)
            self.selectedEventId = events[1] and events[1].id or nil
            self.scrollAreas.events:setOffset(0)
            self.scrollAreas.properties:setOffset(0)
            return true
        end

        local propertyEvents = PropertyCatalog.getEvents(self.selectedCategoryId)
        local eventRow = EditorLayout.hitTestEvent(
            self.layout,
            #propertyEvents,
            x,
            y,
            self.scrollAreas.events:getOffset()
        )
        if eventRow then
            self.selectedEventId = propertyEvents[eventRow].id
            self.scrollAreas.properties:setOffset(0)
            return true
        end
    end

    if self.session:hasStage() and not self.session:isPlaying() and propertyRow then
        local property = selectedEvent.properties[propertyRow]
        local groupId = property.groupId or selectedEvent.id
        if property.kind == "number" then
            self:beginValueEdit(groupId, property.id)
        elseif property.kind == "boolean" then
            if selectedEvent.timelineType then
                local defaults = self.eventDefaults[selectedEvent.timelineType]
                defaults[property.id] = not defaults[property.id]
            else
                local currentValue = self.session:getProperty(groupId, property.id)
                local changed, errorMessage = self.session:setProperty(
                    groupId,
                    property.id,
                    not currentValue
                )
                if not changed then self:showError(errorMessage) end
            end
        elseif property.kind == "music" then
            self:openMusicDialog()
        end
        return true
    end
    return true
end

function EditorApp:mousereleased(_, _, button)
    if button == 1 and self.timelineDrag == "playhead" then
        self.timelineDrag = nil
    elseif button == 1 and type(self.timelineDrag) == "table"
        and self.timelineDrag.kind == "selection" then
        self.timelineDrag = nil
    elseif button == 1 and type(self.timelineDrag) == "table"
        and self.timelineDrag.kind == "events" then
        local drag = self.timelineDrag
        self.timelineDrag = nil
        if drag.hasMoved and next(drag.collisionIds) == nil then
            local moved, errorMessage = self.session:moveTimelineEvents(
                drag.positions
            )
            if not moved then self:showError(errorMessage) end
        end
    elseif button == 3 and self.timelineDrag == "pan" then
        self.timelineDrag = nil
    end
    return true
end

function EditorApp:textinput(text)
    if self.dialog then
        self.dialog:textinput(text)
    elseif self.valueEdit and not self.session:isPlaying() then
        if self.valueEdit:textinput(text) then
            self.valueEdit.invalid = false
        end
    end
    return true
end

function EditorApp:keypressed(key, _, isRepeat)
    if self.dialog then
        self.dialog:keypressed(key)
    elseif self.valueEdit and not self.session:isPlaying() then
        if self.valueEdit:keypressed(key) then
            if key == "backspace" or key == "delete" then
                self.valueEdit.invalid = false
            end
        elseif key == "return" or key == "kpenter" then
            self:commitValueEdit()
        elseif key == "escape" then
            self.valueEdit = nil
        end
    elseif not isRepeat and key == "delete" and self.session:hasStage()
        and not self.session:isPlaying()
        and next(self.selectedTimelineEventIds) ~= nil then
        local deleted, errorMessage = self.session:deleteTimelineEvents(
            self.selectedTimelineEventIds
        )
        if deleted then
            self.selectedTimelineEventIds = {}
            self.hoveredTimelineEventId = nil
        else
            self:showError(errorMessage)
        end
    elseif not isRepeat and key == "s" and self.isControlDown()
        and self.session:hasStage() then
        self:executeAction("save")
    elseif not isRepeat and key == "f" and self.session:hasStage() then
        if self.session:isPlaying() then
            self.session:pause()
        else
            self:executeAction("play")
        end
    elseif not isRepeat and key == "r" and self.session:hasStage() then
        if self.session:isPlaying() then self.session:pause() end
        local reset, errorMessage = self.session:resetTimeline()
        if not reset then self:showError(errorMessage) end
    end
    return true
end

return EditorApp
