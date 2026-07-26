local function newGraphics()
    local previousCanvas = { name = "previous" }
    local graphics = {
        canvasCreations = 0,
        canvases = {},
        currentCanvas = previousCanvas,
        previousCanvas = previousCanvas,
        stack = {},
        depth = 0,
        events = {},
        draws = 0,
        pushes = 0,
        pops = 0,
    }

    function graphics.newCanvas(width, height)
        graphics.canvasCreations = graphics.canvasCreations + 1
        graphics.canvasWidth = width
        graphics.canvasHeight = height
        graphics.lastCanvas = { width = width, height = height }
        graphics.canvases[graphics.canvasCreations] = graphics.lastCanvas
        return graphics.lastCanvas
    end

    function graphics.push(mode)
        graphics.pushes = graphics.pushes + 1
        graphics.pushMode = mode
        table.insert(graphics.stack, graphics.currentCanvas)
        graphics.depth = graphics.depth + 1
        table.insert(graphics.events, "push")
    end

    function graphics.pop()
        graphics.pops = graphics.pops + 1
        graphics.currentCanvas = table.remove(graphics.stack)
        graphics.depth = graphics.depth - 1
        graphics.popRestoredCanvas = graphics.currentCanvas
        table.insert(graphics.events, "pop")
    end

    function graphics.setCanvas(canvas)
        graphics.setCanvasTarget = canvas
        graphics.currentCanvas = canvas
        table.insert(graphics.events, "setCanvas")
    end

    function graphics.clear()
    end

    function graphics.draw(canvas, x, y)
        graphics.draws = graphics.draws + 1
        graphics.compositeCanvas = canvas
        graphics.compositeX = x
        graphics.compositeY = y
        graphics.compositeTarget = graphics.currentCanvas
        table.insert(graphics.events, "composite")
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
        name = "TestPlayer는 Auto Play 선택을 Stage 시작 전에 Project 게임에 전달한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local calls = {}
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        setAutoPlay = function(_, value)
                            table.insert(calls, "auto:" .. value)
                        end,
                        startStage = function()
                            table.insert(calls, "stage")
                        end,
                    }, nil
                end,
                graphics = newGraphics(),
            })

            assert(player:start({ id = "sample" }, { events = {} }, 0, "bad"))
            test.assertEqual(calls[1], "auto:bad")
            test.assertEqual(calls[2], "stage")
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
            local projectCanvas, projectDepth
            local graphics = newGraphics()
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        draw = function(_, width, height)
                            projectCanvas = graphics.currentCanvas
                            projectDepth = graphics.depth
                            table.insert(graphics.events, "projectDraw")
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
            local firstCanvas = graphics.canvases[1]
            test.assertEqual(graphics.lastCanvas, firstCanvas)
            test.assertEqual(graphics.pushMode, "all")
            test.assertEqual(graphics.pushes, 1)
            test.assertEqual(graphics.pops, 1)
            test.assertEqual(graphics.depth, 0)
            test.assertEqual(graphics.setCanvasTarget, firstCanvas)
            test.assertEqual(projectCanvas, firstCanvas)
            test.assertEqual(projectDepth, 1)
            test.assertEqual(graphics.popRestoredCanvas, graphics.previousCanvas)
            test.assertEqual(graphics.currentCanvas, graphics.previousCanvas)
            test.assertEqual(graphics.draws, 1)
            test.assertEqual(graphics.compositeCanvas, firstCanvas)
            test.assertEqual(graphics.compositeX, 10)
            test.assertEqual(graphics.compositeY, 20)
            test.assertEqual(graphics.compositeTarget, graphics.previousCanvas)
            test.assertEqual(graphics.events[1], "push")
            test.assertEqual(graphics.events[2], "setCanvas")
            test.assertEqual(graphics.events[3], "projectDraw")
            test.assertEqual(graphics.events[4], "pop")
            test.assertEqual(graphics.events[5], "composite")

            assert(player:draw({ x = 10, y = 20, width = 400, height = 240 }))
            test.assertEqual(graphics.canvasCreations, 1)
            test.assertEqual(graphics.lastCanvas, firstCanvas)
            test.assertEqual(graphics.pushes, 2)
            test.assertEqual(graphics.pops, 2)
            test.assertEqual(graphics.depth, 0)
            test.assertEqual(graphics.currentCanvas, graphics.previousCanvas)
            test.assertEqual(graphics.draws, 2)

            assert(player:draw({ x = 30, y = 50, width = 640, height = 360 }))
            local secondCanvas = graphics.canvases[2]
            test.assertEqual(receivedWidth, 640)
            test.assertEqual(receivedHeight, 360)
            test.assertEqual(graphics.canvasCreations, 2)
            test.assertTrue(secondCanvas ~= firstCanvas)
            test.assertEqual(secondCanvas.width, 640)
            test.assertEqual(secondCanvas.height, 360)
            test.assertEqual(graphics.setCanvasTarget, secondCanvas)
            test.assertEqual(projectCanvas, secondCanvas)
            test.assertEqual(projectDepth, 1)
            test.assertEqual(graphics.compositeCanvas, secondCanvas)
            test.assertEqual(graphics.compositeX, 30)
            test.assertEqual(graphics.compositeY, 50)
            test.assertEqual(graphics.compositeTarget, graphics.previousCanvas)
            test.assertEqual(graphics.pushes, 3)
            test.assertEqual(graphics.pops, 3)
            test.assertEqual(graphics.depth, 0)
            test.assertEqual(graphics.currentCanvas, graphics.previousCanvas)
            test.assertEqual(graphics.draws, 3)

            player:stop()
            test.assertEqual(player:isPlaying(), false)

            local failingGraphics = newGraphics()
            local failingProjectCanvas, failingProjectDepth
            local failingPlayer = TestPlayer.new({
                createGame = function()
                    return {
                        draw = function()
                            failingProjectCanvas = failingGraphics.currentCanvas
                            failingProjectDepth = failingGraphics.depth
                            table.insert(failingGraphics.events, "projectDrawThrow")
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
            test.assertEqual(failingGraphics.setCanvasTarget, failingGraphics.lastCanvas)
            test.assertEqual(failingProjectCanvas, failingGraphics.lastCanvas)
            test.assertEqual(failingProjectDepth, 1)
            test.assertEqual(#failingGraphics.events, 4)
            test.assertEqual(failingGraphics.events[1], "push")
            test.assertEqual(failingGraphics.events[2], "setCanvas")
            test.assertEqual(failingGraphics.events[3], "projectDrawThrow")
            test.assertEqual(failingGraphics.events[4], "pop")
            test.assertEqual(failingGraphics.pushes, 1)
            test.assertEqual(failingGraphics.pops, 1)
            test.assertEqual(failingGraphics.depth, 0)
            test.assertEqual(
                failingGraphics.popRestoredCanvas,
                failingGraphics.previousCanvas
            )
            test.assertEqual(failingGraphics.currentCanvas, failingGraphics.previousCanvas)
            test.assertEqual(failingGraphics.draws, 0)
            test.assertEqual(failingGraphics.compositeCanvas, nil)
        end,
    },
}
