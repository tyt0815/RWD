local MixtapeSettings = require("core.MixtapeSettings")
local StageSettings = require("core.StageSettings")

local StageSchema = {}
local ERROR_INVALID_STAGE = "INVALID_STAGE"
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
    if type(valueMetatable) ~= "table" then return nil end
    if valueMetatable.__tojson ~= nil then return "custom" end
    if valueMetatable.__jsontype == "array" or valueMetatable.__jsontype == "object" then
        return valueMetatable.__jsontype
    end
    return nil
end

local function isArray(value)
    if type(value) ~= "table" then return false end
    local tableKind = jsonTableKind(value)
    if tableKind == "custom" or tableKind == "object" then return false end

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
    if type(value) ~= "table" then return false end
    local tableKind = jsonTableKind(value)
    if tableKind == "custom" or tableKind == "array" then return false end
    if tableKind == "object" or next(value) == nil then return true end
    return not isArray(value)
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    if jsonTableKind(value) == "custom" then return value end

    seen = seen or {}
    if seen[value] then return seen[value] end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

local function normalizeEmptyEventParams(stage)
    for _, event in ipairs(stage.events) do
        if (event.type == "pattern" or event.type == "projectEvent")
            and event.params ~= nil
            and next(event.params) == nil
            and getmetatable(event.params) == nil then
            setmetatable(event.params, { __jsontype = "object" })
        end
    end
end

local function validateEvent(event, index, trackCount)
    local path = "$.events[" .. index .. "]"
    if not isObject(event) then return path .. " must be an object." end
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
        return path .. ".track must be an integer between 1 and " .. trackCount .. "."
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
    elseif event.type == "projectEvent" then
        if event.track == nil then return path .. ".track is required." end
        if type(event.categoryId) ~= "string" or event.categoryId == "" then
            return path .. ".categoryId must be a non-empty string."
        end
        if type(event.eventId) ~= "string" or event.eventId == "" then
            return path .. ".eventId must be a non-empty string."
        end
        if not isObject(event.params) then return path .. ".params must be an object." end
    elseif event.type == "end" then
        if event.track == nil then return path .. ".track is required." end
    elseif event.type == "setInputEnabled" then
        if event.track == nil then return path .. ".track is required." end
        if type(event.enabled) ~= "boolean" then return path .. ".enabled must be a boolean." end
    else
        return path .. ".type must be pattern, tapNote, longNote, projectEvent, end, or setInputEnabled."
    end
    return nil
end

function StageSchema.isSafeId(value)
    return type(value) == "string"
        and value:match(SAFE_ID_PATTERN) ~= nil
        and not isWindowsReservedBasename(value)
end

function StageSchema.validate(stage)
    local function invalid(message)
        return nil, message, ERROR_INVALID_STAGE
    end

    if not isObject(stage) then return invalid("$ must be an object.") end
    if stage.schemaVersion ~= 3 then return invalid("$.schemaVersion must be 3.") end
    if not StageSchema.isSafeId(stage.projectId) then
        return invalid("$.projectId must be a safe identifier.")
    end
    if not StageSchema.isSafeId(stage.stageId) then
        return invalid("$.stageId must be a safe identifier.")
    end
    if type(stage.name) ~= "string" or stage.name == "" then
        return invalid("$.name must be a non-empty string.")
    end
    if stage.tempoMap ~= nil then
        return invalid("$.tempoMap is not supported in schemaVersion 3.")
    end
    if not isFiniteNumber(stage.bpm) or stage.bpm <= 0 then
        return invalid("$.bpm must be a positive finite number.")
    end
    if stage.mixtape ~= nil and not isObject(stage.mixtape) then
        return invalid("$.mixtape must be an object.")
    end
    local mixtapeError = MixtapeSettings.validate(stage.mixtape)
    if mixtapeError then return invalid(mixtapeError) end
    if stage.editorSettings ~= nil and not isObject(stage.editorSettings) then
        return invalid("$.editorSettings must be an object.")
    end
    local settingsError = StageSettings.validate(stage.editorSettings)
    if settingsError then return invalid(settingsError) end
    if not isArray(stage.events) then return invalid("$.events must be an array.") end

    local eventIds = {}
    local endCount = 0
    local trackCount = StageSettings.resolve(stage.editorSettings).trackCount
    for index, event in ipairs(stage.events) do
        local eventError = validateEvent(event, index, trackCount)
        if eventError then return invalid(eventError) end
        if eventIds[event.id] then return invalid("$.events[" .. index .. "].id must be unique.") end
        eventIds[event.id] = true
        if event.type == "end" then
            endCount = endCount + 1
            if endCount > 1 then
                return invalid("$.events[" .. index .. "].type allows only one End Event.")
            end
        end
    end
    return true, nil, nil
end

function StageSchema.normalize(stage)
    local valid, message, code = StageSchema.validate(stage)
    if not valid then return nil, message, code end

    local normalized = deepCopy(stage)
    normalized.mixtape = MixtapeSettings.compact(normalized.mixtape)
    normalized.editorSettings = StageSettings.compact(normalized.editorSettings)
    normalizeEmptyEventParams(normalized)
    return normalized, nil, nil
end

function StageSchema.resolveEditorSettings(stage)
    return StageSettings.resolve(stage and stage.editorSettings)
end

return StageSchema
