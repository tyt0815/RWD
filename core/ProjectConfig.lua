local defaultJson = require("vendor.dkjson")

local ProjectConfig = {}
ProjectConfig.__index = ProjectConfig

local defaultFileSystem = {
    read = function(_, path)
        return love.filesystem.read(path)
    end,
}

function ProjectConfig.new(options)
    options = options or {}
    return setmetatable({
        fileSystem = options.fileSystem or defaultFileSystem,
        json = options.json or defaultJson,
    }, ProjectConfig)
end

-- 캐시하지 않고 호출할 때마다 읽어 Project Play마다 디스크 수정값을 반영한다.
function ProjectConfig:load(path)
    if type(path) ~= "string" or path == "" then
        return nil, "Project config path is required."
    end
    local contents, readError = self.fileSystem:read(path)
    if not contents then
        return nil, "Failed to read Project config: " .. tostring(readError)
    end
    local data, position, decodeError = self.json.decode(
        contents,
        1,
        self.json.null
    )
    if decodeError then return nil, "Invalid Project config JSON: " .. decodeError end
    if contents:sub(position):match("^%s*$") == nil then
        return nil, "Invalid Project config JSON: trailing content."
    end
    if type(data) ~= "table" then
        return nil, "Project config root must be an object."
    end
    return data, nil
end

return ProjectConfig
