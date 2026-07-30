local Core = require("core")
local StageDocument = require("editor.stage.StageDocument")
local MetronomePlayback = require("editor.playback.MetronomePlayback")
local TimelineSnap = require("editor.timeline.TimelineSnap")
local TimelineEventGeometry = require("editor.timeline.TimelineEventGeometry")

local EditorSession = {}
EditorSession.__index = EditorSession

local function defaultTransportFactory(bpm)
    return Core.PlaybackTransport.new({
        bpm = bpm,
        musicPlayback = Core.MusicPlayback.new(),
    })
end

local function resolveProjectMusicPath(project, music)
    if not music then return nil end
    return "projects/" .. project.id .. "/" .. music
end

local function fitPreviewRect(rect, aspectWidth, aspectHeight)
    if type(rect.width) ~= "number" or type(rect.height) ~= "number" then
        return rect
    end
    local aspect = aspectWidth / aspectHeight
    local width
    local height
    if rect.width / rect.height > aspect then
        height = math.max(1, math.floor(rect.height))
        width = math.max(1, math.floor(height * aspect))
    else
        width = math.max(1, math.floor(rect.width))
        height = math.max(1, math.floor(width / aspect))
    end
    return {
        x = rect.x + math.floor((rect.width - width) / 2),
        y = rect.y + math.floor((rect.height - height) / 2),
        width = width,
        height = height,
    }
end

local function getProjectEventDefinition(project, eventId)
    return Core.ProjectEvents.getEvent(project, eventId)
end

local function validateProjectEventData(project, document)
    local singletonCounts = {}
    for _, event in ipairs(document:getEvents()) do
        if event.type == "projectEvent" then
            local definition = getProjectEventDefinition(project, event.eventId)
            if not definition then
                return "Unknown Project Event: " .. tostring(event.eventId)
            end
            local paramsError = Core.ProjectEvents.validateParams(
                definition,
                event.params
            )
            if paramsError then return paramsError end
            if definition.singleton then
                singletonCounts[event.eventId] = (singletonCounts[event.eventId] or 0) + 1
                if singletonCounts[event.eventId] > 1 then
                    return definition.label .. " allows only one Event."
                end
            end
        end
    end
    return nil
end

local function decorateProjectEvent(event, definition)
    if event.type ~= "projectEvent" or not definition then return event end
    event.projectDefinition = definition
    local geometry = definition.geometry or {}
    local connector = TimelineEventGeometry.resolveConnector(event.params, geometry)
    if connector then
        event.widthBeats = connector.widthBeats
        if geometry.connector then
            event.collisionSegments = connector.collisionSegments
            event.timelineStyle = "connector"
            event.responseBeatOffset = connector.responseBeatOffset
            event.startEndpointWidthBeats = connector.startWidthBeats
            event.endEndpointWidthBeats = connector.endWidthBeats
            event.endpointStartColor = geometry.startColor
            event.endpointEndColor = geometry.endColor
        end
    elseif type(geometry.widthBeats) == "number" then
        event.widthBeats = geometry.widthBeats
    end
    return event
end

function EditorSession.new(options)
    assert(options and options.projectCatalog, "projectCatalog is required")
    assert(options.stageStore, "stageStore is required")
    assert(options.testPlayer, "testPlayer is required")

    return setmetatable({
        projectCatalog = options.projectCatalog,
        stageStore = options.stageStore,
        testPlayer = options.testPlayer,
        transportFactory = options.transportFactory or defaultTransportFactory,
        metronome = options.metronome or MetronomePlayback.new(),
        project = nil,
        document = nil,
        transport = nil,
        stageRuntime = nil,
        anchorBeat = 0,
        timelineStartBeat = 0,
        inputEnabled = true,
        timelineHistory = {},
        timelineHistoryIndex = 0,
    }, EditorSession)
end

function EditorSession:resetTimelineHistory()
    self.timelineHistory = {}
    self.timelineHistoryIndex = 0
    if self.document then self:recordTimelineHistory() end
end

function EditorSession:recordTimelineHistory()
    for index = #self.timelineHistory, self.timelineHistoryIndex + 1, -1 do
        table.remove(self.timelineHistory, index)
    end
    table.insert(self.timelineHistory, {
        data = self.document:toTable(),
        dirty = self.document:isDirty(),
    })
    self.timelineHistoryIndex = #self.timelineHistory
