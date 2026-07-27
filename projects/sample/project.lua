local Core = require("core")

-- game/ 바로 아래에서 Definition.lua와 Runtime.lua를 가진 Category를 자동 발견한다.
-- 따라서 NewGameSample/ 폴더를 추가할 때 이 manifest를 다시 편집할 필요가 없다.
local eventCategories, categoryError = Core.ProjectCategories.discover({
    directoryPath = "projects/sample/game",
    modulePrefix = "projects.sample.game",
})
if not eventCategories then error(categoryError) end

return {
    id = "sample",
    title = "Sample Project",
    coreApiVersion = 1,
    entryModule = "projects.sample.game.SampleGame",
    eventCategories = eventCategories,
}
