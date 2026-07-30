local Core = {}

Core.CORE_API_VERSION = 1

Core.JudgmentResult = {
    GOOD = "GOOD",
    BAD = "BAD",
    MISS = "MISS",
    EMPTY_INPUT = "EMPTY_INPUT",
}

Core.PlaybackClock = require("core.PlaybackClock")
Core.TapJudgment = require("core.TapJudgment")
Core.LongNoteJudgment = require("core.LongNoteJudgment")
Core.PlayerAction = require("core.PlayerAction")
Core.BeatTween = require("core.BeatTween")
Core.ProjectManifest = require("core.ProjectManifest")
Core.ProjectEvents = require("core.ProjectEvents")
Core.ProjectCategories = require("core.ProjectCategories")
Core.ProjectConfig = require("core.ProjectConfig")
Core.StageRuntime = require("core.StageRuntime")
Core.MusicPlayback = require("core.MusicPlayback")
Core.PlaybackTransport = require("core.PlaybackTransport")
Core.MixtapeSettings = require("core.MixtapeSettings")
Core.StageSchema = require("core.StageSchema")
Core.TempoMap = require("core.TempoMap")
Core.UI = {
    Button = require("core.ui.Button"),
    TextInput = require("core.ui.TextInput"),
    ComboBox = require("core.ui.ComboBox"),
    ScrollArea = require("core.ui.ScrollArea"),
}

return Core