end

function EditorSession:restoreTimelineHistory(index)
    local snapshot = self.timelineHistory[index]
    if not snapshot then return nil, "No Timeline edit history is available." end
    local document, errorMessage = StageDocument.fromSnapshot(
        snapshot.data,
        snapshot.dirty
    )
    if not document then return nil, errorMessage end
    local bpmChanged, bpmError = self.transport:setBpm(document:getBpm())
    if not bpmChanged then return nil, bpmError end
    self.document = document
    self.timelineHistoryIndex = index
    return true, nil
end

function EditorSession:undoTimelineEdit()
    if self:isPlaying() then return nil, "Pause before undoing Timeline edits." end
    if self.timelineHistoryIndex <= 1 then return nil, "Nothing to undo." end
    return self:restoreTimelineHistory(self.timelineHistoryIndex - 1)
end

function EditorSession:redoTimelineEdit()
    if self:isPlaying() then return nil, "Pause before redoing Timeline edits." end
    if self.timelineHistoryIndex >= #self.timelineHistory then
        return nil, "Nothing to redo."
    end
    return self:restoreTimelineHistory(self.timelineHistoryIndex + 1)
end

function EditorSession:hasStage()
    return self.document ~= nil
end

function EditorSession:isDirty()
    return self.document ~= nil and self.document:isDirty()
end

function EditorSession:isPlaying()
    return self.transport ~= nil and self.transport:isPlaying()
end

function EditorSession:getProject()
    return self.project
end

function EditorSession:getDocument()
    return self.document
end

function EditorSession:getBpm()
    return self.document and self.document:getBpm() or nil
end

function EditorSession:getBeat()
    return self.transport and self.transport:getBeat() or 0
end

function EditorSession:getAnchorBeat()
    return self.anchorBeat
end

function EditorSession:getTimelineStartBeat()
    return self.timelineStartBeat
end

function EditorSession:isInputEnabled()
    return self.inputEnabled
end

function EditorSession:seekTimeline(beat)
    if not self.document then return nil, "No Stage is open." end
    local snap = self.document:getEditorSettings().snap
    local snappedBeat = TimelineSnap.snapBeat(beat, snap)
    local seeked, errorMessage = self.transport:seekBeat(snappedBeat)
    if not seeked then return nil, errorMessage end
    self.anchorBeat = snappedBeat
    return true, nil
end

function EditorSession:resetTimeline()
    local seeked, errorMessage = self:seekTimeline(0)
    if not seeked then return nil, errorMessage end
    self.timelineStartBeat = 0
    return true, nil
end

function EditorSession:panTimeline(deltaX, pixelsPerBeat)
    if not self.document then return nil, "No Stage is open." end
    self.timelineStartBeat = math.max(
        0,
        self.timelineStartBeat - deltaX / pixelsPerBeat
    )
    return true, nil
end

function EditorSession:zoomTimeline(cursorOffsetX, wheelY)
    if not self.document then return nil, "No Stage is open." end

    local oldScale = self.document:getEditorSettings().scale
    local newScale = math.max(0.25, math.min(8, oldScale * (1.25 ^ wheelY)))
    local cursorBeat = self.timelineStartBeat
        + cursorOffsetX / (32 * oldScale) - 1
    local newStart = cursorBeat - cursorOffsetX / (32 * newScale) + 1
    local changed, errorMessage = self.document:setEditorSetting("scale", newScale)
    if not changed then return nil, errorMessage end
    if oldScale ~= newScale then self:recordTimelineHistory() end
    self.timelineStartBeat = math.max(0, newStart)
    return true, nil
end

function EditorSession:listProjects()
    return self.projectCatalog:listProjects()
end

function EditorSession:listStages(projectId)
    return self.stageStore:listStages(projectId)
end

function EditorSession:replaceStage(project, document)
    local projectEventError = validateProjectEventData(project, document)
    if projectEventError then return nil, projectEventError end
    local transport, transportError = self.transportFactory(document:getBpm())
    if not transport then return nil, transportError end

    self:pause()
    self.project = project
    self.document = document
    self.transport = transport
    self.stageRuntime = nil
    self.anchorBeat = 0
    self.timelineStartBeat = 0
    self.inputEnabled = true
    self:resetTimelineHistory()
    return true, nil
