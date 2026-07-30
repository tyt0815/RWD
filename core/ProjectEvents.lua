local ProjectEvents = {}

local function isFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function ProjectEvents.getCategories(project)
    return project and project.eventCategories or {}
end

function ProjectEvents.getEvent(project, categoryId, eventId)
    for _, category in ipairs(ProjectEvents.getCategories(project)) do
        if category.id == categoryId then
            for _, event in ipairs(category.events or {}) do
                if event.id == eventId then return event end
            end
            return nil
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
