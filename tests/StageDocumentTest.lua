local function validStage()
    return {
        schemaVersion = 3,
        projectId = "sample",
        stageId = "tutorial",
        name = "Tutorial",
        bpm = 120,
        events = {},
    }
end

local function assertInvalidStage(test, data, expected, exact)
    local valid, errorMessage, code = require("core").StageSchema.validate(data)
    test.assertEqual(valid, nil)
    if exact then
        test.assertEqual(errorMessage, expected)
    else
        test.assertContains(errorMessage, expected)
    end
    test.assertEqual(code, "INVALID_STAGE")
end

return {
    {
        name = "새 Stage는 단일 BPM과 빈 타임라인으로 생성된다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.create("sample", "new-stage", "New Stage", 120))
            local data = document:toTable()

            test.assertEqual(data.schemaVersion, 3)
            test.assertEqual(data.bpm, 120)
            test.assertEqual(#data.events, 0)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "StageSchema는 Category ID 없는 Project Event를 거부한다",
        run = function(test)
            local Core = require("core")
            local data = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "tutorial",
                name = "Tutorial",
                bpm = 120,
                events = {
                    {
                        id = "event-1",
                        type = "projectEvent",
                        startBeat = 4,
                        track = 2,
                        eventId = "cueResponse",
                        params = {},
                    },
                },
            }

            local valid, errorMessage, code = Core.StageSchema.validate(data)
            test.assertEqual(valid, nil)
            test.assertContains(errorMessage, "$.events[1].categoryId")
            test.assertEqual(code, "INVALID_STAGE")
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
            test.assertContains(zeroError, "$.bpm")
            test.assertEqual(nanDocument, nil)
            test.assertContains(nanError, "$.bpm")
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
            local data = validStage()
            data.schemaVersion = 1
            assertInvalidStage(test, data, "$.schemaVersion must be 3.", true)
        end,
    },
    {
        name = "잘못된 Long Note는 Event JSON 경로와 함께 거부한다",
        run = function(test)
            local data = validStage()
            data.events = {
                { id = "event-1", type = "longNote", startBeat = 4, durationBeats = 0 },
            }
            assertInvalidStage(test, data, "$.events[1].durationBeats")
        end,
    },
    {
        name = "decoded events 객체는 배열 오류로 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local data = assert(json.decode([[
                {
                    "schemaVersion": 3,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": {}
                }
            ]]))
            assertInvalidStage(test, data, "$.events must be an array.", true)
        end,
    },
    {
        name = "decoded pattern params 배열은 객체 오류로 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local data = assert(json.decode([[
                {
                    "schemaVersion": 3,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": [{
                        "id": "event-1",
                        "type": "pattern",
                        "patternId": "empty",
                        "startBeat": 0,
                        "params": []
                    }]
                }
            ]]))
            assertInvalidStage(
                test,
                data,
                "$.events[1].params must be an object.",
                true
            )
        end,
    },
    {
        name = "decoded top-level 배열은 Stage 객체 오류로 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local data = assert(json.decode("[]"))
            assertInvalidStage(test, data, "$ must be an object.", true)
        end,
    },
    {
        name = "decoded tempo 배열 항목은 객체 오류로 거부한다",
        run = function(test)
            local data = validStage()
            data.tempoMap = {}
            assertInvalidStage(
                test,
                data,
                "$.tempoMap is not supported in schemaVersion 3.",
                true
            )
        end,
    },
    {
        name = "decoded Event 배열은 객체 오류로 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local data = validStage()
            data.events[1] = assert(json.decode("[]"))
            assertInvalidStage(test, data, "$.events[1] must be an object.", true)
        end,
    },
    {
        name = "빈 배열과 객체는 decoded 메타정보와 코드 문맥에서 승인한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local decoded = assert(json.decode([[
                {
                    "schemaVersion": 3,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": [{
                        "id": "event-1",
                        "type": "pattern",
                        "patternId": "empty",
                        "startBeat": 0,
                        "params": {}
                    }]
                }
            ]]))
            test.assertEqual(require("core").StageSchema.validate(decoded), true)

            local constructed = validStage()
            constructed.events = {
                {
                    id = "event-1",
                    type = "pattern",
                    patternId = "empty",
                    startBeat = 0,
                    params = {},
                },
            }
            test.assertEqual(require("core").StageSchema.validate(constructed), true)
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
    {
        name = "최소 Stage는 해석된 설정 기본값을 제공하고 변경값만 저장한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local minimum = {
                schemaVersion = 3,
                projectId = "sample",
                stageId = "stage-one",
                name = "Stage One",
                bpm = 120,
                events = {},
            }
            local document = assert(StageDocument.fromTable(minimum))
            test.assertEqual(document:getMixtape().volume, 1)
            test.assertEqual(document:getMixtape().beat0Offset, 0)
            test.assertEqual(document:getEditorSettings().metronomePeriod, 4)
            assert(document:setMixtapeValue("volume", 0.8))
            assert(document:setEditorSetting("scale", 2))
            local changed = document:toTable()
            test.assertEqual(changed.mixtape.volume, 0.8)
            test.assertEqual(changed.editorSettings.scale, 2)
            test.assertEqual(document:isDirty(), true)
            assert(document:setMixtapeValue("volume", 1))
            assert(document:setEditorSetting("scale", 1))
            local reverted = document:toTable()
            test.assertEqual(reverted.mixtape, nil)
            test.assertEqual(reverted.editorSettings, nil)
        end,
    },
    {
        name = "선택 설정의 동일한 해석값은 clean Stage를 dirty로 바꾸지 않는다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            assert(document:setMixtapeValue("volume", 1))
            assert(document:setEditorSetting("scale", 1))
            test.assertEqual(document:isDirty(), false)
        end,
    },
    {
        name = "Game Manager Event는 Track과 노드별 Enabled를 저장하고 이동한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))

            local endEvent = assert(document:addEvent("end", 4, 2))
            local inputEvent = assert(document:addEvent("setInputEnabled", 8, 3))
            test.assertEqual(endEvent.id, "event-001")
            test.assertEqual(inputEvent.enabled, false)
            test.assertEqual(#document:getEvents(), 2)

            assert(document:moveEvent(inputEvent.id, 12, 7))
            assert(document:setEventProperty(inputEvent.id, "enabled", true))
            local saved = document:toTable()
            test.assertEqual(saved.events[2].startBeat, 12)
            test.assertEqual(saved.events[2].track, 7)
            test.assertEqual(saved.events[2].enabled, true)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "Stage는 End Event를 하나만 허용한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.events = {
                { id = "end-1", type = "end", startBeat = 4, track = 1 },
                { id = "end-2", type = "end", startBeat = 8, track = 2 },
            }
            assertInvalidStage(test, data, "only one End")

            local document = assert(StageDocument.fromTable(validStage()))
            assert(document:addEvent("end", 4, 1))
            local added, errorMessage = document:addEvent("end", 8, 2)
            test.assertEqual(added, nil)
            test.assertContains(errorMessage, "only one End")
            test.assertEqual(#document:getEvents(), 1)
        end,
    },
    {
        name = "선택한 Timeline Event 여러 개를 한 번에 삭제한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            local first = assert(document:addEvent("end", 4, 1))
            local second = assert(document:addEvent("setInputEnabled", 8, 2))
            local third = assert(document:addEvent("tapNote", 12, 3))
            document:markClean()

            local deleted = assert(document:deleteEvents({
                [first.id] = true,
                [third.id] = true,
            }))

            test.assertEqual(deleted, 2)
            test.assertEqual(#document:getEvents(), 1)
            test.assertEqual(document:getEvents()[1].id, second.id)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "Game Manager Event 검증은 잘못된 Track과 필드를 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.events = {
                { id = "end", type = "end", startBeat = 4, track = 11 },
            }
            assertInvalidStage(test, data, ".track")

            data.events = {
                {
                    id = "input",
                    type = "setInputEnabled",
                    startBeat = 4,
                    track = 1,
                    enabled = "false",
                },
            }
            assertInvalidStage(test, data, ".enabled")
        end,
    },
    {
        name = "선택 설정은 객체만 허용한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local mixtape = validStage()
            mixtape.mixtape = assert(json.decode("[]"))
            assertInvalidStage(test, mixtape, "$.mixtape must be an object.", true)
            local editorSettings = validStage()
            editorSettings.editorSettings = "invalid"
            assertInvalidStage(
                test,
                editorSettings,
                "$.editorSettings must be an object.",
                true
            )
        end,
    },
}
