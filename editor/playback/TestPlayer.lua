local TestPlayer = {}
TestPlayer.__index = TestPlayer

function TestPlayer.new()
    return setmetatable({
        playing = false,
    }, TestPlayer)
end

function TestPlayer:isPlaying()
    return self.playing
end

return TestPlayer
