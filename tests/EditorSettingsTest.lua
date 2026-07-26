return {
    {
        name = "EditorSettings resolves missing values to defaults",
        run = function(test)
            local settings = require("editor.stage.EditorSettings").resolve(nil)
            test.assertEqual(settings.metronome, false)
            test.assertEqual(settings.metronomePeriod, 4)
            test.assertEqual(settings.snap, 1)
            test.assertEqual(settings.onsetThreshold, 0.01)
            test.assertEqual(settings.scale, 1)
            test.assertEqual(settings.playbackRate, 1)
            test.assertEqual(settings.trackCount, 10)
        end,
    },
    {
        name = "EditorSettings removes defaults from compact values",
        run = function(test)
            local compact = require("editor.stage.EditorSettings").compact({
                metronome = true,
                metronomePeriod = 4,
                snap = 1,
                onsetThreshold = 0.01,
                scale = 2,
                playbackRate = 1,
                trackCount = 10,
            })
            test.assertEqual(compact.metronome, true)
            test.assertEqual(compact.metronomePeriod, nil)
            test.assertEqual(compact.snap, nil)
            test.assertEqual(compact.onsetThreshold, nil)
            test.assertEqual(compact.scale, 2)
            test.assertEqual(compact.playbackRate, nil)
            test.assertEqual(compact.trackCount, nil)

            local explicitZero = require("editor.stage.EditorSettings").compact({
                onsetThreshold = 0,
            })
            test.assertEqual(explicitZero.onsetThreshold, 0)
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
            test.assertContains(validate({ snap = 0 }), "snap")
            test.assertContains(validate({ snap = 33 }), "snap")
            test.assertContains(validate({ snap = 1.5 }), "snap")
            test.assertContains(validate({ onsetThreshold = -0.01 }), "onsetThreshold")
            test.assertContains(validate({ onsetThreshold = 1.01 }), "onsetThreshold")
            test.assertContains(validate({ onsetThreshold = "0" }), "onsetThreshold")
            test.assertContains(validate({ scale = 0.24 }), "scale")
            test.assertContains(validate({ scale = 8.01 }), "scale")
            test.assertContains(validate({ playbackRate = 0.24 }), "playbackRate")
            test.assertContains(validate({ playbackRate = 4.01 }), "playbackRate")
            test.assertContains(validate({ trackCount = 0 }), "trackCount")
            test.assertContains(validate({ trackCount = 33 }), "trackCount")
            test.assertContains(validate({ trackCount = 1.5 }), "trackCount")
            test.assertEqual(validate({
                metronome = true,
                metronomePeriod = 5,
                snap = 4,
                onsetThreshold = 0.02,
                scale = 2,
                playbackRate = 0.5,
                trackCount = 12,
            }), nil)
        end,
    },
}
