local ProjectManifest = {}

local IDENTIFIER_PATTERN = "^[A-Za-z0-9_][A-Za-z0-9_%-]*$"

local function invalid(message)
    return nil, message, "INVALID_PROJECT"
end

local function isFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function isArray(value)
    if type(value) ~= "table" then return false end

    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if value[index] == nil then return false end
    end
    return true
end

local function isIdentifier(value)
    return type(value) == "string" and value:match(IDENTIFIER_PATTERN) ~= nil
end

function ProjectManifest.validate(project, options)
    options = options or {}
    if type(project) ~= "table" then
        return invalid("Project manifest must be a table.")
    end

    for _, fieldName in ipairs({ "id", "title", "entryModule" }) do
        if type(project[fieldName]) ~= "string" or project[fieldName] == "" then
            return invalid("Invalid project field: " .. fieldName)
        end
    end

    if options.expectedId ~= nil and project.id ~= options.expectedId then
        return invalid("Project id does not match directory: " .. tostring(options.expectedId))
    end

    if options.expectedCoreApiVersion ~= nil
        and project.coreApiVersion ~= options.expectedCoreApiVersion then
        return invalid(string.format(
            "Core API version mismatch: project=%s, core=%s",
            tostring(project.coreApiVersion),
            tostring(options.expectedCoreApiVersion)
        ))
    end

    local categories = project.eventCategories
    if categories == nil then return true, nil, nil end
    if not isArray(categories) then
        return invalid("eventCategories must be an array.")
    end

    local categoryIds = {}
    for categoryIndex, category in ipairs(categories) do
        if type(category) ~= "table" or not isIdentifier(category.id) then
            return invalid("eventCategories[" .. categoryIndex .. "].id must be an identifier.")
        end
        if categoryIds[category.id] then
            return invalid("Project Event Category ids must be unique.")
        end
        categoryIds[category.id] = true

        if type(category.label) ~= "string" or category.label == "" then
            return invalid("Project Event Category label must be a non-empty string.")
        end
        if category.runtimeModule ~= nil
            and (type(category.runtimeModule) ~= "string" or category.runtimeModule == "") then
            return invalid("Project Event Category runtimeModule must be a non-empty string.")
        end
        if not isArray(category.events) then
            return invalid("Project Event Category events must be an array.")
        end

        local eventIds = {}
        for _, event in ipairs(category.events) do
            if type(event) ~= "table" or not isIdentifier(event.id) then
                return invalid("Project Event id must be an identifier.")
            end
            if eventIds[event.id] then
                return invalid("Project Event ids must be unique within a Category.")
            end
            eventIds[event.id] = true

            if type(event.label) ~= "string" or event.label == "" then
                return invalid("Project Event label must be a non-empty string.")
            end
            if not isArray(event.properties) then
                return invalid("Project Event properties must be an array.")
            end

            local propertyIds = {}
            for _, property in ipairs(event.properties) do
                if type(property) ~= "table"
                    or type(property.id) ~= "string" or property.id == ""
                    or property.kind ~= "number" or not isFinite(property.default)
                    or (property.min ~= nil and not isFinite(property.min))
                    or (property.max ~= nil and not isFinite(property.max)) then
                    return invalid(
                        "Project Event properties require an id, number kind, and finite default."
                    )
                end
                if propertyIds[property.id] then
                    return invalid("Project Event property ids must be unique.")
                end
                propertyIds[property.id] = true
            end
        end
    end

    return true, nil, nil
end

return ProjectManifest
