return {
    {
        name = "매니페스트의 진입 모듈로 샘플 게임을 생성한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = assert(ProjectLoader.loadProject("sample", 2))
            local game, errorMessage = ProjectLoader.createGame(project, {
                stageRepository = {},
            })

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
}
