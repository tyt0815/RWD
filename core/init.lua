local Core = {}

Core.CORE_API_VERSION = 1

Core.JudgmentResult = {
    GOOD = "GOOD",
    BAD = "BAD",
    MISS = "MISS",
    EMPTY_INPUT = "EMPTY_INPUT",
}

Core.PlaybackClock = require("core.PlaybackClock")
Core.MusicPlayback = require("core.MusicPlayback")
Core.MixtapeSettings = require("core.MixtapeSettings")
Core.TempoMap = require("core.TempoMap")

return Core
