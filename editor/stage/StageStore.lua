local jsonDefault = require("vendor.dkjson")
local NativeFileSystem = require("editor.stage.NativeFileSystem")
local StageDocument = require("editor.stage.StageDocument")

local StageStore = {}
StageStore.__index = StageStore
StageStore.ERROR_STAGE_EXISTS = "STAGE_EXISTS"

local JSON_KEY_ORDER = {
    "schemaVersion", "projectId", "stageId", "name", "bpm",
    "mixtape", "editorSettings", "events",
    "music", "volume", "beat0Offset",
    "snap", "scale", "playbackRate", "metronome", "metronomePeriod",
    "onsetThreshold", "previewAspectWidth", "previewAspectHeight",
    "id", "startBeat", "type", "categoryId", "eventId", "patternId", "params", "durationBeats",
    "responseDelayBeats",
}

local function validateId(value, fieldName)
    if not StageDocument.isSafeId(value) then
        return nil, "$.'" .. fieldName .. "' must be a safe identifier."
    end
    return true, nil
end

local function stageDirectory(projectId)
    return "projects/" .. projectId .. "/stages"
end

local function stagePath(projectId, stageId)
    return stageDirectory(projectId) .. "/" .. stageId .. ".json"
end

function StageStore.new(fileSystem, json)
    return setmetatable({
        fileSystem = fileSystem or NativeFileSystem.new(),
        json = json or jsonDefault,
    }, StageStore)
end

function StageStore:listStages(projectId)
    local valid, validationError = validateId(projectId, "projectId")
    if not valid then
        return nil, validationError
    end
    local items, listError = self.fileSystem:list(stageDirectory(projectId))
    if not items then
        return nil, "Failed to list Stage files: " .. tostring(listError)
    end
    local stageIds = {}
    for _, fileName in ipairs(items) do
        local stageId = fileName:match("^([a-z0-9][a-z0-9_-]*)%.json$")
        local relativePath = stageDirectory(projectId) .. "/" .. fileName
        if stageId and StageDocument.isSafeId(stageId) and self.fileSystem:isFile(relativePath) then
            table.insert(stageIds, stageId)
        end
    end
    table.sort(stageIds)
    return stageIds, nil
end

function StageStore:stageExists(projectId, stageId)
    local validProject, projectError = validateId(projectId, "projectId")
    if not validProject then return nil, projectError end
    local validStage, stageError = validateId(stageId, "stageId")
    if not validStage then return nil, stageError end
    return self.fileSystem:exists(stagePath(projectId, stageId)), nil
end

function StageStore:load(projectId, stageId)
    local exists, existsError = self:stageExists(projectId, stageId)
    if exists == nil then return nil, existsError end
    if not exists then return nil, "Stage file does not exist: " .. stageId end
    local contents, readError = self.fileSystem:read(stagePath(projectId, stageId))
    if not contents then return nil, "Failed to read Stage: " .. tostring(readError) end
    local data, position, decodeError = self.json.decode(contents, 1, self.json.null)
    if decodeError then return nil, "Invalid JSON: " .. decodeError end
    if contents:sub(position):match("^%s*$") == nil then
        return nil, "Invalid JSON: trailing content."
    end
    local validationError = StageDocument.validate(data)
    if validationError then return nil, validationError end
    if data.projectId ~= projectId then
        return nil, "$.projectId must match selected Project."
    end
    if data.stageId ~= stageId then
        return nil, "$.stageId must match the file name."
    end
    return data, nil
end

function StageStore:save(data, overwrite)
    local document, validationError = StageDocument.fromTable(data)
    if not document then return nil, validationError end
    local path = stagePath(data.projectId, data.stageId)
    if self.fileSystem:exists(path) and not overwrite then
        return nil, "Stage already exists: " .. data.stageId, StageStore.ERROR_STAGE_EXISTS
    end
    local encoded, encodeError
    local succeeded, valueOrError = pcall(self.json.encode, document:toTable(), {
        indent = true,
        keyorder = JSON_KEY_ORDER,
    })
    if succeeded then encoded = valueOrError else encodeError = valueOrError end
    if not encoded then return nil, "Failed to encode Stage: " .. tostring(encodeError) end
    local written, writeError = self.fileSystem:writeAtomic(path, encoded .. "\n")
    if not written then return nil, "Failed to save Stage: " .. tostring(writeError) end
    return true, nil
end

return StageStore
