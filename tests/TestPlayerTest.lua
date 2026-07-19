local function newGraphics()
    local graphics = {
        canvasCreations = 0,
        draws = 0,
        pushes = 0,
        pops = 0,
    }

    function graphics.newCanvas(width, height)
        graphics.canvasCreations = graphics.canvasCreations + 1
        graphics.canvasWidth = width
        graphics.canvasHeight = height
        graphics.lastCanvas = { width = width, height = height }
        return graphics.lastCanvas
    end

    function graphics.push(mode)
        graphics.pushes = graphics.pushes + 1
        graphics.pushMode = mode
    end

    function graphics.pop()
        graphics.pops = graphics.pops + 1
    end

    function graphics.setCanvas(canvas)
        graphics.activeCanvas = canvas
    end

    function graphics.clear()
    end

    function graphics.draw(canvas, x, y)
        graphics.draws = graphics.draws + 1
        graphics.compositeCanvas = canvas
        graphics.compositeX = x
        graphics.compositeY = y
    end

    return graphics
end

return {
    {
        name = "TestPlayer starts a created Project game",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local project = { id = "sample", title = "Sample" }
            local factoryCount = 0
            local createdGames = {}
            local receivedProjects = {}
            local wasPlayingDuringRestart
            local gameDuringRestart
            local player
            player = TestPlayer.new({
                createGame = function(receivedProject)
                    factoryCount = factoryCount + 1
                    receivedProjects[factoryCount] = receivedProject
                    if factoryCount == 2 then
                        wasPlayingDuringRestart = player:isPlaying()
                        gameDuringRestart = player.game
                    end
                    local game = { instance = factoryCount }
                    createdGames[factoryCount] = game
                    return game, nil
                end,
                graphics = newGraphics(),
            })

            test.assertEqual(player:isPlaying(), false)
            assert(player:start(project))
            test.assertEqual(player:isPlaying(), true)
            test.assertEqual(receivedProjects[1], project)
            test.assertEqual(player.game, createdGames[1])

            assert(player:start(project))
            test.assertEqual(factoryCount, 2)
            test.assertEqual(receivedProjects[2], project)
            test.assertEqual(wasPlayingDuringRestart, false)
            test.assertEqual(gameDuringRestart, nil)
            test.assertTrue(createdGames[1] ~= createdGames[2])
            test.assertEqual(player.game, createdGames[2])
        end,
    },
    {
        name = "TestPlayer update forwards deltaTime to the Project game",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local received = 0
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        update = function(_, deltaTime)
                            received = deltaTime
                        end,
                    }, nil
                end,
                graphics = newGraphics(),
            })

            assert(player:start({ id = "sample" }))
            assert(player:update(0.25))
            test.assertEqual(received, 0.25)
        end,
    },
    {
        name = "TestPlayer returns game creation errors and stays inactive",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local project = { id = "sample" }
            local player = TestPlayer.new({
                createGame = function()
                    return nil, "preview failed"
                end,
                graphics = newGraphics(),
            })

            local started, errorMessage = player:start(project)

            local factoryCount = 0
            local firstGame = {}
            local throwingPlayer = TestPlayer.new({
                createGame = function()
                    factoryCount = factoryCount + 1
                    if factoryCount == 1 then
                        return firstGame, nil
                    end
                    error("factory exploded")
                end,
                graphics = newGraphics(),
            })

            assert(throwingPlayer:start(project))
            test.assertEqual(throwingPlayer.game, firstGame)
            local restartReturned, restarted, thrownError = pcall(function()
                return throwingPlayer:start(project)
            end)

            local invalidPlayer = TestPlayer.new({
                createGame = function()
                    return "not a game", nil
                end,
                graphics = newGraphics(),
            })
            local invalidStarted, invalidError = invalidPlayer:start(project)

            test.assertEqual(started, nil)
            test.assertEqual(player:isPlaying(), false)
            test.assertContains(errorMessage, "Project preview creation failed")
            test.assertContains(errorMessage, "preview failed")
            test.assertEqual(restartReturned, true)
            test.assertEqual(restarted, nil)
            test.assertContains(thrownError, "Project preview creation failed")
            test.assertContains(thrownError, "factory exploded")
            test.assertEqual(throwingPlayer:isPlaying(), false)
            test.assertEqual(throwingPlayer.game, nil)
            test.assertEqual(invalidStarted, nil)
            test.assertContains(invalidError, "Project preview creation failed")
            test.assertEqual(invalidPlayer:isPlaying(), false)
        end,
    },
    {
        name = "TestPlayer returns update exceptions as errors",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        update = function()
                            error("update exploded")
                        end,
                    }, nil
                end,
                graphics = newGraphics(),
            })

            assert(player:start({ id = "sample" }))
            local updated, errorMessage = player:update(0.1)
            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "update exploded")
        end,
    },
    {
        name = "TestPlayer draws with Canvas dimensions and stop releases playback",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local receivedWidth, receivedHeight
            local graphics = newGraphics()
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        draw = function(_, width, height)
                            receivedWidth, receivedHeight = width, height
                        end,
                    }, nil
                end,
                graphics = graphics,
            })

            assert(player:start({ id = "sample" }))
            assert(player:draw({ x = 10, y = 20, width = 400, height = 240 }))
            test.assertEqual(receivedWidth, 400)
            test.assertEqual(receivedHeight, 240)
            test.assertEqual(graphics.canvasCreations, 1)
            test.assertEqual(graphics.canvasWidth, 400)
            test.assertEqual(graphics.canvasHeight, 240)
            test.assertEqual(graphics.pushMode, "all")
            test.assertEqual(graphics.pushes, 1)
            test.assertEqual(graphics.pops, 1)
            test.assertEqual(graphics.draws, 1)
            test.assertEqual(graphics.compositeCanvas, graphics.lastCanvas)
            test.assertEqual(graphics.compositeX, 10)
            test.assertEqual(graphics.compositeY, 20)

            assert(player:draw({ x = 10, y = 20, width = 400, height = 240 }))
            test.assertEqual(graphics.canvasCreations, 1)
            test.assertEqual(graphics.pushes, 2)
            test.assertEqual(graphics.pops, 2)
            test.assertEqual(graphics.draws, 2)

            player:stop()
            test.assertEqual(player:isPlaying(), false)

            local failingGraphics = newGraphics()
            local failingPlayer = TestPlayer.new({
                createGame = function()
                    return {
                        draw = function()
                            error("draw exploded")
                        end,
                    }, nil
                end,
                graphics = failingGraphics,
            })
            assert(failingPlayer:start({ id = "sample" }))
            local drawn, drawError = failingPlayer:draw({
                x = 10,
                y = 20,
                width = 400,
                height = 240,
            })
            test.assertEqual(drawn, nil)
            test.assertContains(drawError, "Project preview draw failed")
            test.assertContains(drawError, "draw exploded")
            test.assertEqual(failingGraphics.pushes, 1)
            test.assertEqual(failingGraphics.pops, 1)
            test.assertEqual(failingGraphics.draws, 0)
        end,
    },
}
