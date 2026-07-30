local Core = require("core")

local PropertyCatalog = {}

local CATEGORIES = {
    {
        id = "global",
        label = "Global",
        events = {
            {
                id = "editorProperties",
                label = "Editor Properties",
                properties = {
                    { id = "snap", label = "Snap", kind = "number" },
                    { id = "scale", label = "Scale", kind = "number" },
                    { id = "playbackRate", label = "Playback Rate", kind = "number" },
                    { id = "autoPlay", label = "Auto Play", kind = "choice" },
                    { id = "metronome", label = "Metronome", kind = "boolean" },
                    { id = "metronomePeriod", label = "Metronome Period", kind = "number" },
                    { id = "trackCount", label = "Track", kind = "number" },
                    { id = "previewAspectWidth", label = "Preview Aspect Width", kind = "number" },
                    { id = "previewAspectHeight", label = "Preview Aspect Height", kind = "number" },
                },
            },
            {
                id = "mixtapeProperties",
                label = "Mixtape Properties",
                properties = {
                    { id = "music", label = "Music", kind = "music" },
                    { id = "volume", label = "Volume", kind = "number" },
                    { id = "beat0Offset", label = "Beat 0 Offset", kind = "number" },
                    { id = "onsetThreshold", label = "Onset Threshold", kind = "number", groupId = "editorProperties" },
                    { id = "bpm", label = "BPM", kind = "number" },
                },
            },
        },
    },
    {
        id = "gameManager",
        label = "Game Manager",
        events = {
            {
                id = "end", label = "End", timelineType = "end",
                color = { 0.68, 0.32, 0.9, 1 }, properties = {},
            },
            {
                id = "setInputEnabled", label = "Set Input Enabled",
                timelineType = "setInputEnabled",
                color = { 0.12, 0.72, 0.62, 1 },
                properties = {
                    { id = "enabled", label = "Enabled", kind = "boolean" },
                },
                nodeProperties = {
                    { id = "enabled", label = "Enabled", kind = "boolean" },
                },
            },
        },
    },
}

local function copyProperties(properties)
    local result = {}
    for _, property in ipairs(properties or {}) do
        table.insert(result, {
            id = property.id,
            label = property.label,
            kind = property.kind,
            groupId = property.groupId,
            default = property.default,
            min = property.min,
            max = property.max,
        })
    end
    return result
end

local function copyEvent(event, isProjectEvent, categoryId)
    local color
    if event.color then color = { event.color[1], event.color[2], event.color[3], event.color[4] } end
    local properties = copyProperties(event.properties)
    return {
        id = event.id,
        label = event.label,
        timelineType = isProjectEvent
            and ("project:" .. categoryId .. ":" .. event.id) or event.timelineType,
        projectCategoryId = isProjectEvent and categoryId or nil,
        projectEventId = isProjectEvent and event.id or nil,
        color = color,
        properties = properties,
        nodeProperties = copyProperties(event.nodeProperties or (isProjectEvent and event.properties)),
        singleton = event.singleton == true,
        geometry = event.geometry,
    }
end

local function eachCategory(project, callback)
    for _, category in ipairs(CATEGORIES) do callback(category, false) end
    for _, category in ipairs(Core.ProjectEvents.getCategories(project)) do
        callback(category, true)
    end
end

function PropertyCatalog.getCategories(project)
    local categories = {}
    eachCategory(project, function(category)
        table.insert(categories, { id = category.id, label = category.label })
    end)
    return categories
end

function PropertyCatalog.getEvents(categoryId, project)
    categoryId = categoryId or "global"
    local result = {}
    eachCategory(project, function(category, isProject)
        if category.id == categoryId then
            for _, event in ipairs(category.events or {}) do
                table.insert(result, copyEvent(event, isProject, category.id))
            end
        end
    end)
    return result
end

function PropertyCatalog.getEvent(categoryId, eventId, project)
    local found
    eachCategory(project, function(category, isProject)
        if category.id == categoryId then
            for _, event in ipairs(category.events or {}) do
                if event.id == eventId then
                    found = copyEvent(event, isProject, category.id)
                end
            end
        end
    end)
    return found
end

function PropertyCatalog.getTimelineEvent(event, project)
    local eventType = type(event) == "table" and event.type or event
    local projectCategoryId = type(event) == "table" and event.categoryId or nil
    local projectEventId = type(event) == "table" and event.eventId or nil
    if eventType == "projectEvent" then
        local definition = Core.ProjectEvents.getEvent(
            project,
            projectCategoryId,
            projectEventId
        )
        return definition
            and copyEvent(definition, true, projectCategoryId) or nil
    end
    local found
    eachCategory(nil, function(category)
        for _, definition in ipairs(category.events or {}) do
            if definition.timelineType == eventType then
                found = copyEvent(definition, false, category.id)
            end
        end
    end)
    return found
end

return PropertyCatalog
