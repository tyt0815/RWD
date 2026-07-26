local StageDocument = {}
StageDocument.__index = StageDocument

local Core = require("core")
local EditorSettings = require("editor.stage.EditorSettings")

local SAFE_ID_PATTERN = "^[a-z0-9][a-z0-9_-]*$"

local function isWindowsReservedBasename(value)
    local normalized = string.lower(value)
    if normalized == "con" or normalized == "prn" or normalized == "aux" or normalized == "nul" then
        return true
    end
    return normalized:match("^com[1-9]$") ~= nil
        or normalized:match("^lpt[1-9]$") ~= nil
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

local function jsonTableKind(value)
    local valueMetatable = type(value) == "table" and getmetatable(value)
    if type(valueMetatable) ~= "table" then
        return nil
    end
    if valueMetatable.__tojson ~= nil then
        return "custom"
    end
    if valueMetatable.__jsontype == "array" or valueMetatable.__jsontype == "object" then
        return valueMetatable.__jsontype
    end
    return nil
end

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end
    local tableKind = jsonTableKind(value)
    if tableKind == "custom" or tableKind == "object" then
        return false
    end

    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    return maximum == count
end

local function isObject(value)
    if type(value) ~= "table" then
        return false
    end
    local tableKind = jsonTableKind(value)
    if tableKind == "custom" or tableKind == "array" then
        return false
    end
    if tableKind == "object" or next(value) == nil then
        return true
    end
    return not isArray(value)
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    if jsonTableKind(value) == "custom" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

local function normalizeEmptyPatternParams(data)
    for _, event in ipairs(data.events) do
        if event.type == "pattern"
            and event.params ~= nil
            and next(event.params) == nil
            and getmetatable(event.params) == nil then
            setmetatable(event.params, { __jsontype = "object" })
        end
    end
end

function StageDocument.isSafeId(value)
    return type(value) == "string"
        and value:match(SAFE_ID_PATTERN) ~= nil
        and not isWindowsReservedBasename(value)
end

local function validateEvent(event, index, trackCount)
    local path = "$.events[" .. index .. "]"
    if not isObject(event) then
        return path .. " must be an object."
    end
    if type(event.id) ~= "string" or event.id == "" then
        return path .. ".id must be a non-empty string."
    end
    if not isFiniteNumber(event.startBeat) or event.startBeat < 0 then
        return path .. ".startBeat must be a non-negative finite number."
    end
    if event.track ~= nil
        and (not isFiniteNumber(event.track)
            or event.track % 1 ~= 0
            or event.track < 1
            or event.track > trackCount) then
        return path .. ".track must be an integer between 1 and "
            .. trackCount .. "."
    end
    if event.type == "pattern" then
        if type(event.patternId) ~= "string" or event.patternId == "" then
            return path .. ".patternId must be a non-empty string."
        end
        if event.params ~= nil and not isObject(event.params) then
            return path .. ".params must be an object."
        end
    elseif event.type == "tapNote" then
        return nil
    elseif event.type == "longNote" then
        if not isFiniteNumber(event.durationBeats) or event.durationBeats <= 0 then
            return path .. ".durationBeats must be a positive finite number."
        end
    elseif event.type == "end" then
        if event.track == nil then return path .. ".track is required." end
    elseif event.type == "setInputEnabled" then
        if event.track == nil then return path .. ".track is required." end
        if type(event.enabled) ~= "boolean" then
            return path .. ".enabled must be a boolean."
        end
    else
        return path .. ".type must be pattern, tapNote, longNote, end, or setInputEnabled."
    end
    return nil
end

function StageDocument.validate(data)
    if not isObject(data) then
        return "$ must be an object."
    end
    if data.schemaVersion ~= 2 then
        return "$.schemaVersion must be 2."
    end
    if not StageDocument.isSafeId(data.projectId) then
        return "$.projectId must be a safe identifier."
    end
    if not StageDocument.isSafeId(data.stageId) then
        return "$.stageId must be a safe identifier."
    end
    if type(data.name) ~= "string" or data.name == "" then
        return "$.name must be a non-empty string."
    end
    if data.tempoMap ~= nil then
        return "$.tempoMap is not supported in schemaVersion 2."
    end
    if not isFiniteNumber(data.bpm) or data.bpm <= 0 then
        return "$.bpm must be a positive finite number."
    end
    if data.mixtape ~= nil and not isObject(data.mixtape) then
        return "$.mixtape must be an object."
    end
    local mixtapeError = Core.MixtapeSettings.validate(data.mixtape)
    if mixtapeError then
        return mixtapeError
    end
    if data.editorSettings ~= nil and not isObject(data.editorSettings) then
        return "$.editorSettings must be an object."
    end
    local editorError = EditorSettings.validate(data.editorSettings)
    if editorError then
        return editorError
    end
    if not isArray(data.events) then
        return "$.events must be an array."
    end
    local eventIds = {}
    local trackCount = EditorSettings.resolve(data.editorSettings).trackCount
    for index, event in ipairs(data.events) do
        local eventError = validateEvent(event, index, trackCount)
        if eventError then
            return eventError
        end
        if eventIds[event.id] then
            return "$.events[" .. index .. "].id must be unique."
        end
        eventIds[event.id] = true
    end
    return nil
end