end

function EditorSession:createStage(projectId, stageId, name, bpm)
    local project, projectError = self.projectCatalog:getProject(projectId)
    if not project then return nil, projectError end

    local exists, existsError = self.stageStore:stageExists(projectId, stageId)
    if exists == nil then return nil, existsError end
    if exists then return nil, "Stage already exists: " .. stageId end

    local document, documentError = StageDocument.create(projectId, stageId, name, bpm)
    if not document then return nil, documentError end
    return self:replaceStage(project, document)
end

function EditorSession:openStage(projectId, stageId)
    local project, projectError = self.projectCatalog:getProject(projectId)
    if not project then return nil, projectError end

    local data, loadError = self.stageStore:load(projectId, stageId)
    if not data then return nil, loadError end

    local document, documentError = StageDocument.fromTable(data)
    if not document then return nil, documentError end
    return self:replaceStage(project, document)
end

function EditorSession:save()
    if not self.document then return nil, "No Stage is open." end

    local saved, errorMessage, errorCode = self.stageStore:save(
        self.document:toTable(),
        true
    )
    if not saved then return nil, errorMessage, errorCode end

    self.document:markClean()
    if self.timelineHistory[self.timelineHistoryIndex] then
        self.timelineHistory[self.timelineHistoryIndex].data = self.document:toTable()
        self.timelineHistory[self.timelineHistoryIndex].dirty = false
    end
    return true, nil
end

function EditorSession:saveAs(stageId, name, overwrite)
    if not self.document then return nil, "No Stage is open." end

    local copy, copyError = self.document:cloneAs(stageId, name)
    if not copy then return nil, copyError end

    local saved, errorMessage, errorCode = self.stageStore:save(
        copy:toTable(),
        overwrite == true
    )
    if not saved then return nil, errorMessage, errorCode end

    copy:markClean()
    self.document = copy
    self:resetTimelineHistory()
    return true, nil
end

function EditorSession:setBpm(bpm)
    if not self.document then return nil, "No Stage is open." end

    local previousBpm = self.document:getBpm()
    local candidate = self.document:toTable()
    candidate.bpm = bpm
    local validationError = StageDocument.validate(candidate)
    if validationError then return nil, validationError end

    local transportChanged, transportError = self.transport:setBpm(bpm)
    if not transportChanged then return nil, transportError end
    local changed, errorMessage = self.document:setBpm(bpm)
    if changed and previousBpm ~= bpm then self:recordTimelineHistory() end
    return changed, errorMessage
end

function EditorSession:getTimelineEvents()
    if not self.document then return {} end
    local events = self.document:getEvents()
    for _, event in ipairs(events) do
        if event.type == "projectEvent" then
            decorateProjectEvent(
                event,
                getProjectEventDefinition(self.project, event.eventId)
            )
        end
    end
    return events
end

function EditorSession:addTimelineEvent(eventType, beat, track, params)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before placing Timeline Events." end
    local projectEventId = type(eventType) == "string"
        and eventType:match("^project:(.+)$") or nil
    local projectDefinition
    if projectEventId then
        projectDefinition = getProjectEventDefinition(self.project, projectEventId)
        if not projectDefinition then return nil, "Unknown Project Event: " .. projectEventId end
        params = params or Core.ProjectEvents.getDefaultParams(projectDefinition)
        local paramsError = Core.ProjectEvents.validateParams(projectDefinition, params)
        if paramsError then return nil, paramsError end
        if projectDefinition.singleton then
            for _, event in ipairs(self.document:getEvents()) do
                if event.type == "projectEvent" and event.eventId == projectEventId then
                    return nil, projectDefinition.label .. " allows only one Event.", "PROJECT_EVENT_EXISTS"
                end
            end
        end
        eventType = "projectEvent"
    end
    local snap = self.document:getEditorSettings().snap
    local snappedBeat = TimelineSnap.snapEventBeat(beat, snap)
    local events = self:getTimelineEvents()
    if eventType == "end" then
        for _, event in ipairs(events) do
            if event.type == "end" then
                return nil,
                    "Stage can contain only one End Event.",
                    "END_EVENT_EXISTS"
            end
        end
    end
    local candidateId = "__new_timeline_event__"
    local usedIds = {}
    for _, event in ipairs(events) do usedIds[event.id] = true end
    while usedIds[candidateId] do candidateId = candidateId .. "_" end
    local candidate = {
        id = candidateId,
        type = eventType,
        startBeat = snappedBeat,
        track = track,
    }
    if projectEventId then
        candidate.eventId = projectEventId
        candidate.params = params
        decorateProjectEvent(candidate, projectDefinition)
    end
    table.insert(events, candidate)
    local collisions = TimelineEventGeometry.findCollisionIds(
        events,
        { [candidateId] = true }
    )
    if next(collisions) ~= nil then
        return nil,
            "Cannot place Timeline Event because its area would overlap another node.",
            "TIMELINE_EVENT_OVERLAP"
    end
    local added, errorMessage = self.document:addEvent(
        eventType,
        snappedBeat,
        track,
        projectEventId,
        params
    )
    if added then self:recordTimelineHistory() end
    return added, errorMessage
