return {
    {
        name = "기본 앱 창 해상도는 FHD다",
        run = function(test)
            local config = { window = {} }
            love.conf(config)

            test.assertEqual(config.window.width, 1920)
            test.assertEqual(config.window.height, 1080)
            test.assertEqual(config.window.minwidth, 1280)
            test.assertEqual(config.window.minheight, 720)
        end,
    },
    {
        name = "에디터는 확정된 다섯 패널을 순서대로 배치한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)
            local expectedLabels = { "Menu", "Categories", "Events", "Properties", "Values" }

            test.assertEqual(#layout.panels, #expectedLabels)
            for index, expectedLabel in ipairs(expectedLabels) do
                test.assertEqual(layout.panels[index].label, expectedLabel)
            end
        end,
    },
    {
        name = "타임라인은 상단 패널 아래에서 전체 너비를 사용한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)

            test.assertEqual(layout.timeline.x, 0)
            test.assertEqual(layout.timeline.y, 392)
            test.assertEqual(layout.timeline.width, 1200)
            test.assertEqual(layout.timeline.height, 408)
        end,
    },
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
