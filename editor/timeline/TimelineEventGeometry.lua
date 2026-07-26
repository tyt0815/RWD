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

local function getCollisionSegments(event)
    if type(event.collisionSegments) == "table" then
        local segments = {}
        for _, segment in ipairs(event.collisionSegments) do
            table.insert(segments, {
                startBeat = event.startBeat + (segment.offsetBeats or 0),
                widthBeats = segment.widthBeats,
            })
        end
        return segments
    end
    return {
        {
            startBeat = event.startBeat,
            widthBeats = TimelineEventGeometry.getWidthBeats(event),
        },
    }
end

local function eventsOverlap(first, second)
    if first.track ~= second.track then return false end
    for _, firstSegment in ipairs(getCollisionSegments(first)) do
        local firstEnd = firstSegment.startBeat + firstSegment.widthBeats
        for _, secondSegment in ipairs(getCollisionSegments(second)) do
            local secondEnd = secondSegment.startBeat + secondSegment.widthBeats
            if firstSegment.startBeat < secondEnd
                and secondSegment.startBeat < firstEnd then
                return true
            end
        end
    end
    return false
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
