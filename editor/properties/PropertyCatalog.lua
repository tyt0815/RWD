local PropertyCatalog = {}

local EVENTS = {
    {
        id = "editorProperties",
        label = "Editor Properties",
        properties = {
            { id = "scale", label = "Scale", kind = "number" },
            { id = "playbackRate", label = "Playback Rate", kind = "number" },
            { id = "metronome", label = "Metronome", kind = "boolean" },
            { id = "metronomePeriod", label = "Metronome Period", kind = "number" },
        },
    },
    {
        id = "mixtapeProperties",
        label = "Mixtape Properties",
        properties = {
            { id = "music", label = "Music", kind = "music" },
            { id = "volume", label = "Volume", kind = "number" },
            { id = "beat0Offset", label = "Beat 0 Offset", kind = "number" },
            { id = "bpm", label = "BPM", kind = "number" },
        },
    },
}

local function copyEvent(event)
    local properties = {}
    for _, property in ipairs(event.properties) do
        table.insert(properties, {
            id = property.id,
            label = property.label,
            kind = property.kind,
        })
    end
    return {
        id = event.id,
        label = event.label,
        properties = properties,
    }
end

function PropertyCatalog.getEvents()
    local events = {}
    for _, event in ipairs(EVENTS) do
        table.insert(events, copyEvent(event))
    end
    return events
end

function PropertyCatalog.getEvent(eventId)
    for _, event in ipairs(EVENTS) do
        if event.id == eventId then return copyEvent(event) end
    end
    return nil
end

return PropertyCatalog
