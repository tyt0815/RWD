local StageDocument = {}
StageDocument.__index = StageDocument

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
    if data.schemaVersion ~= 1 then
        return "$.schemaVersion must be 1."
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
    if not isArray(data.tempoMap) or #data.tempoMap ~= 1 then
        return "$.tempoMap must contain exactly one item."
    end
    local tempo = data.tempoMap[1]
    if not isObject(tempo) then
        return "$.tempoMap[1] must be an object."
    end
    if tempo.startBeat ~= 0 then
        return "$.tempoMap[1].startBeat must be 0."
    end
    if not isFiniteNumber(tempo.bpm) or tempo.bpm <= 0 then
        return "$.tempoMap[1].bpm must be a positive finite number."
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
    normalizeEmptyPatternParams(documentData)
    return setmetatable({ data = documentData, dirty = dirty }, StageDocument), nil
end

function StageDocument.create(projectId, stageId, name, bpm)
    return newDocument({
        schemaVersion = 1,
        projectId = projectId,
        stageId = stageId,
        name = name,
        tempoMap = { { startBeat = 0, bpm = bpm } },
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
    return self.data.tempoMap[1].bpm
end

function StageDocument:isDirty()
    return self.dirty
end

function StageDocument:markClean()
    self.dirty = false
end

function StageDocument:setBpm(bpm)
    if not isFiniteNumber(bpm) or bpm <= 0 then
        return nil, "$.tempoMap[1].bpm must be a positive finite number."
    end
    if self.data.tempoMap[1].bpm ~= bpm then
        self.data.tempoMap[1].bpm = bpm
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
