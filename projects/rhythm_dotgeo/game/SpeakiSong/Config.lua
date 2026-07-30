local Core = require("core")

local Config = {}
Config.__index = Config

local CONFIG_PATH = "projects/rhythm_dotgeo/config/speaki_song.json"
local PROJECT_PREFIX = "projects/rhythm_dotgeo/"

local function isFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function isNonNegativeFinite(value)
    return isFinite(value) and value >= 0
end

local function isPositiveFinite(value)
    return isFinite(value) and value > 0
end

local function validateSfxPath(path)
    return type(path) == "string"
        and path:match("^assets/audio/sfx/.+%.mp3$") ~= nil
end

function Config.new(loader)
    return setmetatable({
        loader = loader or Core.ProjectConfig.new(),
    }, Config)
end

function Config:load()
    local data, loadError = self.loader:load(CONFIG_PATH)
    if not data then return nil, loadError end
    if not validateSfxPath(data.longStartSound)
        or not validateSfxPath(data.longLoopSound)
        or not validateSfxPath(data.longEndSound) then
        return nil, "SpeakiSong config Long SFX values must be assets/audio/sfx MP3 paths."
    end
    local layout = data.actorLayout
    if type(layout) ~= "table"
        or not isPositiveFinite(layout.heightRatio)
        or not isPositiveFinite(layout.maxWidthRatio)
        or not isNonNegativeFinite(layout.sideMarginRatio)
        or not isNonNegativeFinite(layout.minMargin)
        or not isNonNegativeFinite(layout.outsidePadding) then
        return nil, "SpeakiSong config actorLayout contains invalid values."
    end
    local reactions = data.reactions
    if type(reactions) ~= "table"
        or not isPositiveFinite(reactions.longPressBeats)
        or not isFinite(reactions.longShiftXRatio)
        or not isFinite(reactions.longShiftYRatio)
        or not isPositiveFinite(reactions.tapDurationBeats)
        or not isFinite(reactions.tapShiftXRatio)
        or not isFinite(reactions.tapShiftYRatio)
        or not isNonNegativeFinite(reactions.tapShakeRatio) then
        return nil, "SpeakiSong config reactions contains invalid values."
    end
    if type(data.tapSounds) ~= "table" or #data.tapSounds == 0 then
        return nil, "SpeakiSong config tapSounds must contain at least one path."
    end
    for index, path in ipairs(data.tapSounds) do
        if not validateSfxPath(path) then
            return nil, "SpeakiSong config tapSounds[" .. index
                .. "] must be an assets/audio/sfx MP3 path."
        end
    end

    local resolved = {
        longStartSound = PROJECT_PREFIX .. data.longStartSound,
        longLoopSound = PROJECT_PREFIX .. data.longLoopSound,
        longEndSound = PROJECT_PREFIX .. data.longEndSound,
        tapSounds = {},
        actor = {
            actorHeightRatio = layout.heightRatio,
            maxActorWidthRatio = layout.maxWidthRatio,
            sideMarginRatio = layout.sideMarginRatio,
            minMargin = layout.minMargin,
            outsidePadding = layout.outsidePadding,
            longPressBeats = reactions.longPressBeats,
            longShiftXRatio = reactions.longShiftXRatio,
            longShiftYRatio = reactions.longShiftYRatio,
            tapDurationBeats = reactions.tapDurationBeats,
            tapShiftXRatio = reactions.tapShiftXRatio,
            tapShiftYRatio = reactions.tapShiftYRatio,
            tapShakeRatio = reactions.tapShakeRatio,
        },
    }
    for index, path in ipairs(data.tapSounds) do
        resolved.tapSounds[index] = PROJECT_PREFIX .. path
    end
    return resolved, nil
end

return Config