end

function EditorSession:getTimelineEventCopies(eventIds)
    if not self.document then return {} end
    local copies = {}
    for _, event in ipairs(self.document:getEvents()) do
        if eventIds[event.id] then table.insert(copies, event) end
    end
    return copies
end

function EditorSession:pasteTimelineEvents(sourceEvents, beat, track)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before pasting Timeline Events." end
    if #sourceEvents == 0 then return nil, "No Timeline Events have been copied." end

    local minimumBeat = math.huge
    local minimumTrack = math.huge
    local maximumTrack = -math.huge
    for _, event in ipairs(sourceEvents) do
        minimumBeat = math.min(minimumBeat, event.startBeat)
        minimumTrack = math.min(minimumTrack, event.track or 1)
        maximumTrack = math.max(maximumTrack, event.track or 1)
    end
    local snap = self.document:getEditorSettings().snap
    local targetBeat = TimelineSnap.snapEventBeat(math.max(0, beat), snap)
    local trackDelta = track - minimumTrack
    if maximumTrack + trackDelta > self.document:getEditorSettings().trackCount then
        return nil, "Cannot paste Timeline Events outside the available Tracks."
    end

    local candidates = {}
    local movingIds = {}
    for index, source in ipairs(sourceEvents) do
        local candidate = {}
        for key, value in pairs(source) do candidate[key] = value end
        candidate.startBeat = targetBeat + source.startBeat - minimumBeat
        candidate.track = (source.track or 1) + trackDelta
        candidate.id = "__pasted_timeline_event_" .. index
        movingIds[candidate.id] = true
        if candidate.type == "projectEvent" then
            local definition = getProjectEventDefinition(self.project, candidate.eventId)
            if not definition then
                return nil, "Unknown Project Event: " .. tostring(candidate.eventId)
            end
            local paramsError = Core.ProjectEvents.validateParams(
                definition,
                candidate.params
            )
            if paramsError then return nil, paramsError end
            if definition.singleton then
                for _, existing in ipairs(self.document:getEvents()) do
                    if existing.type == "projectEvent"
                        and existing.eventId == candidate.eventId then
                        return nil, definition.label .. " allows only one Event."
                    end
                end
            end
        end
        table.insert(candidates, candidate)
    end

    local proposedEvents = self:getTimelineEvents()
    for _, candidate in ipairs(candidates) do
        local previewCandidate = {}
        for key, value in pairs(candidate) do previewCandidate[key] = value end
        if previewCandidate.type == "projectEvent" then
            decorateProjectEvent(
                previewCandidate,
                getProjectEventDefinition(self.project, previewCandidate.eventId)
            )
        end
        table.insert(proposedEvents, previewCandidate)
    end
    local collisions = TimelineEventGeometry.findCollisionIds(
        proposedEvents,
        movingIds
    )
    if next(collisions) ~= nil then
        return nil, "Cannot paste Timeline Events because their areas would overlap other nodes."
    end

    for _, candidate in ipairs(candidates) do candidate.id = nil end
    local added, errorMessage = self.document:addEvents(candidates)
    if not added then return nil, errorMessage end
    self:recordTimelineHistory()
    return added, nil
