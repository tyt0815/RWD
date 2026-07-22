local Core = require("core")
local StageDocument = require("editor.stage.StageDocument")
local MetronomePlayback = require("editor.playback.MetronomePlayback")

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
        timelineStartBeat = 0,
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

function EditorSession:getTimelineStartBeat()
    return self.timelineStartBeat
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
    self.timelineStartBeat = 0
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

    local transportUpdated, transportError = self.transport:update(deltaTime)
    if not transportUpdated then
        self:pause()
        return nil, transportError
    end

    local playbackRate = self.document:getEditorSettings().playbackRate
    local updated, errorMessage = self.testPlayer:update(deltaTime * playbackRate)
    if not updated then
        self:pause()
        return nil, errorMessage
    end

    if visibleBeatCount and self:getBeat() >= self.timelineStartBeat + visibleBeatCount then
        local requiredStart = self:getBeat() - visibleBeatCount + 4
        self.timelineStartBeat = math.max(0, math.floor(requiredStart / 4) * 4)
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
