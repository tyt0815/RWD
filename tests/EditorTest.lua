return {
    {
        name = "에디터 공개 진입점은 비활성 TestPlayer를 가진 앱을 만든다",
        run = function(test)
            local Editor = require("editor")
            local app = Editor.createApp({
                projectCatalog = {
                    listProjects = function() return {}, nil end,
                    getProject = function() return nil, "missing" end,
                },
                stageRepository = {
                    listStages = function() return {}, nil end,
                    stageExists = function() return false, nil end,
                },
                testPlayer = {
                    stop = function() end,
                    update = function() return true, nil end,
                    draw = function() return true, nil end,
                },
            })

            test.assertTrue(type(app.draw) == "function")
            test.assertEqual(app:getSession():hasStage(), false)
            test.assertEqual(app:getViewModel().playing, false)
        end,
    },
}
