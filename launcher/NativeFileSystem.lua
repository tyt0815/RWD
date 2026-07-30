local NativeFileSystem = {}
NativeFileSystem.__index = NativeFileSystem

local PACKAGED_WRITE_ERROR = "Cannot write Stage files inside a packaged .love source."

local function normalizeRoot(rootPath)
    return rootPath:gsub("[\\/]+$", "")
end

local function join(rootPath, relativePath)
    return normalizeRoot(rootPath) .. "/" .. relativePath
end

local function nativeFileExists(path)
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
end

local function readFile(path)
    local file, openError = io.open(path, "rb")
    if not file then return nil, tostring(openError) end
    local contents, readError = file:read("*a")
    local closed, closeError = file:close()
    if not contents or not closed then
        return nil, tostring(readError or closeError)
    end
    return contents, nil
end

local function writeFile(path, contents)
    local file, openError = io.open(path, "wb")
    if not file then return nil, tostring(openError) end
    local wrote, writeError = file:write(contents)
    local closed, closeError = file:close()
    if not wrote or not closed then
        return nil, tostring(writeError or closeError)
    end
    return true, nil
end

local function copyFile(sourcePath, targetPath)
    local contents, readError = readFile(sourcePath)
    if not contents then return nil, readError end
    return writeFile(targetPath, contents)
end

local NATIVE_OPERATIONS = {}

function NATIVE_OPERATIONS:list(path)
    local succeeded, itemsOrError = pcall(love.filesystem.getDirectoryItems, path)
    if not succeeded then return nil, tostring(itemsOrError) end
    return itemsOrError, nil
end

function NATIVE_OPERATIONS:read(path)
    return readFile(path)
end

function NATIVE_OPERATIONS:isFile(path)
    return nativeFileExists(path)
end

function NATIVE_OPERATIONS:exists(path)
    return nativeFileExists(path)
end

function NATIVE_OPERATIONS:write(path, contents)
    return writeFile(path, contents)
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

local function isPackaged(sourceRoot)
    return sourceRoot:lower():match("%.love$") ~= nil
end

function NativeFileSystem.new(sourceRoot, operations)
    return setmetatable({
        sourceRoot = normalizeRoot(sourceRoot or love.filesystem.getSource()),
        operations = operations or NATIVE_OPERATIONS,
    }, NativeFileSystem)
end

function NativeFileSystem:list(relativePath)
    if not isPackaged(self.sourceRoot) then
        return self.operations:list(join(self.sourceRoot, relativePath))
    end
    local succeeded, itemsOrError = pcall(love.filesystem.getDirectoryItems, relativePath)
    if not succeeded then return nil, tostring(itemsOrError) end
    return itemsOrError, nil
end

function NativeFileSystem:read(relativePath)
    if not isPackaged(self.sourceRoot) then
        return self.operations:read(join(self.sourceRoot, relativePath))
    end
    local contents, sizeOrError = love.filesystem.read(relativePath)
    if not contents then return nil, tostring(sizeOrError) end
    return contents, nil
end

function NativeFileSystem:isFile(relativePath)
    if not isPackaged(self.sourceRoot) then
        return self.operations:isFile(join(self.sourceRoot, relativePath))
    end
    return love.filesystem.getInfo(relativePath, "file") ~= nil
end

function NativeFileSystem:exists(relativePath)
    if not isPackaged(self.sourceRoot) then
        return self.operations:exists(join(self.sourceRoot, relativePath))
    end
    return love.filesystem.getInfo(relativePath, "file") ~= nil
end

function NativeFileSystem:write(relativePath, contents)
    if isPackaged(self.sourceRoot) then return nil, PACKAGED_WRITE_ERROR end
    return self.operations:write(join(self.sourceRoot, relativePath), contents)
end

function NativeFileSystem:remove(relativePath)
    if isPackaged(self.sourceRoot) then return nil, PACKAGED_WRITE_ERROR end
    return self.operations:remove(join(self.sourceRoot, relativePath))
end

function NativeFileSystem:rename(sourcePath, targetPath)
    if isPackaged(self.sourceRoot) then return nil, PACKAGED_WRITE_ERROR end
    return self.operations:rename(
        join(self.sourceRoot, sourcePath),
        join(self.sourceRoot, targetPath)
    )
end

function NativeFileSystem:copy(sourcePath, targetPath)
    if isPackaged(self.sourceRoot) then return nil, PACKAGED_WRITE_ERROR end
    return self.operations:copy(
        join(self.sourceRoot, sourcePath),
        join(self.sourceRoot, targetPath)
    )
end

return NativeFileSystem
