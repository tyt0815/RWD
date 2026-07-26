return {
    {
        name = "BeatTween은 beat 진행률로 값을 0.5박 동안 보간한다",
        run = function(test)
            local Core = require("core")
            local tween = Core.BeatTween.new(0)
            tween:start(0, 1, 4, 0.5)

            test.assertNear(tween:getValue(4), 0, 0.000001)
            test.assertNear(tween:getValue(4.25), 0.5, 0.000001)
            test.assertNear(tween:getValue(4.5), 1, 0.000001)
            test.assertNear(tween:getValue(8), 1, 0.000001)
        end,
    },
    {
        name = "BeatTween 재시작은 현재 보간값에서 새 목표로 이어진다",
        run = function(test)
            local Core = require("core")
            local tween = Core.BeatTween.new(0)
            tween:start(0, 1, 2, 0.5)
            tween:moveTo(-1, 2.25, 0.5)

            test.assertNear(tween:getValue(2.25), 0.5, 0.000001)
            test.assertNear(tween:getValue(2.75), -1, 0.000001)
        end,
    },
}
