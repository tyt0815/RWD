local TempoMap = {}
TempoMap.__index = TempoMap

local function isPositiveFinite(value)
    return type(value) == "number"
        and value == value
        and value > 0
        and value < math.huge
end

local function isNonNegativeFinite(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

function TempoMap.new(bpm)
    if not isPositiveFinite(bpm) then
        return nil, "BPM must be a positive finite number."
    end
    return setmetatable({ bpm = bpm }, TempoMap), nil
end

function TempoMap:beatToSeconds(beat)
    if not isNonNegativeFinite(beat) then
        return nil, "Beat must be a non-negative finite number."
    end
    return beat * 60 / self.bpm, nil
end

function TempoMap:secondsToBeat(seconds)
    if not isNonNegativeFinite(seconds) then
        return nil, "Seconds must be a non-negative finite number."
    end
    return seconds * self.bpm / 60, nil
end

function TempoMap:getBpm()
    return self.bpm
end

return TempoMap
