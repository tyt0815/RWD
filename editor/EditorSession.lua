local Core = require("core")
local StageDocument = require("editor.stage.StageDocument")

local EditorSession = {}
EditorSession.__index = EditorSession

function EditorSession.new(options)
    assert(options and options.projectCatalog, "projectCatalog is required")
    assert(options.stageStore, "stageStore is required")
    assert(options.testPlayer, "testPlayer is required")

    return setmetatable({
        projectCatalog = options.projectCatalog,
        stageStore = options.stageStore,
        testPlayer = options.testPlayer,
        clockFactory = options.clockFactory or Core.PlaybackClock.new,
        project = nil,
        document = nil,
        clock = nil,
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
    return self.clock ~= nil and self.clock:isPlaying()
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
    return self.clock and self.clock:getBeat() or 0
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
    local clock, clockError = self.clockFactory(document:getBpm())
    if not clock then return nil, clockError end

    self.testPlayer:stop()
    self.project = project
    self.document = document
    self.clock = clock
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

    local clockChanged, clockError = self.clock:setBpm(bpm)
    if not clockChanged then return nil, clockError end
    return self.document:setBpm(bpm)
end

function EditorSession:play()
    if not self.document then return nil, "No Stage is open." end

    local started, errorMessage = self.testPlayer:start(self.project)
    if not started then
        self:pause()
        return nil, errorMessage
    end

    self.clock:play()
    return true, nil
end

function EditorSession:pause()
    if self.clock then self.clock:pause() end
    self.testPlayer:stop()
end

function EditorSession:update(deltaTime, visibleBeatCount)
    if not self:isPlaying() then return true, nil end

    self.clock:update(deltaTime)
    local updated, errorMessage = self.testPlayer:update(deltaTime)
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
