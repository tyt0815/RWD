local Core = require("core")

return {
    {
        name = "ProjectConfig는 요청할 때마다 Project JSON을 다시 읽는다",
        run = function(test)
            local readCount = 0
            local decoded = {
                { longStartSound = "start-a.mp3" },
                { longStartSound = "start-b.mp3" }
            }
            local config = Core.ProjectConfig.new({
                fileSystem = {
                    read = function(_, path)
                        test.assertEqual(path,
                            "projects/rhythm_dotgeo/config/speaki_song.json")
                        readCount = readCount + 1
                        return "{}", nil
                    end,
                },
                json = {
                    null = {},
                    decode = function()
                        return decoded[readCount], 3, nil
                    end,
                },
            })

            local first = assert(config:load(
                "projects/rhythm_dotgeo/config/speaki_song.json"
            ))
            local second = assert(config:load(
                "projects/rhythm_dotgeo/config/speaki_song.json"
            ))
            test.assertEqual(readCount, 2)
            test.assertEqual(first.longStartSound, "start-a.mp3")
            test.assertEqual(second.longStartSound, "start-b.mp3")
        end,
    },
}
