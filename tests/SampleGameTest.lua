return {
    {
        name = "매니페스트의 진입 모듈로 샘플 게임을 생성한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = assert(ProjectLoader.loadProject("sample", 2))
            local game, errorMessage = ProjectLoader.createGame(project)

            test.assertEqual(errorMessage, nil)
            test.assertEqual(game.project.title, "Sample Project")
            test.assertEqual(game.elapsedTime, 0)

            local previousLove = love
            love = {
                graphics = {
                    clear = function()
                    end,
                    setColor = function()
                    end,
                    printf = function()
                    end,
                },
            }
            local drawn, drawError = pcall(function()
                game:draw(320, 180)
            end)
            love = previousLove
            test.assertTrue(drawn, drawError)
        end,
    },
    {
        name = "샘플 게임은 경과 시간을 갱신한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = assert(ProjectLoader.loadProject("sample", 2))
            local game = assert(ProjectLoader.createGame(project))

            game:update(0.25)
            test.assertEqual(game.elapsedTime, 0.25)
        end,
    },
}
