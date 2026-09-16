local BeatBounce = {}

local SQUASH = 0.12
local PRESS_BEATS = 0.12
local RECOVER_BEATS = 0.48

function BeatBounce.getHeightRatio(beat)
    local phase = beat - math.floor(beat)
    local squash = 0
    if phase < PRESS_BEATS then
        squash = (1 - math.cos(math.pi * phase / PRESS_BEATS)) / 2
    elseif phase < PRESS_BEATS + RECOVER_BEATS then
        squash = (1 + math.cos(math.pi * (phase - PRESS_BEATS) / RECOVER_BEATS)) / 2
    end
    return 1 - SQUASH * squash
end

return BeatBounce
