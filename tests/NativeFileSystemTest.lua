local function newFakeNativeOperations()
    local operations = {
        calls = {},
        files = {},
        directoryItems = {},
    }

    function operations:list(path)
        table.insert(self.calls, { "list", path })
        if self.rejectAbsoluteList and path:match("^%a:[/\\]") then
            return nil, "list path must be source-relative"
        end
        return self.directoryItems[path] or {}, nil
    end

    function operations:read(path)
        table.insert(self.calls, { "read", path })
        return self.files[path], self.files[path] and nil or "missing"
    end

    function operations:isFile(path)
        table.insert(self.calls, { "isFile", path })
        return self.files[path] ~= nil
    end

    function operations:exists(path)
        table.insert(self.calls, { "exists", path })
        return self.files[path] ~= nil
    end

    function operations:write(path, contents)
        table.insert(self.calls, { "write", path, contents })
        self.files[path] = contents
        return true, nil
    end

    function operations:remove(path)
        table.insert(self.calls, { "remove", path })
        self.files[path] = nil
        return true, nil
    end

    function operations:rename(sourcePath, targetPath)
        table.insert(self.calls, { "rename", sourcePath, targetPath })
        self.files[targetPath] = self.files[sourcePath]
        self.files[sourcePath] = nil
        return true, nil
    end

    function operations:copy(sourcePath, targetPath)
        table.insert(self.calls, { "copy", sourcePath, targetPath })
        self.files[targetPath] = self.files[sourcePath]
        return true, nil
    end

    return operations
end

local function withLoveFilesystem(fileSystem, callback)
    local originalLove = love
    love = { filesystem = fileSystem }
    local succeeded, errorMessage = xpcall(callback, debug.traceback)
    love = originalLove
    if not succeeded then error(errorMessage, 0) end
end

local function withIoOpen(openFile, callback)
    local originalOpen = io.open
    io.open = openFile
    local succeeded, errorMessage = xpcall(callback, debug.traceback)
    io.open = originalOpen
    if not succeeded then error(errorMessage, 0) end
end

return {
    {
        name = "Launcher NativeFileSystem keeps unpackaged list source-relative and joins file paths",
        run = function(test)
            local NativeFileSystem = require("launcher.NativeFileSystem")
            local operations = newFakeNativeOperations()
            local directory = "projects/sample/stages"
            local root = "C:/project"
            local target = root .. "/" .. directory .. "/tutorial.json"
            operations.rejectAbsoluteList = true
            operations.directoryItems[directory] = { "tutorial.json" }
            operations.files[target] = "original"
            local fileSystem = NativeFileSystem.new(root .. "///", operations)

            local items = assert(fileSystem:list(directory))
            test.assertEqual(items[1], "tutorial.json")
            test.assertEqual(assert(fileSystem:read(directory .. "/tutorial.json")), "original")
            test.assertEqual(fileSystem:isFile(directory .. "/tutorial.json"), true)
            test.assertEqual(fileSystem:exists(directory .. "/tutorial.json"), true)
            assert(fileSystem:write(directory .. "/new.json", "new"))
            assert(fileSystem:copy(directory .. "/new.json", directory .. "/copy.json"))
            assert(fileSystem:rename(directory .. "/copy.json", directory .. "/moved.json"))
            assert(fileSystem:remove(directory .. "/moved.json"))

            local expected = {
                { "list", directory },
                { "read", target },
                { "isFile", target },
                { "exists", target },
                { "write", root .. "/" .. directory .. "/new.json", "new" },
                {
                    "copy",
                    root .. "/" .. directory .. "/new.json",
                    root .. "/" .. directory .. "/copy.json",
                },
                {
                    "rename",
                    root .. "/" .. directory .. "/copy.json",
                    root .. "/" .. directory .. "/moved.json",
                },
                { "remove", root .. "/" .. directory .. "/moved.json" },
            }
            test.assertEqual(#operations.calls, #expected)
            for index, call in ipairs(expected) do
                test.assertEqual(operations.calls[index][1], call[1])
                test.assertEqual(operations.calls[index][2], call[2])
                test.assertEqual(operations.calls[index][3], call[3])
            end
        end,
    },
    {
        name = "Launcher NativeFileSystem preserves native access errors from exists",
        run = function(test)
            local NativeFileSystem = require("launcher.NativeFileSystem")
            withIoOpen(function()
                return nil, "permission denied", 13
            end, function()
                local exists, errorMessage = NativeFileSystem.new("C:/project"):exists("locked.json")
                test.assertEqual(exists, nil)
                test.assertContains(errorMessage, "permission denied")
            end)
        end,
    },
    {
        name = "Launcher NativeFileSystem treats native missing files as absent",
        run = function(test)
            local NativeFileSystem = require("launcher.NativeFileSystem")
            withIoOpen(function()
                return nil, "no such file", 2
            end, function()
                local exists, errorMessage = NativeFileSystem.new("C:/project"):exists("missing.json")
                test.assertEqual(exists, false)
                test.assertEqual(errorMessage, nil)
            end)
        end,
    },
    {
        name = "Launcher NativeFileSystem reads packaged sources through love.filesystem",
        run = function(test)
            local NativeFileSystem = require("launcher.NativeFileSystem")
            local operations = newFakeNativeOperations()
            local calls = {}
            local fakeLoveFileSystem = {
                getDirectoryItems = function(path)
                    table.insert(calls, { "list", path })
                    return { "tutorial.json" }
                end,
                read = function(path)
                    table.insert(calls, { "read", path })
                    return "packaged", 8
                end,
                getInfo = function(path, requestedType)
                    table.insert(calls, { "getInfo", path, requestedType })
                    return { type = "file" }
                end,
            }
            local originalLove = love
            withLoveFilesystem(fakeLoveFileSystem, function()
                local fileSystem = NativeFileSystem.new("C:/game.LOVE", operations)
                test.assertEqual(assert(fileSystem:list("projects/sample/stages"))[1], "tutorial.json")
                test.assertEqual(assert(fileSystem:read("projects/sample/stages/tutorial.json")), "packaged")
                test.assertEqual(fileSystem:isFile("projects/sample/stages/tutorial.json"), true)
                test.assertEqual(fileSystem:exists("projects/sample/stages/tutorial.json"), true)
            end)
            test.assertEqual(love, originalLove)
            test.assertEqual(#operations.calls, 0)
            test.assertEqual(calls[1][2], "projects/sample/stages")
            test.assertEqual(calls[2][2], "projects/sample/stages/tutorial.json")
            test.assertEqual(calls[3][3], "file")
            test.assertEqual(calls[4][3], "file")
        end,
    },
    {
        name = "Launcher NativeFileSystem rejects every packaged mutation without native calls",
        run = function(test)
            local NativeFileSystem = require("launcher.NativeFileSystem")
            local operations = newFakeNativeOperations()
            local fakeLoveFileSystem = {}
            local originalLove = love
            withLoveFilesystem(fakeLoveFileSystem, function()
                local fileSystem = NativeFileSystem.new("C:/game.love", operations)
                local mutations = {
                    function() return fileSystem:write("target", "contents") end,
                    function() return fileSystem:remove("target") end,
                    function() return fileSystem:rename("source", "target") end,
                    function() return fileSystem:copy("source", "target") end,
                }
                for _, mutation in ipairs(mutations) do
                    local result, message = mutation()
                    test.assertEqual(result, nil)
                    test.assertEqual(message, "Cannot write Stage files inside a packaged .love source.")
                end
            end)
            test.assertEqual(love, originalLove)
            test.assertEqual(#operations.calls, 0)
        end,
    },
}
