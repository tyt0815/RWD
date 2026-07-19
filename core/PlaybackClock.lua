local PlaybackClock = {}
PlaybackClock.__index = PlaybackClock

local function isValidBpm(bpm)
    return type(bpm) == "number"
        and bpm == bpm
        and bpm > 0
        and bpm < math.huge
end

function PlaybackClock.new(bpm)
    if not isValidBpm(bpm) then
        return nil, "BPM must be a positive finite number."
    end

    return setmetatable({
        bpm = bpm,
        beat = 0,
        playing = false,
    }, PlaybackClock)
end

function PlaybackClock:play()
    self.playing = true
end

function PlaybackClock:pause()
    self.playing = false
end

function PlaybackClock:reset(bpm)
    if bpm ~= nil then
        local changed, errorMessage = self:setBpm(bpm)
        if not changed then
            return nil, errorMessage
        end
    end

    self.beat = 0
    self.playing = false
    return true, nil
end

function PlaybackClock:update(deltaTime)
    if self.playing then
        self.beat = self.beat + deltaTime * self.bpm / 60
    end
end

function PlaybackClock:setBpm(bpm)
    if not isValidBpm(bpm) then
        return nil, "BPM must be a positive finite number."
    end

    self.bpm = bpm
    return true, nil
end

function PlaybackClock:getBpm()
    return self.bpm
end

function PlaybackClock:getBeat()
    return self.beat
end

function PlaybackClock:isPlaying()
    return self.playing
end

return PlaybackClock
