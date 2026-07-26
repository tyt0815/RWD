local EditorSettings = {}

local DEFAULTS = {
    metronome = false,
    metronomePeriod = 4,
    snap = 1,
    onsetThreshold = 0.01,
    scale = 1,
    playbackRate = 1,
    trackCount = 10,
}

local ALLOWED_KEYS = {
    metronome = true,
    metronomePeriod = true,
    snap = true,
    onsetThreshold = true,
    scale = true,
    playbackRate = true,
    trackCount = true,
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

function EditorSettings.validate(value)
    if value == nil then return nil end
    if type(value) ~= "table" then return "$.editorSettings must be an object." end
    for key in pairs(value) do
        if not ALLOWED_KEYS[key] then
            return "$.editorSettings contains an unknown field: " .. tostring(key)
        end
    end
    if value.metronome ~= nil and type(value.metronome) ~= "boolean" then
        return "$.editorSettings.metronome must be a boolean."
    end
    if value.metronomePeriod ~= nil
        and (not isFiniteNumber(value.metronomePeriod)
            or value.metronomePeriod % 1 ~= 0
            or value.metronomePeriod < 1
            or value.metronomePeriod > 32) then
        return "$.editorSettings.metronomePeriod must be an integer between 1 and 32."
    end
    if value.snap ~= nil
        and (not isFiniteNumber(value.snap)
            or value.snap % 1 ~= 0
            or value.snap < 1
            or value.snap > 32) then
        return "$.editorSettings.snap must be an integer between 1 and 32."
    end
    if value.onsetThreshold ~= nil
        and (not isFiniteNumber(value.onsetThreshold)
            or value.onsetThreshold < 0
            or value.onsetThreshold > 1) then
        return "$.editorSettings.onsetThreshold must be between 0 and 1."
    end
    if value.scale ~= nil
        and (not isFiniteNumber(value.scale) or value.scale < 0.25 or value.scale > 8) then
        return "$.editorSettings.scale must be between 0.25 and 8."
    end
    if value.playbackRate ~= nil
        and (not isFiniteNumber(value.playbackRate)
            or value.playbackRate < 0.25
            or value.playbackRate > 4) then
        return "$.editorSettings.playbackRate must be between 0.25 and 4."
    end
    if value.trackCount ~= nil
        and (not isFiniteNumber(value.trackCount)
            or value.trackCount % 1 ~= 0
            or value.trackCount < 1
            or value.trackCount > 32) then
        return "$.editorSettings.trackCount must be an integer between 1 and 32."
    end
    return nil
end

function EditorSettings.resolve(value)
    value = value or {}
    local metronome = value.metronome
    if metronome == nil then metronome = DEFAULTS.metronome end
    return {
        metronome = metronome,
        metronomePeriod = value.metronomePeriod or DEFAULTS.metronomePeriod,
        snap = value.snap or DEFAULTS.snap,
        onsetThreshold = value.onsetThreshold or DEFAULTS.onsetThreshold,
        scale = value.scale or DEFAULTS.scale,
        playbackRate = value.playbackRate or DEFAULTS.playbackRate,
        trackCount = value.trackCount or DEFAULTS.trackCount,
    }
end

function EditorSettings.compact(value)
    local resolved = EditorSettings.resolve(value)
    local compact = {}
    for key, defaultValue in pairs(DEFAULTS) do
        if resolved[key] ~= defaultValue then compact[key] = resolved[key] end
    end
    return next(compact) and compact or nil
end

return EditorSettings
