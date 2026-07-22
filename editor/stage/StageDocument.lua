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

local function validateEvent(event, index)
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
    else
        return path .. ".type must be pattern, tapNote, or longNote."
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
    for index, event in ipairs(data.events) do
        local eventError = validateEvent(event, index)
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
    return setSparseValue(self, "editorSettings", key, value, EditorSettings)
end

function StageDocument:cloneAs(stageId, name)
    local data = self:toTable()
    data.stageId = stageId
    data.name = name
    return newDocument(data, true)
end

return StageDocument
