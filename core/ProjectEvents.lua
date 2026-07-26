local ProjectEvents = {}

local function isFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function ProjectEvents.validate(project)
    local categories = project and project.eventCategories
    if categories == nil then return nil end
    if type(categories) ~= "table" then return "eventCategories must be an array." end
    local categoryIds = {}
    local eventIds = {}
    for categoryIndex, category in ipairs(categories) do
        if type(category.id) ~= "string" or category.id == "" then
            return "eventCategories[" .. categoryIndex .. "].id must be a non-empty string."
        end
        if categoryIds[category.id] then return "Project Event Category ids must be unique." end
        categoryIds[category.id] = true
        if type(category.label) ~= "string" or category.label == "" then
            return "Project Event Category label must be a non-empty string."
        end
        if type(category.events) ~= "table" then
            return "Project Event Category events must be an array."
        end
        for _, event in ipairs(category.events) do
            if type(event.id) ~= "string" or event.id == "" then
                return "Project Event id must be a non-empty string."
            end
            if eventIds[event.id] then return "Project Event ids must be unique." end
            eventIds[event.id] = true
            if type(event.label) ~= "string" or event.label == "" then
                return "Project Event label must be a non-empty string."
            end
            for _, property in ipairs(event.properties or {}) do
                if type(property.id) ~= "string" or property.id == ""
                    or property.kind ~= "number" or not isFinite(property.default) then
                    return "Project Event properties require an id, number kind, and finite default."
                end
            end
        end
    end
    return nil
end

function ProjectEvents.getCategories(project)
    return project and project.eventCategories or {}
end

function ProjectEvents.getEvent(project, eventId)
    for _, category in ipairs(ProjectEvents.getCategories(project)) do
        for _, event in ipairs(category.events or {}) do
            if event.id == eventId then return event end
        end
    end
    return nil
end

function ProjectEvents.getDefaultParams(definition)
    local params = {}
    for _, property in ipairs(definition and definition.properties or {}) do
        params[property.id] = property.default
    end
    return params
end

function ProjectEvents.validateParams(definition, params)
    if not definition then return "Unknown Project Event." end
    params = params or {}
    local known = {}
    for _, property in ipairs(definition.properties or {}) do
        known[property.id] = true
        local value = params[property.id]
        if property.kind == "number" then
            if not isFinite(value) then
                return property.id .. " must be a finite number."
            end
            if property.min ~= nil and value < property.min then
                return property.id .. " must be at least " .. tostring(property.min) .. "."
            end
            if property.max ~= nil and value > property.max then
                return property.id .. " must be at most " .. tostring(property.max) .. "."
            end
        end
    end
    for key in pairs(params) do
        if not known[key] then return "Unknown Project Event property: " .. tostring(key) end
    end
    return nil
end

return ProjectEvents