end

function EditorSession:moveTimelineEvents(positions)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before moving Timeline Events." end

    local movingIds = {}
    for eventId in pairs(positions) do movingIds[eventId] = true end

    local proposedEvents = self.document:getEvents()
    for _, event in ipairs(proposedEvents) do
        local position = positions[event.id]
        if position then
            event.startBeat = position.startBeat
            event.track = position.track
        end
    end
    local collisions = TimelineEventGeometry.findCollisionIds(
        proposedEvents,
        movingIds
    )
    if next(collisions) ~= nil then
        return nil, "Timeline Events cannot overlap.", collisions
    end
    local moved, errorMessage = self.document:moveEvents(positions)
    if moved then self:recordTimelineHistory() end
    return moved, errorMessage
end

function EditorSession:moveTimelineEvent(eventId, beat, track)
    if not self.document then return nil, "No Stage is open." end
    local snap = self.document:getEditorSettings().snap
    return self:moveTimelineEvents({
        [eventId] = {
            startBeat = TimelineSnap.snapEventBeat(beat, snap),
            track = track,
        },
    })
end

function EditorSession:deleteTimelineEvents(eventIds)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before deleting Timeline Events." end
    local deleted, errorMessage = self.document:deleteEvents(eventIds)
    if deleted and deleted > 0 then self:recordTimelineHistory() end
    return deleted, errorMessage
end

function EditorSession:setTimelineEventProperty(eventId, propertyId, value)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before editing Timeline Events." end
    for _, event in ipairs(self.document:getEvents()) do
        if event.id == eventId and event.type == "projectEvent" then
            local definition = getProjectEventDefinition(self.project, event.eventId)
            local params = event.params
            params[propertyId] = value
            local paramsError = Core.ProjectEvents.validateParams(definition, params)
            if paramsError then return nil, paramsError end
            break
        end
    end
    local before
    for _, event in ipairs(self.document:getEvents()) do
        if event.id == eventId then
            before = event.type == "projectEvent"
                and event.params[propertyId] or event[propertyId]
            break
        end
    end
    local changed, errorMessage = self.document:setEventProperty(
        eventId,
        propertyId,
        value
    )
    if changed and before ~= value then self:recordTimelineHistory() end
    return changed, errorMessage
end

function EditorSession:getProperty(groupId, propertyId)
    if not self.document then return nil, "No Stage is open." end

    if groupId == "editorProperties" then
        return self.document:getEditorSettings()[propertyId]
    end
    if groupId == "mixtapeProperties" then
        if propertyId == "bpm" then return self.document:getBpm() end
        return self.document:getMixtape()[propertyId]
    end
    return nil, "Unknown property group: " .. tostring(groupId)
end

function EditorSession:setProperty(groupId, propertyId, value)
    if not self.document then return nil, "No Stage is open." end

    if groupId == "editorProperties" then
        local previous = self.document:getEditorSettings()[propertyId]
        local changed, errorMessage = self.document:setEditorSetting(
            propertyId,
            value
        )
        if changed and previous ~= value then self:recordTimelineHistory() end
        return changed, errorMessage
    end
    if groupId == "mixtapeProperties" then
        if propertyId == "bpm" then return self:setBpm(value) end
        local previous = self.document:getMixtape()[propertyId]
        local changed, errorMessage = self.document:setMixtapeValue(
            propertyId,
            value
        )
        if changed and previous ~= value then self:recordTimelineHistory() end
        return changed, errorMessage
    end
    return nil, "Unknown property group: " .. tostring(groupId)
end

