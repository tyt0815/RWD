local PATHS = {
    stageDirectory = function(projectId)
        return "projects/" .. projectId .. "/stages"
    end,
    stageFile = function(projectId, stageId)
        return "projects/" .. projectId .. "/stages/" .. stageId .. ".json"
    end,
}

local function validStage(stageId)
    return {
        schemaVersion = 3,
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
        operationLog = {},
        renameErrors = {},
    }

    function fileSystem:list(path)
        if self.listError then return nil, self.listError end
        return self.directoryItems[path] or {}, nil
    end

    function fileSystem:read(path)
        if self.readError then return nil, self.readError end
        local contents = self.files[path]
        if contents == nil then return nil, "missing file: " .. path end
        return contents, nil
    end

    function fileSystem:isFile(path)
        return self.files[path] ~= nil and not self.directories[path]
    end

    function fileSystem:exists(path)
        if self.existsError then return nil, self.existsError end
        return self.files[path] ~= nil
    end

    function fileSystem:write(path, contents)
        table.insert(self.operationLog, "write(" .. path .. ")")
        if self.writeError then return nil, self.writeError end
        self.files[path] = contents
        return true, nil
    end

    function fileSystem:remove(path)
        table.insert(self.operationLog, "remove(" .. path .. ")")
        if self.removeError then return nil, self.removeError end
        self.files[path] = nil
        return true, nil
    end

    function fileSystem:rename(sourcePath, targetPath)
        table.insert(self.operationLog, "rename(" .. sourcePath .. "," .. targetPath .. ")")
        local renameError = self.renameErrors[sourcePath .. "->" .. targetPath]
        if renameError then return nil, renameError end
        if self.files[sourcePath] == nil then return nil, "missing source: " .. sourcePath end
        self.files[targetPath] = self.files[sourcePath]
        self.files[sourcePath] = nil
        return true, nil
    end

    function fileSystem:copy(sourcePath, targetPath)
        table.insert(self.operationLog, "copy(" .. sourcePath .. "," .. targetPath .. ")")
        if self.copyError then return nil, self.copyError end
        if self.files[sourcePath] == nil then return nil, "missing source: " .. sourcePath end
        self.files[targetPath] = self.files[sourcePath]
        return true, nil
    end

    return fileSystem
end

local function newRepository(fileSystem, json)
    return require("core").StageRepository.new({
        fileSystem = fileSystem,
        paths = PATHS,
        json = json or require("vendor.dkjson"),
    })
end

local function assertError(test, expectedCode, expectedText, first, message, code)
    test.assertEqual(first, nil)
    test.assertEqual(code, expectedCode)
    test.assertContains(message, expectedText)
end

