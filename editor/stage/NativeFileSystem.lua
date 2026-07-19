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

local function writeFile(path, contents)
    local file, openError = io.open(path, "wb")
    if not file then
        return nil, tostring(openError)
    end
    local wrote, writeError = file:write(contents)
    local closed, closeError = file:close()
    if not wrote or not closed then
        return nil, tostring(writeError or closeError)
    end
    return true, nil
end

local function copyFile(sourcePath, targetPath)
    local sourceFile, openError = io.open(sourcePath, "rb")
    if not sourceFile then
        return nil, tostring(openError)
    end
    local contents, readError = sourceFile:read("*a")
    local closed, closeError = sourceFile:close()
    if not contents or not closed then
        return nil, tostring(readError or closeError)
    end
    return writeFile(targetPath, contents)
end

local NATIVE_OPERATIONS = {}

function NATIVE_OPERATIONS:write(path, contents)
    return writeFile(path, contents)
end

function NATIVE_OPERATIONS:exists(path)
    return nativeFileExists(path)
end

function NATIVE_OPERATIONS:remove(path)
    return os.remove(path)
end

function NATIVE_OPERATIONS:rename(sourcePath, targetPath)
    return os.rename(sourcePath, targetPath)
end

function NATIVE_OPERATIONS:copy(sourcePath, targetPath)
    return copyFile(sourcePath, targetPath)
end

function NativeFileSystem.new(sourceRoot, operations)
    return setmetatable({
        sourceRoot = sourceRoot or love.filesystem.getSource(),
        operations = operations or NATIVE_OPERATIONS,
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

function NativeFileSystem:isFile(relativePath)
    return love.filesystem.getInfo(relativePath, "file") ~= nil
end

function NativeFileSystem:exists(relativePath)
    return self:isFile(relativePath)
end

function NativeFileSystem:writeAtomic(relativePath, contents)
    if self.sourceRoot:lower():match("%.love$") then
        return nil, "Editor cannot write Stage files inside a packaged .love source."
    end

    local targetPath = join(self.sourceRoot, relativePath)
    local temporaryPath = targetPath .. ".tmp"
    local backupPath = targetPath .. ".bak"
    local wrote, writeError = self.operations:write(temporaryPath, contents)
    if not wrote then
        self.operations:remove(temporaryPath)
        return nil, "Failed to write temporary Stage file: " .. tostring(writeError)
    end

    local hadTarget = self.operations:exists(targetPath)
    if hadTarget then
        self.operations:remove(backupPath)
        local backedUp, backupError = self.operations:rename(targetPath, backupPath)
        if not backedUp then
            self.operations:remove(temporaryPath)
            return nil, "Failed to back up Stage file: " .. tostring(backupError)
        end
    end

    local replaced, replaceError = self.operations:rename(temporaryPath, targetPath)
    if not replaced then
        self.operations:remove(temporaryPath)
        if not hadTarget then
            return nil, "Failed to replace Stage file: " .. tostring(replaceError)
        end

        local restored, restoreError = self.operations:rename(backupPath, targetPath)
        if restored then
            return nil, "Failed to replace Stage file: " .. tostring(replaceError)
        end

        local copied, copyError = self.operations:copy(backupPath, targetPath)
        if copied then
            self.operations:remove(backupPath)
            return nil, "Failed to replace Stage file: " .. tostring(replaceError)
                .. "; original restored by copy after rollback rename failed: "
                .. tostring(restoreError)
        end

        self.operations:remove(targetPath)
        return nil, "Failed to replace Stage file: " .. tostring(replaceError)
            .. "; failed to restore original Stage file from retained backup '"
            .. backupPath .. "': rollback rename failed: " .. tostring(restoreError)
            .. "; copy fallback failed: " .. tostring(copyError)
    end
    if hadTarget then
        self.operations:remove(backupPath)
    end
    return true, nil
end

return NativeFileSystem
