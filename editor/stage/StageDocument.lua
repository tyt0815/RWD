local Core = require("core")

local StageDocument = {}
StageDocument.__index = StageDocument

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    local valueMetatable = getmetatable(value)
    if type(valueMetatable) == "table" and valueMetatable.__tojson ~= nil then
        return value
    end

    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

local function normalize(data)
    local normalized, errorMessage = Core.StageSchema.normalize(data)
    if not normalized then return nil, errorMessage end
    return normalized, nil
end

local function newDocument(data, dirty)
    local normalized, errorMessage = normalize(data)
    if not normalized then return nil, errorMessage end
    return setmetatable({ data = normalized, dirty = dirty }, StageDocument), nil
end

local function findEvent(data, eventId)
    for index, event in ipairs(data.events) do
        if event.id == eventId then return event, index end
    end
    return nil, nil
end

-- Task 5에서 StageStore와 함께 제거할 임시 호환 adapter다.
function StageDocument.validate(data)
    local valid, errorMessage = Core.StageSchema.validate(data)
    return valid and nil or errorMessage
end

-- Task 5에서 StageStore와 함께 제거할 임시 호환 adapter다.
function StageDocument.isSafeId(value)
    return Core.StageSchema.isSafeId(value)
end

function StageDocument.create(projectId, stageId, name, bpm)
    return newDocument({
        schemaVersion = 3,
        projectId = projectId,
        stageId = stageId,
        name = name,
        bpm = bpm,
        events = {},
    }, true)
end

function StageDocument.fromTable(data)
    return newDocument(data, false)
end

function StageDocument.fromSnapshot(data, dirty)
    return newDocument(data, dirty == true)
end

function StageDocument:toTable()
    return deepCopy(self.data)
end

function StageDocument:getProjectId()
    return self.data.projectId
end

function StageDocument:getStageId()
    return self.data.stageId
end

function StageDocument:getName()
    return self.data.name
end

function StageDocument:getBpm()
    return self.data.bpm
end

function StageDocument:getMixtape()
    return Core.MixtapeSettings.resolve(self.data.mixtape)
end

function StageDocument:getEditorSettings()
    return Core.StageSchema.resolveEditorSettings(self.data)
end

function StageDocument:isDirty()
    return self.dirty
end

function StageDocument:markClean()
    self.dirty = false
end

function StageDocument:setBpm(bpm)
    local candidateData = self:toTable()
    candidateData.bpm = bpm
    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    if self.data.bpm ~= normalized.bpm then
        self.data = normalized
        self.dirty = true
    end
    return true, nil
end

local function setSparseValue(document, sectionName, key, value, resolve)
    local current = resolve(document.data)
    local candidateSection = deepCopy(current)
    candidateSection[key] = value
    local candidateData = document:toTable()
    candidateData[sectionName] = candidateSection
    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    local resolved = resolve(normalized)
    if current[key] ~= resolved[key] then
        document.data = normalized
        document.dirty = true
    end
    return true, nil
end

function StageDocument:setMixtapeValue(key, value)
    return setSparseValue(self, "mixtape", key, value, function(stage)
        return Core.MixtapeSettings.resolve(stage.mixtape)
    end)
end

function StageDocument:setEditorSetting(key, value)
    return setSparseValue(self, "editorSettings", key, value, function(stage)
        return Core.StageSchema.resolveEditorSettings(stage)
    end)
end

function StageDocument:getEvents()
    return deepCopy(self.data.events)
end

function StageDocument:addEvent(
    eventType,
    startBeat,
    track,
    projectCategoryId,
    projectEventId,
    params
)
    local sequence = 1
    local eventId
    repeat
        eventId = string.format("event-%03d", sequence)
        sequence = sequence + 1
    until findEvent(self.data, eventId) == nil

    local event = {
        id = eventId,
        type = eventType,
        startBeat = startBeat,
        track = track,
    }
    if eventType == "setInputEnabled" then
        event.enabled = params and params.enabled == true or false
    elseif eventType == "projectEvent" then
        event.categoryId = projectCategoryId
        event.eventId = projectEventId
        event.params = deepCopy(params or {})
    end

    local candidateData = self:toTable()
    table.insert(candidateData.events, event)
    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    self.data = normalized
    self.dirty = true
    local storedEvent = assert(findEvent(self.data, eventId))
    return deepCopy(storedEvent), nil
end

function StageDocument:addEvents(events)
    local candidateData = self:toTable()
    local usedIds = {}
    for _, event in ipairs(candidateData.events) do usedIds[event.id] = true end
    local addedIds = {}
    local sequence = 1
    for _, source in ipairs(events) do
        local event = deepCopy(source)
        repeat
            event.id = string.format("event-%03d", sequence)
            sequence = sequence + 1
        until not usedIds[event.id]
        usedIds[event.id] = true
        table.insert(candidateData.events, event)
        table.insert(addedIds, event.id)
    end

    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    self.data = normalized
    local added = {}
    for _, eventId in ipairs(addedIds) do
        local storedEvent = assert(findEvent(self.data, eventId))
        table.insert(added, deepCopy(storedEvent))
    end
    if #added > 0 then self.dirty = true end
    return added, nil
end

function StageDocument:moveEvents(positions)
    local candidateData = self:toTable()
    local changed = false
    for eventId, position in pairs(positions) do
        local event = findEvent(candidateData, eventId)
        if not event then
            return nil, "Unknown Timeline Event: " .. tostring(eventId)
        end
        if event.startBeat ~= position.startBeat or event.track ~= position.track then
            event.startBeat = position.startBeat
            event.track = position.track
            changed = true
        end
    end

    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    if changed then
        self.data = normalized
        self.dirty = true
    end
    return true, nil
end

function StageDocument:moveEvent(eventId, startBeat, track)
    return self:moveEvents({
        [eventId] = { startBeat = startBeat, track = track },
    })
end

function StageDocument:deleteEvents(eventIds)
    local candidateData = self:toTable()
    local deletedCount = 0
    for index = #candidateData.events, 1, -1 do
        if eventIds[candidateData.events[index].id] then
            table.remove(candidateData.events, index)
            deletedCount = deletedCount + 1
        end
    end
    if deletedCount > 0 then
        local normalized, errorMessage = normalize(candidateData)
        if not normalized then return nil, errorMessage end
        self.data = normalized
        self.dirty = true
    end
    return deletedCount, nil
end

function StageDocument:setEventProperty(eventId, propertyId, value)
    local candidateData = self:toTable()
    local event = findEvent(candidateData, eventId)
    if not event then return nil, "Unknown Timeline Event: " .. tostring(eventId) end

    local currentValue
    if event.type == "setInputEnabled" and propertyId == "enabled" then
        currentValue = event.enabled
        event.enabled = value
    elseif event.type == "projectEvent" and event.params[propertyId] ~= nil then
        currentValue = event.params[propertyId]
        event.params[propertyId] = value
    else
        return nil, "Unknown Timeline Event property: " .. tostring(propertyId)
    end

    local normalized, errorMessage = normalize(candidateData)
    if not normalized then return nil, errorMessage end
    if currentValue ~= value then
        self.data = normalized
        self.dirty = true
    end
    return true, nil
end

function StageDocument:cloneAs(stageId, name)
    local data = self:toTable()
    data.stageId = stageId
    data.name = name
    return newDocument(data, true)
end

return StageDocument
