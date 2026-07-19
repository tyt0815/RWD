local NativeFileSystem = {}
NativeFileSystem.__index = NativeFileSystem

local function normalizeRoot(rootPath)
    return rootPath:gsub("[\\/]+$", "")
end

local function join(rootPath, relativePath)
    return normalizeRoot(rootPath) .. "/" .. relativePath
end

local function nativeFileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

function NativeFileSystem.new(sourceRoot)
    return setmetatable({
        sourceRoot = sourceRoot or love.filesystem.getSource(),
    }, NativeFileSystem)
end

function NativeFileSystem:list(relativePath)
    local succeeded, itemsOrError = pcall(love.filesystem.getDirectoryItems, relativePath)
    if not succeeded then
        return nil, tostring(itemsOrError)
    end
    return itemsOrError, nil
end

function NativeFileSystem:read(relativePath)
    local contents, sizeOrError = love.filesystem.read(relativePath)
    if not contents then
        return nil, tostring(sizeOrError)
    end
    return contents, nil
end

function NativeFileSystem:exists(relativePath)
    return love.filesystem.getInfo(relativePath, "file") ~= nil
end

function NativeFileSystem:writeAtomic(relativePath, contents)
    if self.sourceRoot:lower():match("%.love$") then
        return nil, "Editor cannot write Stage files inside a packaged .love source."
    end

    local targetPath = join(self.sourceRoot, relativePath)
    local temporaryPath = targetPath .. ".tmp"
    local backupPath = targetPath .. ".bak"
    local file, openError = io.open(temporaryPath, "wb")
    if not file then
        return nil, "Failed to open temporary Stage file: " .. tostring(openError)
    end
    local wrote, writeError = file:write(contents)
    local closed, closeError = file:close()
    if not wrote or not closed then
        os.remove(temporaryPath)
        return nil, "Failed to write temporary Stage file: " .. tostring(writeError or closeError)
    end

    local hadTarget = nativeFileExists(targetPath)
    if hadTarget then
        os.remove(backupPath)
        local backedUp, backupError = os.rename(targetPath, backupPath)
        if not backedUp then
            os.remove(temporaryPath)
            return nil, "Failed to back up Stage file: " .. tostring(backupError)
        end
    end

    local replaced, replaceError = os.rename(temporaryPath, targetPath)
    if not replaced then
        if hadTarget then
            os.rename(backupPath, targetPath)
        end
        os.remove(temporaryPath)
        return nil, "Failed to replace Stage file: " .. tostring(replaceError)
    end
    if hadTarget then
        os.remove(backupPath)
    end
    return true, nil
end

return NativeFileSystem
