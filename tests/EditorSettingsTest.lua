return {
    {
        name = "EditorSettings resolves missing values to defaults",
        run = function(test)
            local settings = require("editor.stage.EditorSettings").resolve(nil)
            test.assertEqual(settings.metronome, false)
            test.assertEqual(settings.metronomePeriod, 4)
            test.assertEqual(settings.scale, 1)
            test.assertEqual(settings.playbackRate, 1)
        end,
    },
    {
        name = "EditorSettings removes defaults from compact values",
        run = function(test)
            local compact = require("editor.stage.EditorSettings").compact({
                metronome = true,
                metronomePeriod = 4,
                scale = 2,
                playbackRate = 1,
            })
            test.assertEqual(compact.metronome, true)
            test.assertEqual(compact.metronomePeriod, nil)
            test.assertEqual(compact.scale, 2)
            test.assertEqual(compact.playbackRate, nil)
        end,
    },
    {
        name = "EditorSettings validates type and ranges",
        run = function(test)
            local validate = require("editor.stage.EditorSettings").validate
            test.assertContains(validate({ metronome = "true" }), "metronome")
            test.assertContains(validate({ metronomePeriod = 0 }), "metronomePeriod")
            test.assertContains(validate({ metronomePeriod = 33 }), "metronomePeriod")
            test.assertContains(validate({ metronomePeriod = 1.5 }), "metronomePeriod")
            test.assertContains(validate({ scale = 0.24 }), "scale")
            test.assertContains(validate({ scale = 8.01 }), "scale")
            test.assertContains(validate({ playbackRate = 0.24 }), "playbackRate")
            test.assertContains(validate({ playbackRate = 4.01 }), "playbackRate")
            test.assertEqual(validate({
                metronome = true,
                metronomePeriod = 5,
                scale = 2,
                playbackRate = 0.5,
            }), nil)
        end,
    },
}
