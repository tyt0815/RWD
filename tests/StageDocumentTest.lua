local function validStage()
    return {
        schemaVersion = 1,
        projectId = "sample",
        stageId = "tutorial",
        name = "Tutorial",
        tempoMap = { { startBeat = 0, bpm = 120 } },
        events = {},
    }
end

return {
    {
        name = "새 Stage는 단일 BPM과 빈 타임라인으로 생성된다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.create("sample", "new-stage", "New Stage", 120))
            local data = document:toTable()

            test.assertEqual(data.schemaVersion, 1)
            test.assertEqual(data.tempoMap[1].startBeat, 0)
            test.assertEqual(data.tempoMap[1].bpm, 120)
            test.assertEqual(#data.events, 0)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "Stage 식별자는 경로 문자를 허용하지 않는다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document, errorMessage = StageDocument.create("sample", "../escape", "Bad", 120)
            test.assertEqual(document, nil)
            test.assertContains(errorMessage, "$.stageId")

            local conDocument, conError = StageDocument.create("sample", "con", "CON", 120)
            local com1Document, com1Error = StageDocument.create("sample", "com1", "COM1", 120)
            test.assertEqual(conDocument, nil)
            test.assertContains(conError, "$.stageId")
            test.assertEqual(com1Document, nil)
            test.assertContains(com1Error, "$.stageId")

            local prefixedDocument = StageDocument.create("sample", "con-stage", "CON Stage", 120)
            local com10Document = StageDocument.create("sample", "com10", "COM10", 120)
            test.assertTrue(prefixedDocument ~= nil)
            test.assertTrue(com10Document ~= nil)
        end,
    },
    {
        name = "Stage는 0 이하와 유한하지 않은 BPM을 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local zeroDocument, zeroError = StageDocument.create("sample", "zero", "Zero", 0)
            local nanDocument, nanError = StageDocument.create("sample", "nan", "NaN", 0 / 0)
            test.assertEqual(zeroDocument, nil)
            test.assertContains(zeroError, "$.tempoMap[1].bpm")
            test.assertEqual(nanDocument, nil)
            test.assertContains(nanError, "$.tempoMap[1].bpm")
        end,
    },
    {
        name = "BPM 변경은 값을 바꾸고 dirty로 표시한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            test.assertEqual(document:isDirty(), false)
            assert(document:setBpm(90))
            test.assertEqual(document:getBpm(), 90)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "같은 BPM은 clean Stage를 dirty로 바꾸지 않는다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            assert(document:setBpm(120))
            test.assertEqual(document:isDirty(), false)
        end,
    },
    {
        name = "지원하지 않는 schemaVersion은 JSON 경로와 함께 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.schemaVersion = 2
            local errorMessage = StageDocument.validate(data)
            test.assertContains(errorMessage, "$.schemaVersion")
        end,
    },
    {
        name = "잘못된 Long Note는 Event JSON 경로와 함께 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.events = {
                { id = "event-1", type = "longNote", startBeat = 4, durationBeats = 0 },
            }
            local errorMessage = StageDocument.validate(data)
            test.assertContains(errorMessage, "$.events[1].durationBeats")
        end,
    },
    {
        name = "Save As 복제는 원본을 바꾸지 않고 새 ID와 이름을 사용한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local original = assert(StageDocument.fromTable(validStage()))
            local copy = assert(original:cloneAs("tutorial-copy", "Tutorial Copy"))
            test.assertEqual(original:getStageId(), "tutorial")
            test.assertEqual(copy:getStageId(), "tutorial-copy")
            test.assertEqual(copy:getName(), "Tutorial Copy")
            test.assertEqual(copy:isDirty(), true)
        end,
    },
}