return {
    {
        name = "StageRepository lists safe Stage files in ID order",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local directory = PATHS.stageDirectory("sample")
            fileSystem.directoryItems[directory] = {
                "zeta.json", "notes.txt", "alpha.json", "con.json", "folder.json",
            }
            fileSystem.files[directory .. "/zeta.json"] = "{}"
            fileSystem.files[directory .. "/alpha.json"] = "{}"
            fileSystem.files[directory .. "/con.json"] = "{}"
            fileSystem.files[directory .. "/folder.json"] = "{}"
            fileSystem.directories[directory .. "/folder.json"] = true

            local stageIds = assert(newRepository(fileSystem):listStages("sample"))
            test.assertEqual(#stageIds, 2)
            test.assertEqual(stageIds[1], "alpha")
            test.assertEqual(stageIds[2], "zeta")
        end,
    },
    {
        name = "StageRepository asserts its injected dependency contract",
        run = function(test)
            local json = require("vendor.dkjson")
            local fileSystem = newFakeFileSystem()
            local validOptions = { fileSystem = fileSystem, paths = PATHS, json = json }
            local cases = {
                { options = {}, message = "fileSystem is required" },
                { options = { fileSystem = fileSystem }, message = "paths is required" },
                {
                    options = { fileSystem = fileSystem, paths = {}, json = json },
                    message = "paths.stageDirectory is required",
                },
                {
                    options = {
                        fileSystem = fileSystem,
                        paths = { stageDirectory = PATHS.stageDirectory },
                        json = json,
                    },
                    message = "paths.stageFile is required",
                },
                { options = { fileSystem = fileSystem, paths = PATHS }, message = "json is required" },
                {
                    options = { fileSystem = fileSystem, paths = PATHS, json = {} },
                    message = "json.decode is required",
                },
                {
                    options = {
                        fileSystem = fileSystem,
                        paths = PATHS,
                        json = { decode = json.decode },
                    },
                    message = "json.encode is required",
                },
            }
            for _, case in ipairs(cases) do
                local succeeded, errorMessage = pcall(function()
                    require("core").StageRepository.new(case.options)
                end)
                test.assertEqual(succeeded, false)
                test.assertContains(errorMessage, case.message)
            end
            test.assertTrue(require("core").StageRepository.new(validOptions) ~= nil)
        end,
    },
    {
        name = "StageRepository rejects unsafe path identifiers",
        run = function(test)
            local repository = newRepository(newFakeFileSystem())
            assertError(test, "INVALID_STAGE", "projectId", repository:listStages("../outside"))
            assertError(test, "INVALID_STAGE", "stageId", repository:stageExists("sample", "con"))
            assertError(test, "INVALID_STAGE", "stageId", repository:load("sample", "../outside"))
        end,
    },
    {
        name = "StageRepository reports missing Stage files",
        run = function(test)
            local repository = newRepository(newFakeFileSystem())
            assertError(test, "NOT_FOUND", "does not exist", repository:load("sample", "missing"))
        end,
    },
    {
        name = "StageRepository reports list, exists, and read primitive failures",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            fileSystem.listError = "list denied"
            assertError(test, "READ_FAILED", "list denied", newRepository(fileSystem):listStages("sample"))

            fileSystem.listError = nil
            fileSystem.existsError = "stat denied"
            assertError(
                test,
                "READ_FAILED",
                "stat denied",
                newRepository(fileSystem):stageExists("sample", "tutorial")
            )

            fileSystem.existsError = nil
            fileSystem.files[PATHS.stageFile("sample", "tutorial")] = "{}"
            fileSystem.readError = "read denied"
            assertError(test, "READ_FAILED", "read denied", newRepository(fileSystem):load("sample", "tutorial"))
        end,
    },
    {
        name = "StageRepository distinguishes JSON decode and trailing-content failures",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "broken")
            fileSystem.files[path] = "{"
            local repository = newRepository(fileSystem)
            assertError(test, "DECODE_FAILED", "Invalid JSON", repository:load("sample", "broken"))

            fileSystem.files[path] = require("vendor.dkjson").encode(validStage("broken")) .. " trailing"
            assertError(test, "DECODE_FAILED", "trailing content", repository:load("sample", "broken"))
        end,
    },
    {
        name = "StageRepository rejects decoded schemaVersion and field errors",
        run = function(test)
            local json = require("vendor.dkjson")
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "invalid")
            local stage = validStage("invalid")
            stage.schemaVersion = 2
            fileSystem.files[path] = json.encode(stage)
            assertError(test, "INVALID_STAGE", "schemaVersion", newRepository(fileSystem):load("sample", "invalid"))

            stage.schemaVersion = 3
            stage.bpm = -1
            fileSystem.files[path] = json.encode(stage)
            assertError(test, "INVALID_STAGE", "bpm", newRepository(fileSystem):load("sample", "invalid"))
        end,
    },
    {
        name = "StageRepository verifies decoded IDs against the selected path",
        run = function(test)
            local json = require("vendor.dkjson")
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            local stage = validStage()
            stage.projectId = "other"
            fileSystem.files[path] = json.encode(stage)
            assertError(test, "INVALID_STAGE", "selected Project", newRepository(fileSystem):load("sample", "tutorial"))

            stage.projectId = "sample"
            stage.stageId = "other"
            fileSystem.files[path] = json.encode(stage)
            assertError(test, "INVALID_STAGE", "file name", newRepository(fileSystem):load("sample", "tutorial"))
        end,
    },
    {
        name = "StageRepository load returns a defensive normalized schemaVersion 3 table",
        run = function(test)
            local decoded = validStage()
            decoded.editorSettings = { snap = 1, scale = 2 }
            local json = {
                decode = function(contents)
                    return decoded, #contents + 1, nil
                end,
                encode = function()
                    return "{}"
                end,
            }
            local fileSystem = newFakeFileSystem()
            fileSystem.files[PATHS.stageFile("sample", "tutorial")] = "fixture"

            local loaded = assert(newRepository(fileSystem, json):load("sample", "tutorial"))
            test.assertEqual(loaded.schemaVersion, 3)
            test.assertEqual(loaded.editorSettings.snap, nil)
            test.assertEqual(loaded.editorSettings.scale, 2)
            loaded.name = "Changed"
            test.assertEqual(decoded.name, "Tutorial")
            test.assertEqual(decoded.editorSettings.snap, 1)
        end,
    },
    {
        name = "StageRepository save normalizes a copy and atomically replaces an existing Stage",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            fileSystem.files[path] = "original"
            local stage = validStage()
            stage.editorSettings = { snap = 1, scale = 2 }
            stage.events = {
                {
                    id = "event-1",
                    startBeat = 0,
                    track = 1,
                    type = "projectEvent",
                    categoryId = "sampleGameplay",
                    eventId = "spawnActors",
                    params = {},
                },
            }

            assert(newRepository(fileSystem):save(stage, true))
            local temporaryPath = path .. ".tmp"
            local backupPath = path .. ".bak"
            test.assertEqual(fileSystem.operationLog[1], "write(" .. temporaryPath .. ")")
            test.assertEqual(fileSystem.operationLog[2], "rename(" .. path .. "," .. backupPath .. ")")
            test.assertEqual(fileSystem.operationLog[3], "rename(" .. temporaryPath .. "," .. path .. ")")
            test.assertEqual(fileSystem.operationLog[4], "remove(" .. backupPath .. ")")
            test.assertEqual(#fileSystem.operationLog, 4)
            test.assertEqual(fileSystem.files[temporaryPath], nil)
            test.assertEqual(fileSystem.files[backupPath], nil)
            test.assertEqual(stage.editorSettings.snap, 1)
            test.assertEqual(getmetatable(stage.events[1].params), nil)
            test.assertTrue(fileSystem.files[path]:find('"categoryId"', 1, true)
                < fileSystem.files[path]:find('"eventId"', 1, true))
        end,
    },
    {
        name = "StageRepository preserves an existing Stage when overwrite is false",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            fileSystem.files[path] = "original"
            assertError(test, "STAGE_EXISTS", "already exists", newRepository(fileSystem):save(validStage(), false))
            test.assertEqual(fileSystem.files[path], "original")
            test.assertEqual(#fileSystem.operationLog, 0)
        end,
    },
    {
        name = "StageRepository rejects invalid input before writing",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local stage = validStage()
            stage.schemaVersion = 2
            assertError(test, "INVALID_STAGE", "schemaVersion", newRepository(fileSystem):save(stage, true))
            test.assertEqual(#fileSystem.operationLog, 0)
        end,
    },
    {
        name = "StageRepository reports JSON encode exceptions before writing",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local json = {
                decode = function() return {}, 1, nil end,
                encode = function() error("encoder exploded") end,
            }
            assertError(test, "WRITE_FAILED", "encoder exploded", newRepository(fileSystem, json):save(validStage(), true))
            test.assertEqual(#fileSystem.operationLog, 0)
        end,
    },
    {
        name = "StageRepository cleans the temporary file after a temporary write failure",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            fileSystem.writeError = "disk full"
            assertError(test, "WRITE_FAILED", "disk full", newRepository(fileSystem):save(validStage(), true))
            test.assertEqual(fileSystem.operationLog[1], "write(" .. path .. ".tmp)")
            test.assertEqual(fileSystem.operationLog[2], "remove(" .. path .. ".tmp)")
            test.assertEqual(#fileSystem.operationLog, 2)
        end,
    },
    {
        name = "StageRepository cleans the temporary file when a new Stage replace fails",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            fileSystem.renameErrors[path .. ".tmp->" .. path] = "replace blocked"
            assertError(test, "WRITE_FAILED", "replace blocked", newRepository(fileSystem):save(validStage(), true))
            test.assertEqual(fileSystem.files[path], nil)
            test.assertEqual(fileSystem.files[path .. ".tmp"], nil)
            test.assertEqual(fileSystem.operationLog[3], "remove(" .. path .. ".tmp)")
        end,
    },
    {
        name = "StageRepository restores an existing Stage by rollback rename",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            local backupPath = path .. ".bak"
            fileSystem.files[path] = "original"
            fileSystem.renameErrors[path .. ".tmp->" .. path] = "replace blocked"
            assertError(test, "WRITE_FAILED", "replace blocked", newRepository(fileSystem):save(validStage(), true))
            test.assertEqual(fileSystem.files[path], "original")
            test.assertEqual(fileSystem.files[backupPath], nil)
            test.assertEqual(
                fileSystem.operationLog[5],
                "rename(" .. backupPath .. "," .. path .. ")"
            )
        end,
    },
    {
        name = "StageRepository restores by copy and removes the backup when rollback rename fails",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            local backupPath = path .. ".bak"
            fileSystem.files[path] = "original"
            fileSystem.renameErrors[path .. ".tmp->" .. path] = "replace blocked"
            fileSystem.renameErrors[backupPath .. "->" .. path] = "rollback blocked"
            assertError(test, "WRITE_FAILED", "rollback blocked", newRepository(fileSystem):save(validStage(), true))
            test.assertEqual(fileSystem.files[path], "original")
            test.assertEqual(fileSystem.files[backupPath], nil)
            test.assertEqual(fileSystem.operationLog[6], "copy(" .. backupPath .. "," .. path .. ")")
            test.assertEqual(fileSystem.operationLog[7], "remove(" .. backupPath .. ")")
        end,
    },
    {
        name = "StageRepository retains the backup path when every rollback method fails",
        run = function(test)
            local fileSystem = newFakeFileSystem()
            local path = PATHS.stageFile("sample", "tutorial")
            local backupPath = path .. ".bak"
            fileSystem.files[path] = "original"
            fileSystem.renameErrors[path .. ".tmp->" .. path] = "replace blocked"
            fileSystem.renameErrors[backupPath .. "->" .. path] = "rollback blocked"
            fileSystem.copyError = "copy blocked"
            local saved, message, code = newRepository(fileSystem):save(validStage(), true)
            assertError(test, "WRITE_FAILED", backupPath, saved, message, code)
            test.assertContains(message, "rollback blocked")
            test.assertContains(message, "copy blocked")
            test.assertEqual(fileSystem.files[backupPath], "original")
        end,
    },
}