local function newDocument(data, dirty)
    local validationError = StageDocument.validate(data)
    if validationError then
        return nil, validationError
    end
    local documentData = deepCopy(data)
    documentData.mixtape = Core.MixtapeSettings.compact(documentData.mixtape)
    documentData.editorSettings = EditorSettings.compact(documentData.editorSettings)
    normalizeEmptyPatternParams(documentData)
    return setmetatable({ data = documentData, dirty = dirty }, StageDocument), nil
end

function StageDocument.create(projectId, stageId, name, bpm)
    return newDocument({
        schemaVersion = 2,
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
    return EditorSettings.resolve(self.data.editorSettings)
end

function StageDocument:isDirty()
    return self.dirty
end

function StageDocument:markClean()
    self.dirty = false
end

function StageDocument:setBpm(bpm)
    if not isFiniteNumber(bpm) or bpm <= 0 then
        return nil, "$.bpm must be a positive finite number."
    end
    if self.data.bpm ~= bpm then
        self.data.bpm = bpm
        self.dirty = true
    end
    return true, nil
end

local function setSparseValue(document, sectionName, key, value, settingsModule)
    local current = settingsModule.resolve(document.data[sectionName])
    local candidate = {}
    for name, item in pairs(current) do
        candidate[name] = item
    end
    candidate[key] = value
    local validationError = settingsModule.validate(candidate)
    if validationError then
        return nil, validationError
    end
    local resolved = settingsModule.resolve(candidate)
    if current[key] ~= resolved[key] then
        document.data[sectionName] = settingsModule.compact(resolved)
        document.dirty = true
    end
    return true, nil
end

function StageDocument:setMixtapeValue(key, value)
    return setSparseValue(self, "mixtape", key, value, Core.MixtapeSettings)
end

function StageDocument:setEditorSetting(key, value)
    if key == "trackCount" then
        local candidateSettings = self:getEditorSettings()
        candidateSettings.trackCount = value
        local settingsError = EditorSettings.validate(candidateSettings)
        if settingsError then return nil, settingsError end
        for index, event in ipairs(self.data.events) do
            if event.track ~= nil and event.track > value then
                return nil, "$.events[" .. index .. "].track exceeds Track."
            end
        end
    end
    return setSparseValue(self, "editorSettings", key, value, EditorSettings)
end

function StageDocument:getEvents()
    local events = deepCopy(self.data.events)
    for _, event in ipairs(events) do
        if event.track == nil then event.track = 1 end
    end
    return events
end

local function findEvent(document, eventId)
    for index, event in ipairs(document.data.events) do
        if event.id == eventId then return event, index end
    end
    return nil, nil
end

function StageDocument:addEvent(eventType, startBeat, track)
    local trackCount = self:getEditorSettings().trackCount
    local sequence = 1
    local eventId
    repeat
        eventId = string.format("event-%03d", sequence)
        sequence = sequence + 1
    until findEvent(self, eventId) == nil

    local event = {
        id = eventId,
        type = eventType,
        startBeat = startBeat,
        track = track,
    }
    if eventType == "setInputEnabled" then event.enabled = false end
    local eventError = validateEvent(event, #self.data.events + 1, trackCount)
    if eventError then return nil, eventError end
    table.insert(self.data.events, event)
    self.dirty = true
    return deepCopy(event), nil
end

function StageDocument:moveEvents(positions)
    local candidates = {}
    for eventId, position in pairs(positions) do
        local event, index = findEvent(self, eventId)
        if not event then
            return nil, "Unknown Timeline Event: " .. tostring(eventId)
        end
        local candidate = deepCopy(event)
        candidate.startBeat = position.startBeat
        candidate.track = position.track
        local eventError = validateEvent(
            candidate,
            index,
            self:getEditorSettings().trackCount
        )
        if eventError then return nil, eventError end
        candidates[eventId] = candidate
    end

    local changed = false
    for eventId, candidate in pairs(candidates) do
        local event = findEvent(self, eventId)
        if event.startBeat ~= candidate.startBeat
            or event.track ~= candidate.track then
            event.startBeat = candidate.startBeat
            event.track = candidate.track
            changed = true
        end
    end
    if changed then self.dirty = true end
    return true, nil
end

function StageDocument:moveEvent(eventId, startBeat, track)
    return self:moveEvents({
        [eventId] = { startBeat = startBeat, track = track },
    })
end

function StageDocument:deleteEvents(eventIds)
    local deletedCount = 0
    for index = #self.data.events, 1, -1 do
        if eventIds[self.data.events[index].id] then
            table.remove(self.data.events, index)
            deletedCount = deletedCount + 1
        end
    end
    if deletedCount > 0 then self.dirty = true end
    return deletedCount, nil
end

function StageDocument:setEventProperty(eventId, propertyId, value)
    local event, index = findEvent(self, eventId)
    if not event then return nil, "Unknown Timeline Event: " .. tostring(eventId) end
    if event.type ~= "setInputEnabled" or propertyId ~= "enabled" then
        return nil, "Unknown Timeline Event property: " .. tostring(propertyId)
    end
    local candidate = deepCopy(event)
    candidate.enabled = value
    local eventError = validateEvent(
        candidate,
        index,
        self:getEditorSettings().trackCount
    )
    if eventError then return nil, eventError end
    if event.enabled ~= value then
        event.enabled = value
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
