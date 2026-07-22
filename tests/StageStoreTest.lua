local function validStage(stageId)
    return {
        schemaVersion = 2,
        projectId = "sample",
        stageId = stageId or "tutorial",
        name = "Tutorial",
        bpm = 120,
        events = {},
    }
end

local function newFakeFileSystem()
    local fileSystem = {
        files = {},
        directories = {},
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

    function fileSystem:isFile(relativePath)
        return not self.directories[relativePath]
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

local function newFakeNativeOperations()
    local operations = {
        files = {},
        directoryItems = {},
        renameErrors = {},
        copyError = nil,
        mutationCount = 0,
    }

    function operations:list(relativePath)
        return self.directoryItems[relativePath] or {}, nil
    end

    function operations:read(path)
        local contents = self.files[path]
        if contents == nil then
            return nil, "file not found: " .. path
        end
        return contents, nil
    end

    function operations:isFile(path)
        return self.files[path] ~= nil
    end

    function operations:write(path, contents)
        self.mutationCount = self.mutationCount + 1
        self.files[path] = contents
        return true, nil
    end

    function operations:exists(path)
        return self.files[path] ~= nil
    end

    function operations:remove(path)
        self.mutationCount = self.mutationCount + 1
        self.files[path] = nil
        return true, nil
    end

    function operations:rename(sourcePath, targetPath)
        self.mutationCount = self.mutationCount + 1
        local renameError = self.renameErrors[sourcePath .. "->" .. targetPath]
        if renameError then
            return nil, renameError
        end
        if self.files[sourcePath] == nil then
            return nil, "missing source: " .. sourcePath
        end
        self.files[targetPath] = self.files[sourcePath]
        self.files[sourcePath] = nil
        return true, nil
    end

    function operations:copy(sourcePath, targetPath)
        self.mutationCount = self.mutationCount + 1
        if self.copyError then
            return nil, self.copyError
        end
        if self.files[sourcePath] == nil then
            return nil, "missing source: " .. sourcePath
        end
        self.files[targetPath] = self.files[sourcePath]
        return true, nil
    end

    return operations
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
        name = "Stage 목록은 안전한 실제 JSON 파일만 ID 순으로 반환한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.directoryItems["projects/sample/stages"] = {
                "zeta.json", "notes.txt", "alpha.json", "con.json",
                "aux.json", "com1.json", "folder.json",
            }
            fileSystem.directories["projects/sample/stages/folder.json"] = true
            local store = StageStore.new(fileSystem)
            local stages = assert(store:listStages("sample"))
            test.assertEqual(#stages, 2)
            test.assertEqual(stages[1], "alpha")
            test.assertEqual(stages[2], "zeta")
        end,
    },
    {
        name = "네이티브 Stage 입출력은 sourceRoot 경계를 함께 사용한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local NativeFileSystem = require("editor.stage.NativeFileSystem")
            local StageStore = require("editor.stage.StageStore")
            local operations = newFakeNativeOperations()
            local directory = "projects/sample/stages"
            local sourcePath = "C:/project/" .. directory .. "/tutorial.json"
            local shadowPath = directory .. "/tutorial.json"
            operations.directoryItems[directory] = { "save-only.json", "tutorial.json" }
            local sourceStage = validStage()
            sourceStage.name = "Source Tutorial"
            local shadowStage = validStage()
            shadowStage.name = "Shadow Tutorial"
            operations.files[sourcePath] = json.encode(sourceStage)
            operations.files[shadowPath] = json.encode(shadowStage)

            local store = StageStore.new(NativeFileSystem.new("C:/project", operations), json)
            local stages = assert(store:listStages("sample"))
            test.assertEqual(#stages, 1)
            test.assertEqual(stages[1], "tutorial")
            local saveOnlyExists, existsError = store:stageExists("sample", "save-only")
            test.assertEqual(existsError, nil)
            test.assertEqual(saveOnlyExists, false)

            local loaded = assert(store:load("sample", "tutorial"))
            test.assertEqual(loaded.name, "Source Tutorial")
            assert(store:save(validStage(), true))
            test.assertTrue(operations.files[sourcePath] ~= nil)
            test.assertEqual(operations.files[shadowPath], json.encode(shadowStage))
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

            local reservedProjectStages, reservedProjectError = store:listStages("con")
            test.assertEqual(reservedProjectStages, nil)
            test.assertContains(reservedProjectError, "projectId")

            local reservedStageExists, reservedStageError = store:stageExists("sample", "com1")
            test.assertEqual(reservedStageExists, nil)
            test.assertContains(reservedStageError, "stageId")

            local auxiliaryStageExists, auxiliaryStageError = store:stageExists("sample", "aux")
            test.assertEqual(auxiliaryStageExists, nil)
            test.assertContains(auxiliaryStageError, "stageId")
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
            test.assertEqual(data.bpm, 120)
        end,
    },
    {
        name = "pattern params 내부 JSON null은 문서 왕복 뒤에도 보존된다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageDocument = require("editor.stage.StageDocument")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local path = "projects/sample/stages/tutorial.json"
            fileSystem.files[path] = [[
                {
                    "schemaVersion": 2,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": [{
                        "id": "event-1",
                        "type": "pattern",
                        "patternId": "nullable",
                        "startBeat": 0,
                        "params": {"optional": null}
                    }]
                }
            ]]
            local store = StageStore.new(fileSystem, json)
            local loaded = assert(store:load("sample", "tutorial"))
            local document = assert(StageDocument.fromTable(loaded))
            local documentData = document:toTable()
            test.assertEqual(documentData.events[1].params.optional, json.null)
            assert(store:save(documentData, true))

            local roundTrip = assert(json.decode(fileSystem.files[path], 1, json.null))
            test.assertEqual(roundTrip.events[1].params.optional, json.null)
        end,
    },
    {
        name = "events 배열의 JSON null은 Event 경로 오류로 거부한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/tutorial.json"] = [[
                {
                    "schemaVersion": 2,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": [null]
                }
            ]]
            local loaded, errorMessage = StageStore.new(fileSystem):load("sample", "tutorial")
            test.assertEqual(loaded, nil)
            test.assertContains(errorMessage, "$.events[1]")
        end,
    },
    {
        name = "pattern params의 JSON null은 객체 오류로 거부한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/tutorial.json"] = [[
                {
                    "schemaVersion": 2,
                    "projectId": "sample",
                    "stageId": "tutorial",
                    "name": "Tutorial",
                    "bpm": 120,
                    "events": [{
                        "id": "event-1",
                        "type": "pattern",
                        "patternId": "nullable",
                        "startBeat": 0,
                        "params": null
                    }]
                }
            ]]
            local loaded, errorMessage = StageStore.new(fileSystem):load("sample", "tutorial")
            test.assertEqual(loaded, nil)
            test.assertContains(errorMessage, "$.events[1].params must be an object")
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
        name = "Stage load는 JSON schema와 경로 ID 일치를 검증한다",
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

            local mismatchedStage = validStage("inside")
            fileSystem.files["projects/sample/stages/mismatch.json"] = json.encode(mismatchedStage)
            local mismatched, mismatchError = store:load("sample", "mismatch")
            test.assertEqual(mismatched, nil)
            test.assertContains(mismatchError, "$.stageId")

            local invalidSchema = validStage("invalid")
            invalidSchema.schemaVersion = 1
            fileSystem.files["projects/sample/stages/invalid.json"] = json.encode(invalidSchema)
            local invalid, invalidError = store:load("sample", "invalid")
            test.assertEqual(invalid, nil)
            test.assertContains(invalidError, "$.schemaVersion")
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
        name = "코드 생성 빈 pattern params는 객체로 저장하고 다시 읽는다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local data = validStage("empty-params")
            data.events = {
                {
                    id = "event-1",
                    type = "pattern",
                    patternId = "empty",
                    startBeat = 0,
                    params = {},
                },
            }
            local originalParams = data.events[1].params
            local store = StageStore.new(fileSystem, json)
            assert(store:save(data, false))

            local loaded, loadError = store:load("sample", "empty-params")
            test.assertTrue(loaded ~= nil, loadError)
            local encoded = fileSystem.files["projects/sample/stages/empty-params.json"]
            local saved = assert(json.decode(encoded, 1, json.null))
            test.assertEqual(getmetatable(saved.events[1].params).__jsontype, "object")
            test.assertEqual(getmetatable(originalParams), nil)
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
            local NativeFileSystem = require("editor.stage.NativeFileSystem")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.writeError = "disk full"
            local store = StageStore.new(fileSystem)
            local saved, errorMessage = store:save(validStage(), true)
            test.assertEqual(saved, nil)
            test.assertContains(errorMessage, "disk full")

            local packagedOperations = newFakeNativeOperations()
            local packagedFileSystem = NativeFileSystem.new("C:/game.love", packagedOperations)
            local packaged, packagedError = packagedFileSystem:writeAtomic(
                "projects/sample/stages/tutorial.json",
                "replacement"
            )
            test.assertEqual(packaged, nil)
            test.assertContains(packagedError, "packaged .love")
            test.assertEqual(packagedOperations.mutationCount, 0)

            local relativePath = "projects/sample/stages/tutorial.json"
            local targetPath = "C:/project/" .. relativePath
            local temporaryPath = targetPath .. ".tmp"
            local backupPath = targetPath .. ".bak"
            local recoveryOperations = newFakeNativeOperations()
            recoveryOperations.files[targetPath] = "original"
            recoveryOperations.renameErrors[temporaryPath .. "->" .. targetPath] = "replace blocked"
            recoveryOperations.renameErrors[backupPath .. "->" .. targetPath] = "rollback blocked"
            local recoveryFileSystem = NativeFileSystem.new("C:/project", recoveryOperations)
            local replaced, replaceError = recoveryFileSystem:writeAtomic(relativePath, "replacement")
            test.assertEqual(replaced, nil)
            test.assertContains(replaceError, "replace blocked")
            test.assertEqual(recoveryOperations.files[targetPath], "original")
            test.assertEqual(recoveryOperations.files[backupPath], nil)

            local failedOperations = newFakeNativeOperations()
            failedOperations.files[targetPath] = "original"
            failedOperations.renameErrors[temporaryPath .. "->" .. targetPath] = "replace blocked"
            failedOperations.renameErrors[backupPath .. "->" .. targetPath] = "rollback blocked"
            failedOperations.copyError = "copy blocked"
            local failedFileSystem = NativeFileSystem.new("C:/project", failedOperations)
            local failed, recoveryError = failedFileSystem:writeAtomic(relativePath, "replacement")
            test.assertEqual(failed, nil)
            test.assertContains(recoveryError, "replace blocked")
            test.assertContains(recoveryError, "rollback blocked")
            test.assertContains(recoveryError, "copy blocked")
            test.assertContains(recoveryError, backupPath)
            test.assertEqual(failedOperations.files[backupPath], "original")
        end,
    },
}
