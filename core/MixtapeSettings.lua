local MixtapeSettings = {}

local DEFAULTS = {
    volume = 1,
    beat0Offset = 0,
}

local ALLOWED_KEYS = {
    music = true,
    volume = true,
    beat0Offset = true,
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

local function isMusicPath(value)
    if type(value) ~= "string" or value == "" or value:find("\\", 1, true) then
        return false
    end
    if not value:match("^assets/audio/") or value:match("^/") or value:match("^%a:/") then
        return false
    end
    for segment in value:gmatch("[^/]+") do
        if segment == ".." or segment == "." then return false end
    end
    local extension = value:match("%.([^./]+)$")
    extension = extension and extension:lower() or nil
    return extension == "ogg" or extension == "mp3" or extension == "wav"
end

function MixtapeSettings.validate(value)
    if value == nil then return nil end
    if type(value) ~= "table" then return "$.mixtape must be an object." end
    for key in pairs(value) do
        if not ALLOWED_KEYS[key] then return "$.mixtape contains an unknown field: " .. tostring(key) end
    end
    if value.music ~= nil and not isMusicPath(value.music) then
        return "$.mixtape.music must be a supported assets/audio relative path."
    end
    if value.volume ~= nil
        and (not isFiniteNumber(value.volume) or value.volume < 0 or value.volume > 1) then
        return "$.mixtape.volume must be between 0 and 1."
    end
    if value.beat0Offset ~= nil and not isFiniteNumber(value.beat0Offset) then
        return "$.mixtape.beat0Offset must be a finite number."
    end
    return nil
end

function MixtapeSettings.resolve(value)
    value = value or {}
    return {
        music = value.music,
        volume = value.volume == nil and DEFAULTS.volume or value.volume,
        beat0Offset = value.beat0Offset == nil and DEFAULTS.beat0Offset or value.beat0Offset,
    }
end

function MixtapeSettings.compact(value)
    local resolved = MixtapeSettings.resolve(value)
    local compact = {}
    if resolved.music ~= nil then compact.music = resolved.music end
    if resolved.volume ~= DEFAULTS.volume then compact.volume = resolved.volume end
    if resolved.beat0Offset ~= DEFAULTS.beat0Offset then
        compact.beat0Offset = resolved.beat0Offset
    end
    return next(compact) and compact or nil
end

return MixtapeSettings
