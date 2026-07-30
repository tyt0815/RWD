local StageSchema = require("core.StageSchema")

local StageRepository = {}
StageRepository.__index = StageRepository

local JSON_KEY_ORDER = {
    "schemaVersion", "projectId", "stageId", "name", "bpm",
    "mixtape", "editorSettings", "events",
    "music", "volume", "beat0Offset",
    "snap", "scale", "playbackRate", "metronome", "metronomePeriod",
    "onsetThreshold", "previewAspectWidth", "previewAspectHeight",
    "id", "startBeat", "type", "categoryId", "eventId", "patternId",
    "params", "durationBeats", "responseDelayBeats",
}

local function invalidId(fieldName)
    return nil, "$." .. fieldName .. " must be a safe identifier.", "INVALID_STAGE"
end

local function validateId(value, fieldName)
    if not StageSchema.isSafeId(value) then
        return invalidId(fieldName)
    end
    return true, nil, nil
end

local function readFailure(action, message)
    return nil, "Failed to " .. action .. ": " .. tostring(message), "READ_FAILED"
end

local function writeFailure(action, message)
    return nil, "Failed to " .. action .. ": " .. tostring(message), "WRITE_FAILED"
end

function StageRepository.new(options)
    options = options or {}
    assert(type(options.fileSystem) == "table", "fileSystem is required")
    assert(type(options.paths) == "table", "paths is required")
    assert(type(options.paths.stageDirectory) == "function", "paths.stageDirectory is required")
    assert(type(options.paths.stageFile) == "function", "paths.stageFile is required")
    assert(type(options.json) == "table", "json is required")
    assert(type(options.json.decode) == "function", "json.decode is required")
    assert(type(options.json.encode) == "function", "json.encode is required")

    return setmetatable({
        fileSystem = options.fileSystem,
        paths = options.paths,
        json = options.json,
    }, StageRepository)
end

function StageRepository:listStages(projectId)
    local valid, message, code = validateId(projectId, "projectId")
    if not valid then return nil, message, code end

    local directory = self.paths.stageDirectory(projectId)
    local items, listError = self.fileSystem:list(directory)
    if not items then return readFailure("list Stage files", listError) end

    local stageIds = {}
    for _, fileName in ipairs(items) do
        local stageId = fileName:match("^([a-z0-9][a-z0-9_-]*)%.json$")
        if stageId
            and StageSchema.isSafeId(stageId)
            and self.fileSystem:isFile(directory .. "/" .. fileName) then
            table.insert(stageIds, stageId)
        end
    end
    table.sort(stageIds)
    return stageIds, nil, nil
end

function StageRepository:stageExists(projectId, stageId)
    local validProject, projectMessage, projectCode = validateId(projectId, "projectId")
    if not validProject then return nil, projectMessage, projectCode end
    local validStage, stageMessage, stageCode = validateId(stageId, "stageId")
    if not validStage then return nil, stageMessage, stageCode end

    local exists, existsError = self.fileSystem:exists(self.paths.stageFile(projectId, stageId))
    if exists == nil then return readFailure("check Stage file", existsError) end
    return exists, nil, nil
end

function StageRepository:load(projectId, stageId)
    local exists, existsMessage, existsCode = self:stageExists(projectId, stageId)
    if exists == nil then return nil, existsMessage, existsCode end
    if not exists then
        return nil, "Stage file does not exist: " .. stageId, "NOT_FOUND"
    end

    local path = self.paths.stageFile(projectId, stageId)
    local contents, readError = self.fileSystem:read(path)
    if not contents then return readFailure("read Stage", readError) end

    local decoded, position, decodeError
    local succeeded, first, second, third = pcall(self.json.decode, contents, 1, self.json.null)
    if succeeded then
        decoded, position, decodeError = first, second, third
    else
        decodeError = first
    end
    if not succeeded or decodeError then
        return nil, "Invalid JSON: " .. tostring(decodeError), "DECODE_FAILED"
    end
    if type(position) ~= "number" or contents:sub(position):match("^%s*$") == nil then
        return nil, "Invalid JSON: trailing content.", "DECODE_FAILED"
    end

    local normalized, normalizeMessage, normalizeCode = StageSchema.normalize(decoded)
    if not normalized then return nil, normalizeMessage, normalizeCode end
    if normalized.projectId ~= projectId then
        return nil, "$.projectId must match selected Project.", "INVALID_STAGE"
    end
    if normalized.stageId ~= stageId then
        return nil, "$.stageId must match the file name.", "INVALID_STAGE"
    end
    return normalized, nil, nil
end

function StageRepository:save(stage, overwrite)
    local normalized, normalizeMessage, normalizeCode = StageSchema.normalize(stage)
    if not normalized then return nil, normalizeMessage, normalizeCode end

    local path = self.paths.stageFile(normalized.projectId, normalized.stageId)
    local exists, existsError = self.fileSystem:exists(path)
    if exists == nil then return readFailure("check Stage file", existsError) end
    if exists and not overwrite then
        return nil, "Stage already exists: " .. normalized.stageId, "STAGE_EXISTS"
    end

    local encoded
    local succeeded, encodedOrError, encodeError = pcall(self.json.encode, normalized, {
        indent = true,
        keyorder = JSON_KEY_ORDER,
    })
    if succeeded then encoded = encodedOrError end
    if not succeeded or type(encoded) ~= "string" then
        return writeFailure("encode Stage", succeeded and encodeError or encodedOrError)
    end

    local temporaryPath = path .. ".tmp"
    local backupPath = path .. ".bak"
    local wrote, writeError = self.fileSystem:write(temporaryPath, encoded .. "\n")
    if not wrote then
        self.fileSystem:remove(temporaryPath)
        return writeFailure("write temporary Stage file", writeError)
    end

    if exists then
        local backedUp, backupError = self.fileSystem:rename(path, backupPath)
        if not backedUp then
            self.fileSystem:remove(temporaryPath)
            return writeFailure("back up Stage file", backupError)
        end
    end

    local replaced, replaceError = self.fileSystem:rename(temporaryPath, path)
    if replaced then
        if exists then self.fileSystem:remove(backupPath) end
        return true, nil, nil
    end

    self.fileSystem:remove(temporaryPath)
    if not exists then return writeFailure("replace Stage file", replaceError) end

    local restored, restoreError = self.fileSystem:rename(backupPath, path)
    if restored then return writeFailure("replace Stage file", replaceError) end

    local copied, copyError = self.fileSystem:copy(backupPath, path)
    if copied then
        self.fileSystem:remove(backupPath)
        return nil, "Failed to replace Stage file: " .. tostring(replaceError)
            .. "; original restored by copy after rollback rename failed: "
            .. tostring(restoreError), "WRITE_FAILED"
    end

    return nil, "Failed to replace Stage file: " .. tostring(replaceError)
        .. "; failed to restore original Stage file from retained backup '"
        .. backupPath .. "': rollback rename failed: " .. tostring(restoreError)
        .. "; copy fallback failed: " .. tostring(copyError), "WRITE_FAILED"
end

return StageRepository
