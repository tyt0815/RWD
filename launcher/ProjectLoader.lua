local Core = require("core")

local ProjectLoader = {}

function ProjectLoader.loadProject(projectId, expectedCoreApiVersion)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(require, moduleName)

    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. projectOrError
    end

    local valid, validationError, validationCode = Core.ProjectManifest.validate(
        projectOrError,
        {
            expectedId = projectId,
            expectedCoreApiVersion = expectedCoreApiVersion,
        }
    )
    if not valid then
        return nil, validationError, validationCode
    end

    return projectOrError, nil
end

function ProjectLoader.createGame(project, options)
    options = options or {}
    assert(options.stageRepository, "stageRepository is required")
    local succeeded, gameModuleOrError = pcall(require, project.entryModule)

    if not succeeded then
        return nil, "Failed to load game entry module: " .. gameModuleOrError
    end

    if type(gameModuleOrError) ~= "table" or type(gameModuleOrError.new) ~= "function" then
        return nil, "Game entry module must provide new(project)."
    end

    local created, gameOrError = pcall(gameModuleOrError.new, project, {
        stageRepository = options.stageRepository,
        standalone = options.standalone == true,
        transportFactory = options.transportFactory,
        eventHandlers = options.eventHandlers,
    })

    if not created then
        return nil, "Failed to create game: " .. tostring(gameOrError)
    end

    if type(gameOrError) ~= "table" then
        return nil, "Game constructor must return a table."
    end

    return gameOrError, nil
end

return ProjectLoader
