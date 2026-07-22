local MusicCatalog = {}
MusicCatalog.__index = MusicCatalog

local SUPPORTED_EXTENSIONS = {
    ogg = true,
    mp3 = true,
    wav = true,
}

local function defaultGetInfo(path)
    return love.filesystem.getInfo(path)
end

local function defaultListDirectory(path)
    return love.filesystem.getDirectoryItems(path)
end

local function defaultValidateProjectId(projectId)
    return type(projectId) == "string"
        and projectId:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
end

local function filesystemError(errorMessage)
    return "Failed to list Project music: " .. tostring(errorMessage)
end

function MusicCatalog.new(options)
    options = options or {}
    return setmetatable({
        getInfo = options.getInfo or defaultGetInfo,
        listDirectory = options.listDirectory or defaultListDirectory,
        validateProjectId = options.validateProjectId or defaultValidateProjectId,
    }, MusicCatalog)
end

function MusicCatalog:list(projectId)
    if not self.validateProjectId(projectId) then
        return nil, "Invalid Project id."
    end

    local rootPath = "projects/" .. projectId .. "/assets/audio"
    local infoSucceeded, rootInfo = pcall(self.getInfo, rootPath)
    if not infoSucceeded then
        return nil, filesystemError(rootInfo)
    end
    if not rootInfo or rootInfo.type ~= "directory" then
        return {}, nil
    end

    local files = {}
    local function walk(directoryPath, relativePath)
        local listSucceeded, entries = pcall(self.listDirectory, directoryPath)
        if not listSucceeded then
            return nil, filesystemError(entries)
        end
        if type(entries) ~= "table" then
            return nil, filesystemError("directory listing must be a table")
        end

        for _, entry in ipairs(entries) do
            local childPath = directoryPath .. "/" .. entry
            local childRelativePath = relativePath .. "/" .. entry
            local infoSucceeded, childInfo = pcall(self.getInfo, childPath)
            if not infoSucceeded then
                return nil, filesystemError(childInfo)
            end

            if childInfo and childInfo.type == "directory" then
                local walked, errorMessage = walk(childPath, childRelativePath)
                if not walked then return nil, errorMessage end
            elseif childInfo and childInfo.type == "file" then
                local extension = entry:match("%.([^%.]+)$")
                if extension and SUPPORTED_EXTENSIONS[extension:lower()] then
                    table.insert(files, childRelativePath)
                end
            end
        end

        return true, nil
    end

    local walked, errorMessage = walk(rootPath, "assets/audio")
    if not walked then return nil, errorMessage end

    table.sort(files)
    return files, nil
end

return MusicCatalog
