local Core = require("core")
local ProjectLoader = require("launcher.ProjectLoader")
local game
local smokeTest = false

function love.load(arguments)
    for _, argument in ipairs(arguments or {}) do
        if argument == "--smoke-test" then smokeTest = true end
    end
    require("launcher.AppFont").apply()
    local repository = Core.StageRepository.new({
        fileSystem = require("launcher.NativeFileSystem").new(),
        json = require("vendor.dkjson"),
        paths = {
            stageDirectory = function(id) return "projects/" .. id .. "/stages" end,
            stageFile = function(id, stageId)
                return "projects/" .. id .. "/stages/" .. stageId .. ".json"
            end,
        },
    })
    local project = assert(ProjectLoader.loadProject("rhythm_dotgeo", Core.CORE_API_VERSION))
    game = assert(ProjectLoader.createGame(project, {
        stageRepository = repository,
        standalone = true,
    }))
    assert(not game.errorMessage, game.errorMessage)
    if smokeTest then
        assert(love.filesystem.isFused(), "Smoke test requires the fused executable")
        assert(not love.filesystem.getInfo("editor"), "Editor must not be packaged")
        assert(not love.filesystem.getInfo("projects/sample"), "Sample must not be packaged")
        local stageIds = assert(repository:listStages(project.id))
        assert(#stageIds > 0, "No stages packaged")
        game:draw(1280, 720)
        for _, stageId in ipairs(stageIds) do
            assert(game:startSelectedStage(stageId), game.errorMessage)
            game:update(0.01)
            assert(not game.errorMessage, game.errorMessage)
            game:draw(1280, 720)
            game:returnToStageSelect()
        end
        love.event.quit(0)
    end
end

function love.update(dt) game:update(dt) end
function love.draw() game:draw(love.graphics.getDimensions()) end
function love.mousepressed(x, y, button) game:mousepressed(x, y, button) end
function love.keypressed(key)
    if key == "escape" then
        if game:getScreen() == "stage" then game:returnToStageSelect()
        else love.event.quit() end
    else game:keypressed(key) end
end
function love.keyreleased(key) game:keyreleased(key) end
function love.quit() if game then game:stop() end end

local defaultErrorHandler = love.errorhandler
function love.errorhandler(message)
    if not smokeTest then return defaultErrorHandler(message) end
    io.stderr:write(tostring(message) .. "\n")
    return function() return 1 end
end
