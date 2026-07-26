local Core = require("core")

local ProjectLoader = {}

local function validateProject(project, expectedCoreApiVersion)
    if type(project) ~= "table" then
        return "Project manifest must be a table."
    end

    local requiredStringFields = { "id", "title", "entryModule" }
    for _, fieldName in ipairs(requiredStringFields) do
        if type(project[fieldName]) ~= "string" or project[fieldName] == "" then
            return "Invalid project field: " .. fieldName
        end
    end

    if project.coreApiVersion ~= expectedCoreApiVersion then
        return string.format(
            "Core API version mismatch: project=%s, core=%s",
            tostring(project.coreApiVersion),
            tostring(expectedCoreApiVersion)
        )
    end

    return Core.ProjectEvents.validate(project)
end

function ProjectLoader.loadProject(projectId, coreApiVersion)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(require, moduleName)

    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. projectOrError
    end

    local validationError = validateProject(projectOrError, coreApiVersion)
    if validationError then
        return nil, validationError
    end

    return projectOrError, nil
end

function ProjectLoader.createGame(project)
    local succeeded, gameModuleOrError = pcall(require, project.entryModule)

    if not succeeded then
        return nil, "Failed to load game entry module: " .. gameModuleOrError
    end

    if type(gameModuleOrError) ~= "table" or type(gameModuleOrError.new) ~= "function" then
        return nil, "Game entry module must provide new(project)."
    end

    local created, gameOrError = pcall(gameModuleOrError.new, project)

    if not created then
        return nil, "Failed to create game: " .. tostring(gameOrError)
    end

    if type(gameOrError) ~= "table" then
        return nil, "Game constructor must return a table."
    end

    return gameOrError, nil
end

return ProjectLoader
