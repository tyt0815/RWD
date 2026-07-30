local ProjectEvents = require("core.ProjectEvents")

local ProjectCategories = {}
local Host = {}
Host.__index = Host

local function defaultListDirectory(path)
    return love.filesystem.getDirectoryItems(path)
end

local function defaultIsFile(path)
    local info = love.filesystem.getInfo(path)
    return info ~= nil and info.type == "file"
end

local function defaultLoadModule(moduleName)
    return require(moduleName)
end

local function shallowCopy(value)
    local copy = {}
    for key, item in pairs(value) do copy[key] = item end
    return copy
end

-- Editor와 Launcher가 같은 manifest를 보도록 game/ 바로 아래의 Category를 찾는다.
-- 이 단계에서는 Definition만 require하고 Runtime과 asset 코드는 절대 로드하지 않는다.
function ProjectCategories.discover(options)
    options = options or {}
    if type(options.directoryPath) ~= "string" or options.directoryPath == ""
        or type(options.modulePrefix) ~= "string" or options.modulePrefix == "" then
        return nil, "Project Category discovery requires directoryPath and modulePrefix."
    end

    local listDirectory = options.listDirectory or defaultListDirectory
    local isFile = options.isFile or defaultIsFile
    local loadModule = options.loadModule or defaultLoadModule
    local listed, entriesOrError = pcall(listDirectory, options.directoryPath)
    if not listed then return nil, "Failed to list Project Categories: " .. tostring(entriesOrError) end

    local entries = entriesOrError
    table.sort(entries)
    local categories = {}
    for _, folderName in ipairs(entries) do
        local definitionPath = options.directoryPath .. "/" .. folderName .. "/Definition.lua"
        if isFile(definitionPath) then
            local moduleName = options.modulePrefix .. "." .. folderName .. ".Definition"
            local loaded, definitionOrError = pcall(loadModule, moduleName)
            if not loaded then
                return nil, "Failed to load Project Category Definition: "
                    .. tostring(definitionOrError)
            end
            if type(definitionOrError) ~= "table" then
                return nil, moduleName .. " must return a Category table."
            end

            local definition = shallowCopy(definitionOrError)
            local runtimePath = options.directoryPath .. "/" .. folderName .. "/Runtime.lua"
            if not isFile(runtimePath) then
                return nil, "Project Category Runtime is missing: " .. runtimePath
            end
            definition.runtimeModule = options.modulePrefix .. "." .. folderName .. ".Runtime"
            local validationError = ProjectEvents.validate({
                eventCategories = { definition },
            })
            if validationError then return nil, validationError end
            table.insert(categories, definition)
        end
    end
    return categories, nil
end

-- 실제 게임 객체를 만들 때만 각 Runtime을 생성한다. Host는 Category 간 구현을 모르고
-- lifecycle과 Project Event occurrence를 소유 Runtime에 전달하는 역할만 한다.
function ProjectCategories.createHost(project, options)
    options = options or {}
    local loadModule = options.loadModule or defaultLoadModule
    local host = setmetatable({
        runtimes = {},
        runtimeOrder = {},
        eventRuntimes = {},
    }, Host)

    for _, category in ipairs(ProjectEvents.getCategories(project)) do
        if category.runtimeModule then
            local loaded, moduleOrError = pcall(loadModule, category.runtimeModule)
            if not loaded then
                return nil, "Failed to load Project Category Runtime: "
                    .. tostring(moduleOrError)
            end
            if type(moduleOrError) ~= "table" or type(moduleOrError.new) ~= "function" then
                return nil, category.runtimeModule .. " must provide new(project, category, options)."
            end
            local created, runtimeOrError = pcall(
                moduleOrError.new,
                project,
                category,
                options.runtimeOptions or {}
            )
            if not created then
                return nil, "Failed to create Project Category Runtime: "
                    .. tostring(runtimeOrError)
            end
            if type(runtimeOrError) ~= "table" then
                return nil, category.runtimeModule .. " constructor must return a table."
            end

            host.runtimes[category.id] = runtimeOrError
            table.insert(host.runtimeOrder, runtimeOrError)
            for _, event in ipairs(category.events or {}) do
                host.eventRuntimes[event.id] = runtimeOrError
            end
        end
    end
    return host, nil
end

function Host:getRuntime(categoryId)
    return self.runtimes[categoryId]
end

local function callEach(self, methodName, ...)
    for _, runtime in ipairs(self.runtimeOrder) do
        local method = runtime[methodName]
        if method then method(runtime, ...) end
    end
end

function Host:setAutoPlay(value)
    callEach(self, "setAutoPlay", value)
end

function Host:startStage(stage, startBeat)
    callEach(self, "startStage", stage, startBeat)
end

-- Definition의 Event ID로 Runtime을 찾으므로 Category를 추가해도 Game의 dispatch 코드는
-- 변경되지 않는다. 등록되지 않은 Event는 조용히 무시하지 않고 즉시 오류로 드러낸다.
function Host:applyOccurrences(occurrences, beat)
    for _, occurrence in ipairs(occurrences) do
        local event = occurrence.event
        if event.type == "projectEvent" then
            local runtime = self.eventRuntimes[event.eventId]
            if not runtime then
                error("Unknown Project Event Runtime: " .. tostring(event.eventId))
            end
            if type(runtime.handleEvent) ~= "function" then
                error("Project Category Runtime must provide handleEvent(event, occurrence, beat).")
            end
            runtime:handleEvent(event, occurrence, beat)
        end
    end
end

function Host:update(deltaTime, beat)
    callEach(self, "update", deltaTime, beat)
end

function Host:keypressed(key, beat)
    callEach(self, "keypressed", key, beat)
end

function Host:keyreleased(key, beat)
    callEach(self, "keyreleased", key, beat)
end

function Host:stop()
    callEach(self, "stop")
end

function Host:draw(width, height)
    callEach(self, "draw", width, height)
end

return ProjectCategories
