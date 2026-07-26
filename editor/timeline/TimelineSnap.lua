local TimelineSnap = {}

function TimelineSnap.snapBeat(beat, interval)
    return math.max(0, math.floor(beat / interval + 0.5) * interval)
end

function TimelineSnap.snapEventBeat(beat, interval)
    return math.max(0, math.floor(beat / interval) * interval)
end

return TimelineSnap
