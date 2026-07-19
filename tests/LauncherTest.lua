return {
    {
        name = "실행기는 메뉴 모드로 시작한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            test.assertEqual(launcher:getMode(), "menu")
        end,
    },
    {
        name = "에디터 모드로 전환한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            launcher:openEditor()
            test.assertEqual(launcher:getMode(), "editor")
            test.assertTrue(launcher.activeApp ~= nil)
        end,
    },
    {
        name = "sample 프로젝트 모드로 전환한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            local succeeded = launcher:openProject("sample")
            test.assertEqual(succeeded, true)
            test.assertEqual(launcher:getMode(), "project:sample")
        end,
    },
    {
        name = "없는 프로젝트는 메뉴에 남아 오류를 기록한다",
        run = function(test)
            local Launcher = require("launcher.Launcher")
            local launcher = Launcher.new()

            local succeeded = launcher:openProject("missing")
            test.assertEqual(succeeded, false)
            test.assertEqual(launcher:getMode(), "menu")
            test.assertContains(launcher:getErrorMessage(), "Failed to load project")
        end,
    },
}
