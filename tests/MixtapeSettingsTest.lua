return {
    {
        name = "MixtapeSettings resolves missing values to defaults",
        run = function(test)
            local settings = require("core").MixtapeSettings.resolve(nil)
            test.assertEqual(settings.music, nil)
            test.assertEqual(settings.volume, 1)
            test.assertEqual(settings.beat0Offset, 0)
        end,
    },
    {
        name = "MixtapeSettings removes defaults from compact values",
        run = function(test)
            local MixtapeSettings = require("core").MixtapeSettings
            test.assertEqual(MixtapeSettings.compact({ volume = 1, beat0Offset = 0 }), nil)
            local compact = MixtapeSettings.compact({
                music = "assets/audio/song.ogg",
                volume = 0.8,
                beat0Offset = -0.5,
            })
            test.assertEqual(compact.music, "assets/audio/song.ogg")
            test.assertEqual(compact.volume, 0.8)
            test.assertEqual(compact.beat0Offset, -0.5)
        end,
    },
    {
        name = "MixtapeSettings accepts only safe music paths",
        run = function(test)
            local validate = require("core").MixtapeSettings.validate
            test.assertEqual(validate({ music = "assets/audio/song.ogg" }), nil)
            test.assertEqual(validate({ music = "assets/audio/sub/song.MP3" }), nil)
            test.assertContains(validate({ music = "../song.wav" }), "music")
            test.assertContains(validate({ music = "assets\\audio\\song.wav" }), "music")
            test.assertContains(validate({ music = "assets/audio/song.flac" }), "music")
        end,
    },
    {
        name = "MixtapeSettings validates volume and offset type and range",
        run = function(test)
            local validate = require("core").MixtapeSettings.validate
            test.assertContains(validate({ volume = -0.01 }), "volume")
            test.assertContains(validate({ volume = 1.01 }), "volume")
            test.assertContains(validate({ beat0Offset = 0 / 0 }), "beat0Offset")
            test.assertEqual(validate({ volume = 0, beat0Offset = -10 }), nil)
        end,
    },
}
