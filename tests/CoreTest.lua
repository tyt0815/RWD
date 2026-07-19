return {
    {
        name = "코어 API 버전은 1이다",
        run = function(test)
            local Core = require("core")
            test.assertEqual(Core.CORE_API_VERSION, 1)
        end,
    },
    {
        name = "코어는 네 가지 판정 결과를 공개한다",
        run = function(test)
            local Core = require("core")
            test.assertEqual(Core.JudgmentResult.GOOD, "GOOD")
            test.assertEqual(Core.JudgmentResult.BAD, "BAD")
            test.assertEqual(Core.JudgmentResult.MISS, "MISS")
            test.assertEqual(Core.JudgmentResult.EMPTY_INPUT, "EMPTY_INPUT")
        end,
    },
}
