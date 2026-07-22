return {
    {
        name = "TempoMap converts beats and seconds exactly",
        run = function(test)
            local map = assert(require("core").TempoMap.new(120))
            test.assertNear(map:beatToSeconds(4), 2, 0.000001)
            test.assertNear(map:secondsToBeat(2), 4, 0.000001)
            test.assertEqual(map:getBpm(), 120)
        end,
    },
    {
        name = "TempoMap converts fractional beats and seconds",
        run = function(test)
            local map = assert(require("core").TempoMap.new(90))
            test.assertNear(map:beatToSeconds(1.5), 1, 0.000001)
            test.assertNear(map:secondsToBeat(1), 1.5, 0.000001)
        end,
    },
    {
        name = "TempoMap rejects invalid BPM",
        run = function(test)
            local map, errorMessage = require("core").TempoMap.new(0)
            test.assertEqual(map, nil)
            test.assertContains(errorMessage, "BPM")
        end,
    },
    {
        name = "TempoMap rejects negative and non-finite positions",
        run = function(test)
            local map = assert(require("core").TempoMap.new(120))
            test.assertEqual(map:beatToSeconds(-1), nil)
            test.assertEqual(map:secondsToBeat(0 / 0), nil)
        end,
    },
}
