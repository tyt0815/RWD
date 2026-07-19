return {
    {
        name = "재생 시계는 0박자에서 일시정지 상태로 시작한다",
        run = function(test)
            local PlaybackClock = require("core.PlaybackClock")
            local clock = assert(PlaybackClock.new(120))

            test.assertEqual(clock:isPlaying(), false)
            test.assertEqual(clock:getBeat(), 0)
            test.assertEqual(clock:getBpm(), 120)
        end,
    },
    {
        name = "재생 중 deltaTime을 BPM 기준 beat로 변환한다",
        run = function(test)
            local PlaybackClock = require("core.PlaybackClock")
            local clock = assert(PlaybackClock.new(120))

            clock:play()
            clock:update(1.5)
            test.assertNear(clock:getBeat(), 3, 0.000001)
        end,
    },
    {
        name = "Pause는 beat를 보존하고 Play는 같은 위치에서 재개한다",
        run = function(test)
            local PlaybackClock = require("core.PlaybackClock")
            local clock = assert(PlaybackClock.new(60))

            clock:play()
            clock:update(2)
            clock:pause()
            clock:update(5)
            test.assertNear(clock:getBeat(), 2, 0.000001)

            clock:play()
            clock:update(1)
            test.assertNear(clock:getBeat(), 3, 0.000001)
        end,
    },
    {
        name = "재생 중 BPM 변경은 현재 beat를 보존한다",
        run = function(test)
            local PlaybackClock = require("core.PlaybackClock")
            local clock = assert(PlaybackClock.new(120))

            clock:play()
            clock:update(1)
            assert(clock:setBpm(60))
            test.assertNear(clock:getBeat(), 2, 0.000001)
            clock:update(1)
            test.assertNear(clock:getBeat(), 3, 0.000001)
        end,
    },
    {
        name = "재생 시계는 유효하지 않은 BPM을 거부한다",
        run = function(test)
            local PlaybackClock = require("core.PlaybackClock")

            local zeroClock, zeroError = PlaybackClock.new(0)
            local nanClock, nanError = PlaybackClock.new(0 / 0)
            test.assertEqual(zeroClock, nil)
            test.assertContains(zeroError, "BPM")
            test.assertEqual(nanClock, nil)
            test.assertContains(nanError, "BPM")
        end,
    },
}
