local Core = require("core")

local ProjectCatalog = {}
ProjectCatalog.__index = ProjectCatalog

local function defaultListDirectory()
    return love.filesystem.getDirectoryItems("projects")
end

local function defaultLoadModule(moduleName)
    return require(moduleName)
end

function ProjectCatalog.new(options)
    options = options or {}
    return setmetatable({
        listDirectory = options.listDirectory or defaultListDirectory,
        loadModule = options.loadModule or defaultLoadModule,
        createGameFactory = options.createGame,
        coreApiVersion = options.coreApiVersion or Core.CORE_API_VERSION,
    }, ProjectCatalog)
end

function ProjectCatalog:getProject(projectId)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(self.loadModule, moduleName)
    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. tostring(projectOrError)
    end

    local valid, validationError, validationCode = Core.ProjectManifest.validate(
        projectOrError,
        {
            expectedId = projectId,
            expectedCoreApiVersion = self.coreApiVersion,
        }
    )
    if not valid then
        return nil, validationError, validationCode
    end

    return projectOrError, nil
end

function ProjectCatalog:listProjects()
    local projects = {}
    local succeeded, entriesOrError = pcall(self.listDirectory)
    if not succeeded then
        return projects, tostring(entriesOrError)
    end

    for _, projectId in ipairs(entriesOrError) do
        local project = self:getProject(projectId)
        if project then
            table.insert(projects, project)
        end
    end

    table.sort(projects, function(left, right)
        return left.title < right.title
    end)

    return projects, nil
end

function ProjectCatalog:createGame(project)
    if type(self.createGameFactory) ~= "function" then
        return nil, "Project game factory is not configured."
    end

    local created, gameOrError, factoryError = pcall(self.createGameFactory, project)
    if not created then
        return nil, "Failed to create game: " .. tostring(gameOrError)
    end

    if type(gameOrError) ~= "table" then
        if factoryError ~= nil then
            return nil, tostring(factoryError)
        end
        return nil, "Game factory must return a table."
    end

    return gameOrError, nil
end

return ProjectCatalog
