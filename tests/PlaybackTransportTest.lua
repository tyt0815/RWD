local function newMusicPlayback(state)
    state.playPositions = state.playPositions or {}

    return {
        prepare = function(_, path, volume)
            state.prepareCount = (state.prepareCount or 0) + 1
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
            state.pauseCount = (state.pauseCount or 0) + 1
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
        name = "PlaybackTransport restores beat when delayed music play fails",
        run = function(test)
            local state = { playError = "delayed play failed" }
            local transport = newTransport(state)
            transport:configureMixtape({ volume = 1, beat0Offset = -0.5 }, "song.wav")
            test.assertTrue(transport:play(2))
            local previousBeat = transport:getBeat()

            local updated, errorMessage = transport:update(0.25)

            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "delayed play failed")
            test.assertEqual(transport:isPlaying(), false)
            test.assertNear(transport:getBeat(), previousBeat, 0.000001)
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
        name = "PlaybackTransport seeks to a non-negative beat while paused",
        run = function(test)
            local transport = newTransport({})
            test.assertTrue(transport:play())
            test.assertTrue(transport:update(0.5))
            test.assertTrue(transport:pause())

            test.assertTrue(transport:seekBeat(3.5))

            test.assertNear(transport:getBeat(), 3.5, 0.000001)
            test.assertNear(transport:getTimelineSeconds(), 1.75, 0.000001)
            test.assertEqual(transport.musicStarted, false)
        end,
    },
    {
        name = "PlaybackTransport rejects seek while playing",
        run = function(test)
            local transport = newTransport({})
            test.assertTrue(transport:play())

            local sought, errorMessage = transport:seekBeat(2)

            test.assertEqual(sought, nil)
            test.assertEqual(errorMessage, "Cannot seek while playback is running.")
            test.assertNear(transport:getBeat(), 0, 0.000001)
            test.assertEqual(transport:isPlaying(), true)
        end,
    },
    {
        name = "PlaybackTransport rejects an invalid seek beat",
        run = function(test)
            local transport = newTransport({})

            local sought, errorMessage = transport:seekBeat(-1)

            test.assertEqual(sought, nil)
            test.assertContains(errorMessage, "non-negative finite")
            test.assertNear(transport:getBeat(), 0, 0.000001)
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
        name = "PlaybackTransport rejects mixtape configuration while playing without changing state",
        run = function(test)
            local state = {}
            local transport = newTransport(state)
            local oldSettings = { volume = 0.5, beat0Offset = 0.25 }
            local newSettings = { volume = 1, beat0Offset = -0.5 }
            test.assertTrue(transport:configureMixtape(oldSettings, "old.wav"))
            test.assertTrue(transport:play())

            local prepareCount = state.prepareCount
            local playCount = #state.playPositions
            local configured, errorMessage = transport:configureMixtape(newSettings, "new.wav")
            test.assertEqual(configured, nil)
            test.assertEqual(errorMessage, "Cannot configure mixtape while playback is running.")
            test.assertEqual(transport.mixtape, oldSettings)
            test.assertEqual(transport.resolvedMusicPath, "old.wav")
            test.assertEqual(transport.musicStarted, true)
            test.assertEqual(transport:isPlaying(), true)
            test.assertEqual(state.prepareCount, prepareCount)
            test.assertEqual(#state.playPositions, playCount)
            test.assertEqual(state.pauseCount, nil)

            test.assertTrue(transport:pause())
            test.assertTrue(transport:configureMixtape(newSettings, "new.wav"))
            test.assertEqual(transport.mixtape, newSettings)
            test.assertEqual(transport.resolvedMusicPath, "new.wav")
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
            test.assertNear(transport:getBeat(), 0, 0.000001)
        end,
    },
}