function EditorSession:play()
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return true, nil end

    if math.abs(self.transport:getBeat() - self.anchorBeat) > 0.000001 then
        local seeked, seekError = self.transport:seekBeat(self.anchorBeat)
        if not seeked then return nil, seekError end
    end

    self.stageRuntime = Core.StageRuntime.new()
    local _, runtimeError = self.stageRuntime:start(
        self.document:toTable(),
        self.anchorBeat
    )
    if runtimeError then
        self.stageRuntime = nil
        return nil, runtimeError
    end
    self.inputEnabled = self.stageRuntime:isInputEnabled()

    local mixtape = self.document:getMixtape()
    local editorSettings = self.document:getEditorSettings()
    local configured, configureError = self.transport:configureMixtape(
        mixtape,
        resolveProjectMusicPath(self.project, mixtape.music)
    )
    if not configured then
        self:pause()
        return nil, configureError
    end

    local gameStarted, gameError = self.testPlayer:start(
        self.project,
        self.document:toTable(),
        self.anchorBeat,
        editorSettings.autoPlay
    )
    if not gameStarted then
        self:pause()
        return nil, gameError
    end

    local transportStarted, transportError = self.transport:play(
        editorSettings.playbackRate
    )
    if not transportStarted then
        self:pause()
        return nil, transportError
    end

    if editorSettings.metronome then
        local metronomeStarted, metronomeError = self.metronome:play(
            self.document:getBpm(),
            editorSettings.metronomePeriod,
            self.transport:getBeat(),
            editorSettings.playbackRate
        )
        if not metronomeStarted then
            self:pause()
            return nil, metronomeError
        end
    end

    return true, nil
end

function EditorSession:pause()
    if self.transport then self.transport:pause() end
    self.metronome:pause()
    self.testPlayer:stop()
    self.stageRuntime = nil
end

function EditorSession:update(deltaTime, visibleBeatCount)
    if not self:isPlaying() then return true, nil end

    local previousBeat = self.transport:getBeat()
    local transportUpdated, transportError = self.transport:update(deltaTime)
    if not transportUpdated then
        self:pause()
        return nil, transportError
    end

    local currentBeat = self.transport:getBeat()
    local _, runtimeError = self.stageRuntime:update(currentBeat)
    if runtimeError then
        self:pause()
        return nil, runtimeError
    end
    self.inputEnabled = self.stageRuntime:isInputEnabled()
    if self.stageRuntime:isEnded() then
        local endBeat = self.stageRuntime:getEndBeat()
        self:pause()
        local seeked, seekError = self.transport:seekBeat(endBeat)
        if not seeked then return nil, seekError end
        return true, nil
    end
    if not self.stageRuntime:hasEndEvent()
        and self.transport.isMusicFinished
        and self.transport:isMusicFinished() then
        self:pause()
        return true, nil, "musicEnded"
    end

    if self.document:getEditorSettings().metronome then
        local metronomeUpdated, metronomeError = self.metronome:update(
            self.transport:getBeat()
        )
        if not metronomeUpdated then
            self:pause()
            return nil, metronomeError
        end
    end

    local playbackRate = self.document:getEditorSettings().playbackRate
    local updated, errorMessage = self.testPlayer:update(
        deltaTime * playbackRate,
        self.transport:getBeat(),
        deltaTime
    )
    if not updated then
        self:pause()
        local rolledBack, rollbackError = self.transport:seekBeat(previousBeat)
        if not rolledBack then
            return nil, tostring(errorMessage)
                .. " Rollback failed: " .. tostring(rollbackError)
        end
        return nil, errorMessage
    end

    if visibleBeatCount and self:getBeat() >= self.timelineStartBeat + visibleBeatCount then
        local followMargin = math.min(4, visibleBeatCount)
        local requiredStart = self:getBeat() - visibleBeatCount + followMargin
        self.timelineStartBeat = math.max(0, requiredStart)
    end

    return true, nil
end

function EditorSession:handleInput(key)
    if not self:isPlaying() or not self.inputEnabled then return true, nil end
    local handled, errorMessage = self.testPlayer:keypressed(key, self:getBeat())
    if not handled then self:pause() end
    return handled, errorMessage
end

function EditorSession:handleInputReleased(key)
    if not self:isPlaying() or not self.inputEnabled then return true, nil end
    local handled, errorMessage = self.testPlayer:keyreleased(key, self:getBeat())
    if not handled then self:pause() end
    return handled, errorMessage
end

function EditorSession:drawPreview(rect)
    local settings = self.document:getEditorSettings()
    local previewRect = fitPreviewRect(
        rect,
        settings.previewAspectWidth,
        settings.previewAspectHeight
    )
    local drawn, errorMessage = self.testPlayer:draw(previewRect)
    if not drawn then
        self:pause()
        return nil, errorMessage
    end
    return true, nil
end

function EditorSession:handlePreviewError()
    self:pause()
end

return EditorSession
