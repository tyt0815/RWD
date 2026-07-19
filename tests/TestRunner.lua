local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
    "tests.PlaybackClockTest",
    "tests.ProjectLoaderTest",
    "tests.SampleGameTest",
    "tests.EditorTest",
    "tests.LauncherTest",
}

function TestRunner.run()
    local passedCount = 0
    local failures = {}

    for _, moduleName in ipairs(TEST_MODULES) do
        local testCases = require(moduleName)

        for _, testCase in ipairs(testCases) do
            local succeeded, errorMessage = xpcall(function()
                testCase.run(TestSupport)
            end, debug.traceback)

            if succeeded then
                passedCount = passedCount + 1
            else
                table.insert(failures, testCase.name .. "\n" .. errorMessage)
            end
        end
    end

    if #failures > 0 then
        error("FAIL: " .. #failures .. " test(s)\n" .. table.concat(failures, "\n\n"), 0)
    end

    print("PASS: " .. passedCount .. " tests")
    return passedCount
end

return TestRunner
