local function validStage()
    return {
        schemaVersion = 3,
        projectId = "sample",
        stageId = "test",
        name = "Test",
        bpm = 120,
        events = {},
    }
end

return {
    {
        name = "StageSchema validates a minimum schemaVersion 3 Stage",
        run = function(test)
            local Schema = require("core").StageSchema
            local valid, message, code = Schema.validate(validStage())
            test.assertEqual(valid, true)
            test.assertEqual(message, nil)
            test.assertEqual(code, nil)

            local invalid = validStage()
            invalid.schemaVersion = 2
            local rejected, errorMessage, errorCode = Schema.validate(invalid)
            test.assertEqual(rejected, nil)
            test.assertContains(errorMessage, "$.schemaVersion")
            test.assertEqual(errorCode, "INVALID_STAGE")
        end,
    },
    {
        name = "StageSchema normalize does not mutate input and creates sparse output",
        run = function(test)
            local Schema = require("core").StageSchema
            local stage = validStage()
            stage.editorSettings = { scale = 2, snap = 1 }
            stage.events = {
                {
                    id = "event-001",
                    type = "projectEvent",
                    categoryId = "sampleGameplay",
                    eventId = "spawnActors",
                    startBeat = 0,
                    track = 1,
                    params = {},
                },
            }

            local normalized = assert(Schema.normalize(stage))
            test.assertEqual(stage.editorSettings.snap, 1)
            test.assertEqual(normalized.editorSettings.snap, nil)
            test.assertEqual(normalized.editorSettings.scale, 2)
            test.assertTrue(normalized ~= stage)
            test.assertTrue(normalized.events ~= stage.events)
            test.assertEqual(getmetatable(normalized.events[1].params).__jsontype, "object")
        end,
    },
    {
        name = "StageSchema resolves independent complete Editor settings",
        run = function(test)
            local Schema = require("core").StageSchema
            local stage = validStage()
            stage.editorSettings = { scale = 2 }
            local first = Schema.resolveEditorSettings(stage)
            local second = Schema.resolveEditorSettings(stage)
            first.scale = 7
            test.assertEqual(second.metronome, false)
            test.assertEqual(second.metronomePeriod, 4)
            test.assertEqual(second.scale, 2)
            test.assertEqual(second.snap, 1)
            test.assertEqual(second.onsetThreshold, 0.01)
            test.assertEqual(second.playbackRate, 1)
            test.assertEqual(second.autoPlay, "none")
            test.assertEqual(second.trackCount, 10)
            test.assertEqual(second.previewAspectWidth, 16)
            test.assertEqual(second.previewAspectHeight, 9)
        end,
    },
    {
        name = "StageSchema validates Stage settings types and ranges",
        run = function(test)
            local Schema = require("core").StageSchema
            local invalidValues = {
                { metronome = "true" },
                { metronomePeriod = 0 }, { metronomePeriod = 33 }, { metronomePeriod = 1.5 },
                { snap = 0 }, { snap = 33 }, { snap = 1.5 },
                { onsetThreshold = -0.01 }, { onsetThreshold = 1.01 }, { onsetThreshold = "0" },
                { scale = 0.24 }, { scale = 8.01 },
                { playbackRate = 0.24 }, { playbackRate = 4.01 },
                { autoPlay = "perfect" }, { autoPlay = true },
                { trackCount = 0 }, { trackCount = 33 }, { trackCount = 1.5 },
                { previewAspectWidth = 0 }, { previewAspectHeight = -1 },
                { previewAspectWidth = "16" },
            }
            for _, editorSettings in ipairs(invalidValues) do
                local stage = validStage()
                stage.editorSettings = editorSettings
                local valid, _, code = Schema.validate(stage)
                test.assertEqual(valid, nil)
                test.assertEqual(code, "INVALID_STAGE")
            end

            local stage = validStage()
            stage.editorSettings = {
                metronome = true,
                metronomePeriod = 5,
                snap = 4,
                onsetThreshold = 0.02,
                scale = 2,
                playbackRate = 0.5,
                autoPlay = "miss",
                trackCount = 12,
                previewAspectWidth = 4,
                previewAspectHeight = 3,
            }
            test.assertEqual(Schema.validate(stage), true)
        end,
    },
    {
        name = "StageSchema normalize removes default Stage settings",
        run = function(test)
            local Schema = require("core").StageSchema
            local stage = validStage()
            stage.editorSettings = {
                metronome = true,
                metronomePeriod = 4,
                snap = 1,
                onsetThreshold = 0.01,
                scale = 2,
                playbackRate = 1,
                autoPlay = "good",
                trackCount = 10,
                previewAspectWidth = 16,
                previewAspectHeight = 9,
            }
            local normalized = assert(Schema.normalize(stage))
            test.assertEqual(normalized.editorSettings.metronome, true)
            test.assertEqual(normalized.editorSettings.metronomePeriod, nil)
            test.assertEqual(normalized.editorSettings.snap, nil)
            test.assertEqual(normalized.editorSettings.onsetThreshold, nil)
            test.assertEqual(normalized.editorSettings.scale, 2)
            test.assertEqual(normalized.editorSettings.playbackRate, nil)
            test.assertEqual(normalized.editorSettings.autoPlay, "good")
            test.assertEqual(normalized.editorSettings.trackCount, nil)
            test.assertEqual(normalized.editorSettings.previewAspectWidth, nil)
            test.assertEqual(normalized.editorSettings.previewAspectHeight, nil)

            local zeroStage = validStage()
            zeroStage.editorSettings = { onsetThreshold = 0 }
            local zeroNormalized = assert(Schema.normalize(zeroStage))
            test.assertEqual(zeroNormalized.editorSettings.onsetThreshold, 0)
        end,
    },
    {
        name = "StageSchema normalize는 JSON null sentinel을 보존한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local Schema = require("core").StageSchema
            local stage = validStage()
            stage.events = {
                {
                    id = "event-001",
                    type = "pattern",
                    patternId = "nullable",
                    startBeat = 0,
                    params = { optional = json.null },
                },
            }

            local normalized = assert(Schema.normalize(stage))
            test.assertEqual(normalized.events[1].params.optional, json.null)
        end,
    },
}
