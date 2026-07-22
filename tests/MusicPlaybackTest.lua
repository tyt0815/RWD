local function newSource(state)
    return {
        getDuration = function()
            return state.duration or 10
        end,
        setVolume = function(_, value)
            state.volume = value
        end,
        setPitch = function(_, value)
            state.pitch = value
        end,
        seek = function(_, value)
            state.position = value
            state.seekCount = (state.seekCount or 0) + 1
        end,
        tell = function()
            return state.position or 0
        end,
        play = function()
            state.playing = true
        end,
        pause = function()
            state.playing = false
        end,
        stop = function()
            state.playing = false
            state.stopped = true
        end,
    }
end

local function newPlayback(state)
    local MusicPlayback = require("core.MusicPlayback")

    return MusicPlayback.new({
        sourceFactory = function(path, sourceType)
            state.factoryPath = path
            state.factorySourceType = sourceType
            state.factoryCount = (state.factoryCount or 0) + 1
            return newSource(state)
        end,
    })
end

return {
    {
        name = "MusicPlayback keeps no-music operations successful without creating a Source",
        run = function(test)
            local state = {}
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare(nil, 0.8))
            test.assertTrue(playback:play(0, 1))
            test.assertTrue(playback:update(1, 1, 1))
            test.assertTrue(playback:pause())
            test.assertTrue(playback:stop())
            test.assertEqual(state.factoryCount, nil)
        end,
    },
    {
        name = "MusicPlayback prepares a stream Source with volume and duration",
        run = function(test)
            local state = { duration = 12 }
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))
            test.assertEqual(state.factoryPath, "projects/sample/assets/audio/a.wav")
            test.assertEqual(state.factorySourceType, "stream")
            test.assertEqual(state.volume, 0.8)
        end,
    },
    {
        name = "MusicPlayback seeks, sets pitch, and plays from the requested position",
        run = function(test)
            local state = {}
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))
            test.assertTrue(playback:play(2.5, 0.5))
            test.assertEqual(state.position, 2.5)
            test.assertEqual(state.pitch, 0.5)
            test.assertEqual(state.volume, 0.8)
            test.assertTrue(state.playing)
        end,
    },
    {
        name = "MusicPlayback stops at or after the music duration",
        run = function(test)
            local state = { duration = 10 }
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))
            test.assertTrue(playback:play(2.5, 1))
            test.assertTrue(playback:update(10, 1, 0.1))
            test.assertTrue(state.stopped)
            test.assertEqual(state.playing, false)
        end,
    },
    {
        name = "MusicPlayback corrects drift greater than 0.05 seconds every second",
        run = function(test)
            local state = {}
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))
            test.assertTrue(playback:play(2.5, 1))
            local seekCountBeforeUpdate = state.seekCount
            state.position = 2.551

            test.assertTrue(playback:update(2.5, 1, 1.0))
            test.assertEqual(state.seekCount, seekCountBeforeUpdate + 1)
            test.assertEqual(state.position, 2.5)
        end,
    },
    {
        name = "MusicPlayback preserves drift interval remainder after a large update",
        run = function(test)
            local state = {}
            local playback = newPlayback(state)

            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))
            test.assertTrue(playback:play(0, 1))
            state.position = 0.051
            local seekCountBeforeLargeUpdate = state.seekCount

            test.assertTrue(playback:update(0, 1, 2.5))
            test.assertEqual(state.seekCount, seekCountBeforeLargeUpdate + 1)

            state.position = 0.051
            test.assertTrue(playback:update(0, 1, 0.5))
            test.assertEqual(state.seekCount, seekCountBeforeLargeUpdate + 2)
        end,
    },
    {
        name = "MusicPlayback reports Source factory failures and remains stopped",
        run = function(test)
            local MusicPlayback = require("core.MusicPlayback")
            local playback = MusicPlayback.new({
                sourceFactory = function()
                    error("cannot create source")
                end,
            })

            local prepared, errorMessage = playback:prepare("missing.wav", 0.8)
            test.assertEqual(prepared, nil)
            test.assertContains(errorMessage, "Music playback failed:")
            test.assertContains(errorMessage, "cannot create source")
            test.assertTrue(playback:play(0, 1))
        end,
    },
    {
        name = "MusicPlayback reports Source method failures and stops playback",
        run = function(test)
            local state = {}
            local source = newSource(state)
            source.setPitch = function()
                error("cannot set pitch")
            end

            local MusicPlayback = require("core.MusicPlayback")
            local playback = MusicPlayback.new({
                sourceFactory = function()
                    return source
                end,
            })
            test.assertTrue(playback:prepare("projects/sample/assets/audio/a.wav", 0.8))

            local played, errorMessage = playback:play(2.5, 1)
            test.assertEqual(played, nil)
            test.assertContains(errorMessage, "Music playback failed:")
            test.assertContains(errorMessage, "cannot set pitch")
            test.assertTrue(state.stopped)
            test.assertEqual(state.playing, false)
        end,
    },
}
