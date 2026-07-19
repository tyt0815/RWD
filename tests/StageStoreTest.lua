local function validStage(stageId)
    return {
        schemaVersion = 1,
        projectId = "sample",
        stageId = stageId or "tutorial",
        name = "Tutorial",
        tempoMap = { { startBeat = 0, bpm = 120 } },
        events = {},
    }
end

local function newFakeFileSystem()
    local fileSystem = {
        files = {},
        directoryItems = {},
        writeError = nil,
    }

    function fileSystem:list(relativePath)
        return self.directoryItems[relativePath] or {}, nil
    end

    function fileSystem:read(relativePath)
        local contents = self.files[relativePath]
        if contents == nil then
            return nil, "file not found: " .. relativePath
        end
        return contents, nil
    end

    function fileSystem:exists(relativePath)
        return self.files[relativePath] ~= nil
    end

    function fileSystem:writeAtomic(relativePath, contents)
        if self.writeError then
            return nil, self.writeError
        end
        self.files[relativePath] = contents
        return true, nil
    end

    return fileSystem
end

return {
    {
        name = "고정된 dkjson 버전을 사용한다",
        run = function(test)
            local json = require("vendor.dkjson")
            test.assertEqual(json.version, "dkjson 2.10")
        end,
    },
    {
        name = "Stage 목록은 JSON 확장자만 ID 순으로 반환한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.directoryItems["projects/sample/stages"] = {
                "zeta.json", "notes.txt", "alpha.json",
            }
            local store = StageStore.new(fileSystem)
            local stages = assert(store:listStages("sample"))
            test.assertEqual(#stages, 2)
            test.assertEqual(stages[1], "alpha")
            test.assertEqual(stages[2], "zeta")
        end,
    },
    {
        name = "StageStore는 경로 탈출 식별자를 거부한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local store = StageStore.new(newFakeFileSystem())
            local stages, errorMessage = store:listStages("../outside")
            test.assertEqual(stages, nil)
            test.assertContains(errorMessage, "projectId")
        end,
    },
    {
        name = "Stage JSON을 읽고 검증된 table을 반환한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/tutorial.json"] = json.encode(validStage())
            local store = StageStore.new(fileSystem, json)
            local data = assert(store:load("sample", "tutorial"))
            test.assertEqual(data.stageId, "tutorial")
            test.assertEqual(data.tempoMap[1].bpm, 120)
        end,
    },
    {
        name = "잘못된 JSON은 decode 오류를 반환한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/broken.json"] = "{"
            local store = StageStore.new(fileSystem)
            local data, errorMessage = store:load("sample", "broken")
            test.assertEqual(data, nil)
            test.assertContains(errorMessage, "Invalid JSON")
        end,
    },
    {
        name = "선택 Project와 JSON projectId가 다르면 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local data = validStage("wrong")
            data.projectId = "other"
            fileSystem.files["projects/sample/stages/wrong.json"] = json.encode(data)
            local store = StageStore.new(fileSystem, json)
            local loaded, errorMessage = store:load("sample", "wrong")
            test.assertEqual(loaded, nil)
            test.assertContains(errorMessage, "$.projectId")
        end,
    },
    {
        name = "Stage 저장은 ID 기반 경로와 들여쓰기 JSON을 사용한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local store = StageStore.new(fileSystem)
            assert(store:save(validStage("saved"), false))
            local contents = fileSystem.files["projects/sample/stages/saved.json"]
            test.assertTrue(contents ~= nil)
            test.assertContains(contents, "\n")
            test.assertContains(contents, '"schemaVersion"')
        end,
    },
    {
        name = "overwrite가 false면 기존 Stage를 바꾸지 않는다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local path = "projects/sample/stages/tutorial.json"
            fileSystem.files[path] = "original"
            local store = StageStore.new(fileSystem)
            local saved, errorMessage, errorCode = store:save(validStage(), false)
            test.assertEqual(saved, nil)
            test.assertEqual(errorCode, StageStore.ERROR_STAGE_EXISTS)
            test.assertEqual(fileSystem.files[path], "original")
            test.assertContains(errorMessage, "already exists")
        end,
    },
    {
        name = "원자 쓰기 실패를 호출자에게 전달한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.writeError = "disk full"
            local store = StageStore.new(fileSystem)
            local saved, errorMessage = store:save(validStage(), true)
            test.assertEqual(saved, nil)
            test.assertContains(errorMessage, "disk full")
        end,
    },
}
