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
                    { id = "metronome", label = "Metronome", kind = "boolean" },
                    { id = "metronomePeriod", label = "Metronome Period", kind = "number" },
                    { id = "trackCount", label = "Track", kind = "number" },
                },
            },
            {
                id = "mixtapeProperties",
                label = "Mixtape Properties",
                properties = {
                    { id = "music", label = "Music", kind = "music" },
                    { id = "volume", label = "Volume", kind = "number" },
                    { id = "beat0Offset", label = "Beat 0 Offset", kind = "number" },
                    {
                        id = "onsetThreshold",
                        label = "Onset Threshold",
                        kind = "number",
                        groupId = "editorProperties",
                    },
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
                id = "end",
                label = "End",
                timelineType = "end",
                color = { 0.68, 0.32, 0.9, 1 },
                properties = {},
            },
            {
                id = "setInputEnabled",
                label = "Set Input Enabled",
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
        })
    end
    return result
end

local function copyEvent(event)
    local color
    if event.color then
        color = { event.color[1], event.color[2], event.color[3], event.color[4] }
    end
    return {
        id = event.id,
        label = event.label,
        timelineType = event.timelineType,
        color = color,
        properties = copyProperties(event.properties),
        nodeProperties = copyProperties(event.nodeProperties),
    }
end

function PropertyCatalog.getCategories()
    local categories = {}
    for _, category in ipairs(CATEGORIES) do
        table.insert(categories, { id = category.id, label = category.label })
    end
    return categories
end

function PropertyCatalog.getEvents(categoryId)
    categoryId = categoryId or "global"
    for _, category in ipairs(CATEGORIES) do
        if category.id == categoryId then
            local events = {}
            for _, event in ipairs(category.events) do
                table.insert(events, copyEvent(event))
            end
            return events
        end
    end
    return {}
end

function PropertyCatalog.getEvent(eventId)
    for _, category in ipairs(CATEGORIES) do
        for _, event in ipairs(category.events) do
            if event.id == eventId then return copyEvent(event) end
        end
    end
    return nil
end

function PropertyCatalog.getTimelineEvent(eventType)
    for _, category in ipairs(CATEGORIES) do
        for _, event in ipairs(category.events) do
            if event.timelineType == eventType then return copyEvent(event) end
        end
    end
    return nil
end

return PropertyCatalog
