local TimelineEventGeometry = {}

local DEFAULT_GAMEPLAY_WIDTH_BEATS = 1
local NON_RHYTHMIC_WIDTHS = {
    ["end"] = 0.25,
    setInputEnabled = 0.25,
}

function TimelineEventGeometry.getWidthBeats(event)
    local width = event.widthBeats or event.durationBeats
    if type(width) == "number" and width > 0 then return width end
    return NON_RHYTHMIC_WIDTHS[event.type] or DEFAULT_GAMEPLAY_WIDTH_BEATS
end

local function eventsOverlap(first, second)
    if first.track ~= second.track then return false end
    local firstEnd = first.startBeat
        + TimelineEventGeometry.getWidthBeats(first)
    local secondEnd = second.startBeat
        + TimelineEventGeometry.getWidthBeats(second)
    return first.startBeat < secondEnd and second.startBeat < firstEnd
end

function TimelineEventGeometry.findCollisionIds(events, relevantIds)
    local collisions = {}
    for firstIndex = 1, #events - 1 do
        local first = events[firstIndex]
        for secondIndex = firstIndex + 1, #events do
            local second = events[secondIndex]
            local relevant = relevantIds == nil
                or relevantIds[first.id]
                or relevantIds[second.id]
            if relevant and eventsOverlap(first, second) then
                collisions[first.id] = true
                collisions[second.id] = true
            end
        end
    end
    return collisions
end

return TimelineEventGeometry
