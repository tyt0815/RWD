local function newCatalog(config)
    local MusicCatalog = require("editor.project.MusicCatalog")
    local entries = config.entries or {}
    local directories = config.directories or {}

    return MusicCatalog.new({
        getInfo = config.getInfo or function(path)
            if directories[path] then return { type = "directory" } end
            if path:match("%.%w+$") then return { type = "file" } end
            return nil
        end,
        listDirectory = config.listDirectory or function(path)
            return entries[path]
        end,
        validateProjectId = config.validateProjectId or function(projectId)
            return projectId == "sample"
        end,
    })
end

return {
    {
        name = "music 폴더가 없으면 빈 Music 목록을 반환한다",
        run = function(test)
            local catalog = newCatalog({})
            local files, errorMessage = catalog:list("sample")

            test.assertEqual(#files, 0)
            test.assertEqual(errorMessage, nil)
        end,
    },
    {
        name = "Music 목록은 하위 폴더의 지원 파일만 Project 상대 경로로 정렬한다",
        run = function(test)
            local root = "projects/sample/assets/audio/music"
            local catalog = newCatalog({
                entries = {
                    [root] = { "z.wav", "sub", "ignore.txt" },
                    [root .. "/sub"] = { "a.ogg", "b.MP3" },
                },
                directories = {
                    [root] = true,
                    [root .. "/sub"] = true,
                },
            })

            local files = assert(catalog:list("sample"))
            test.assertEqual(
                table.concat(files, "|"),
                "assets/audio/music/sub/a.ogg|assets/audio/music/sub/b.MP3|assets/audio/music/z.wav"
            )
        end,
    },
    {
        name = "Music 파일시스템 예외는 오류 값으로 반환한다",
        run = function(test)
            local root = "projects/sample/assets/audio/music"
            local catalog = newCatalog({
                directories = { [root] = true },
                listDirectory = function()
                    error("directory unavailable")
                end,
            })

            local files, errorMessage = catalog:list("sample")
            test.assertEqual(files, nil)
            test.assertContains(errorMessage, "Failed to list Project music:")
            test.assertContains(errorMessage, "directory unavailable")
        end,
    },
    {
        name = "잘못된 Project ID는 Music 경로를 만들기 전에 거부한다",
        run = function(test)
            local accessed = false
            local catalog = newCatalog({
                validateProjectId = function() return false end,
                getInfo = function()
                    accessed = true
                    return nil
                end,
            })

            local files, errorMessage = catalog:list("../sample")
            test.assertEqual(files, nil)
            test.assertEqual(errorMessage, "Invalid Project id.")
            test.assertEqual(accessed, false)
        end,
    },
}
