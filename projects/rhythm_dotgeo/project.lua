local Core = require("core")

-- game/ 바로 아래 Category를 자동 발견하므로 SpeakiSong 추가를 위해 Game을 수정하지 않는다.
local eventCategories, categoryError = Core.ProjectCategories.discover({
    directoryPath = "projects/rhythm_dotgeo/game",
    modulePrefix = "projects.rhythm_dotgeo.game",
})
if not eventCategories then error(categoryError) end

return {
    id = "rhythm_dotgeo",
    title = "Rhythm Dotgeo",
    coreApiVersion = 2,
    entryModule = "projects.rhythm_dotgeo.game.Game",
    eventCategories = eventCategories,
}
