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
        anchorBeat = 0,
        timelineStartBeat = 0,
        inputEnabled = true,
    }, EditorSession)
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
    local transport, transportError = self.transportFactory(document:getBpm())
    if not transport then return nil, transportError end

    self:pause()
    self.project = project
    self.document = document
    self.transport = transport
    self.anchorBeat = 0
    self.timelineStartBeat = 0
    self.inputEnabled = true
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
    return true, nil
end

function EditorSession:setBpm(bpm)
    if not self.document then return nil, "No Stage is open." end

    local candidate = self.document:toTable()
    candidate.bpm = bpm
    local validationError = StageDocument.validate(candidate)
    if validationError then return nil, validationError end

    local transportChanged, transportError = self.transport:setBpm(bpm)
    if not transportChanged then return nil, transportError end
    return self.document:setBpm(bpm)
end

function EditorSession:getTimelineEvents()
    if not self.document then return {} end
    return self.document:getEvents()
end

function EditorSession:addTimelineEvent(eventType, beat, track)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before placing Timeline Events." end
    local snap = self.document:getEditorSettings().snap
    return self.document:addEvent(
        eventType,
        TimelineSnap.snapBeat(beat, snap),
        track
    )
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
    return self.document:moveEvents(positions)
end

function EditorSession:moveTimelineEvent(eventId, beat, track)
    if not self.document then return nil, "No Stage is open." end
    local snap = self.document:getEditorSettings().snap
    return self:moveTimelineEvents({
        [eventId] = {
            startBeat = TimelineSnap.snapBeat(beat, snap),
            track = track,
        },
    })
end

function EditorSession:deleteTimelineEvents(eventIds)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before deleting Timeline Events." end
    return self.document:deleteEvents(eventIds)
end

function EditorSession:setTimelineEventProperty(eventId, propertyId, value)
    if not self.document then return nil, "No Stage is open." end
    if self:isPlaying() then return nil, "Pause before editing Timeline Events." end
    return self.document:setEventProperty(eventId, propertyId, value)
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
        return self.document:setEditorSetting(propertyId, value)
    end
    if groupId == "mixtapeProperties" then
        if propertyId == "bpm" then return self:setBpm(value) end
        return self.document:setMixtapeValue(propertyId, value)
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

    self.inputEnabled = true
    local latestInputBeat = -math.huge
    for _, event in ipairs(self.document:getEvents()) do
        if event.type == "setInputEnabled"
            and event.startBeat <= self.anchorBeat
            and event.startBeat >= latestInputBeat then
            self.inputEnabled = event.enabled
            latestInputBeat = event.startBeat
        end
    end

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

    local gameStarted, gameError = self.testPlayer:start(self.project)
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
    local reachedEndBeat
    local events = self.document:getEvents()
    for _, event in ipairs(events) do
        if event.type == "end"
            and event.startBeat >= previousBeat
            and event.startBeat <= currentBeat
            and (reachedEndBeat == nil or event.startBeat < reachedEndBeat) then
            reachedEndBeat = event.startBeat
        end
    end

    local eventCutoffBeat = reachedEndBeat or currentBeat
    local latestInputBeat = -math.huge
    local latestInputEnabled
    for _, event in ipairs(events) do
        if event.type == "setInputEnabled"
            and event.startBeat > previousBeat
            and event.startBeat <= eventCutoffBeat
            and event.startBeat >= latestInputBeat then
            latestInputBeat = event.startBeat
            latestInputEnabled = event.enabled
        end
    end
    if latestInputEnabled ~= nil then self.inputEnabled = latestInputEnabled end
    if reachedEndBeat ~= nil then
        self:pause()
        local seeked, seekError = self.transport:seekBeat(reachedEndBeat)
        if not seeked then return nil, seekError end
        return true, nil
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
    local updated, errorMessage = self.testPlayer:update(deltaTime * playbackRate)
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

function EditorSession:drawPreview(rect)
    local drawn, errorMessage = self.testPlayer:draw(rect)
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
