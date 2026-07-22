local function newMusicPlayback(state)
    state.playPositions = state.playPositions or {}

    return {
        prepare = function(_, path, volume)
            state.preparePath = path
            state.prepareVolume = volume
            if state.prepareError then return nil, state.prepareError end
            return true, nil
        end,
        play = function(_, position, rate)
            table.insert(state.playPositions, { position = position, rate = rate })
            if state.playError then return nil, state.playError end
            return true, nil
        end,
        update = function(_, expectedSeconds, rate, deltaTime)
            state.updateCount = (state.updateCount or 0) + 1
            state.updateExpectedSeconds = expectedSeconds
            state.updateRate = rate
            state.updateDeltaTime = deltaTime
            if state.updateError then return nil, state.updateError end
            return true, nil
        end,
        pause = function()
            state.paused = true
            return true, nil
        end,
        stop = function()
            state.stopped = true
            return true, nil
        end,
    }
end

local function newTransport(state)
    local Core = require("core")
    return assert(Core.PlaybackTransport.new({
        bpm = 120,
        musicPlayback = newMusicPlayback(state),
    }))
end

return {
    {
        name = "PlaybackTransport advances one beat after 0.5 seconds at rate 1",
        run = function(test)
            local transport = newTransport({})

            test.assertTrue(transport:play())
            test.assertTrue(transport:update(0.5))
            test.assertNear(transport:getTimelineSeconds(), 0.5, 0.000001)
            test.assertNear(transport:getBeat(), 1, 0.000001)
            test.assertEqual(transport:getPlaybackRate(), 1)
        end,
    },
    {
        name = "PlaybackTransport advances two beats after 0.5 seconds at rate 2",
        run = function(test)
            local transport = newTransport({})

            test.assertTrue(transport:play(2))
            test.assertTrue(transport:update(0.5))
            test.assertNear(transport:getTimelineSeconds(), 1, 0.000001)
            test.assertNear(transport:getBeat(), 2, 0.000001)
            test.assertEqual(transport:getPlaybackRate(), 2)
        end,
    },
    {
        name = "PlaybackTransport starts music from a positive beat zero offset",
        run = function(test)
            local state = {}
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0.5 }, "song.wav")

            test.assertTrue(transport:play())
            test.assertEqual(state.preparePath, "song.wav")
            test.assertEqual(state.prepareVolume, 1)
            test.assertEqual(#state.playPositions, 1)
            test.assertNear(state.playPositions[1].position, 0.5, 0.000001)
            test.assertEqual(state.playPositions[1].rate, 1)
        end,
    },
    {
        name = "PlaybackTransport starts music when a negative beat zero offset is crossed",
        run = function(test)
            local state = {}
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = -0.5 }, "song.wav")

            test.assertTrue(transport:play(2))
            test.assertEqual(#state.playPositions, 0)
            test.assertTrue(transport:update(0.25))
            test.assertEqual(#state.playPositions, 1)
            test.assertNear(state.playPositions[1].position, 0, 0.000001)
            test.assertEqual(state.playPositions[1].rate, 2)
            test.assertEqual(state.updateCount, nil)
            test.assertNear(transport:getBeat(), 1, 0.000001)
        end,
    },
    {
        name = "PlaybackTransport preserves beat and resumes music from the paused position",
        run = function(test)
            local state = {}
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0.5 }, "song.wav")
            test.assertTrue(transport:play())
            test.assertTrue(transport:update(0.5))

            test.assertTrue(transport:pause())
            test.assertTrue(state.paused)
            test.assertTrue(transport:update(1))
            test.assertNear(transport:getBeat(), 1, 0.000001)

            test.assertTrue(transport:play())
            test.assertNear(state.playPositions[2].position, 1, 0.000001)
        end,
    },
    {
        name = "PlaybackTransport preserves beat when BPM changes and recalculates timeline",
        run = function(test)
            local transport = newTransport({})
            test.assertTrue(transport:play())
            test.assertTrue(transport:update(1))

            test.assertTrue(transport:setBpm(60))
            test.assertNear(transport:getBeat(), 2, 0.000001)
            test.assertNear(transport:getTimelineSeconds(), 2, 0.000001)
            test.assertTrue(transport:update(1))
            test.assertNear(transport:getBeat(), 3, 0.000001)
        end,
    },
    {
        name = "PlaybackTransport reconciles music when BPM changes during playback",
        run = function(test)
            local state = {}
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0 }, "song.wav")
            test.assertTrue(transport:play())
            test.assertTrue(transport:update(1))

            test.assertTrue(transport:setBpm(60))
            test.assertEqual(#state.playPositions, 2)
            test.assertNear(state.playPositions[2].position, 2, 0.000001)
            test.assertEqual(state.playPositions[2].rate, 1)
        end,
    },
    {
        name = "PlaybackTransport pauses and preserves beat when music prepare fails",
        run = function(test)
            local state = { prepareError = "prepare failed" }
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0 }, "song.wav")

            local played, errorMessage = transport:play()
            test.assertEqual(played, nil)
            test.assertContains(errorMessage, "prepare failed")
            test.assertEqual(transport:isPlaying(), false)
            test.assertNear(transport:getBeat(), 0, 0.000001)
        end,
    },
    {
        name = "PlaybackTransport pauses and preserves beat when music play fails",
        run = function(test)
            local state = { playError = "play failed" }
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0 }, "song.wav")

            local played, errorMessage = transport:play()
            test.assertEqual(played, nil)
            test.assertContains(errorMessage, "play failed")
            test.assertEqual(transport:isPlaying(), false)
            test.assertNear(transport:getBeat(), 0, 0.000001)
        end,
    },
    {
        name = "PlaybackTransport pauses and preserves beat when music update fails",
        run = function(test)
            local state = { updateError = "update failed" }
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = 0 }, "song.wav")
            test.assertTrue(transport:play())

            local updated, errorMessage = transport:update(0.5)
            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "update failed")
            test.assertEqual(transport:isPlaying(), false)
            test.assertNear(transport:getBeat(), 1, 0.000001)
        end,
    },
}
