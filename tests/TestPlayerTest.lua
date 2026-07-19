local function newGraphics()
    local graphics = { draws = 0 }

    function graphics.newCanvas(width, height)
        return { width = width, height = height }
    end

    function graphics.push()
    end

    function graphics.pop()
    end

    function graphics.setCanvas()
    end

    function graphics.clear()
    end

    function graphics.draw()
        graphics.draws = graphics.draws + 1
    end

    return graphics
end

return {
    {
        name = "TestPlayer starts a created Project game",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local game = {}
            local player = TestPlayer.new({
                createGame = function()
                    return game, nil
                end,
                graphics = newGraphics(),
            })

            test.assertEqual(player:isPlaying(), false)
            assert(player:start({ id = "sample" }))
            test.assertEqual(player:isPlaying(), true)
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
            local player = TestPlayer.new({
                createGame = function()
                    return nil, "preview failed"
                end,
                graphics = newGraphics(),
            })

            local started, errorMessage = player:start({ id = "sample" })
            test.assertEqual(started, nil)
            test.assertEqual(player:isPlaying(), false)
            test.assertContains(errorMessage, "preview failed")
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
            test.assertEqual(graphics.draws, 1)
            player:stop()
            test.assertEqual(player:isPlaying(), false)
        end,
    },
}
