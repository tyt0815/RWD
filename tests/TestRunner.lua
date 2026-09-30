-- 등록된 Lua 테스트 모듈의 각 testCase.run을 실행하고 실패를 모아 보고한다.
-- main.lua의 --test 분기에서 호출되며 실패는 프로세스 종료 코드 1로 이어진다.

local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
    "tests.TapJudgmentTest",
    "tests.LongNoteJudgmentTest",
    "tests.PlayerActionTest",
    "tests.BeatTweenTest",
    "tests.ProjectManifestTest",
    "tests.ProjectEventsTest",
    "tests.ProjectCategoriesTest",
    "tests.ProjectConfigTest",
    "tests.StageRuntimeTest",
    "tests.ProjectGameplayTest",
    "tests.MixtapeSettingsTest",
    "tests.PlaybackClockTest",
    "tests.MusicPlaybackTest",
    "tests.TempoMapTest",
    "tests.PlaybackTransportTest",
    "tests.MetronomePlaybackTest",
    "tests.StageSchemaTest",
    "tests.TimelineSnapTest",
    "tests.TimelineEventGeometryTest",
    "tests.StageRepositoryTest",
    "tests.NativeFileSystemTest",
    "tests.ModuleBoundaryTest",
    "tests.StageDocumentTest",
    "tests.ProjectLoaderTest",
    "tests.ProjectCatalogTest",
    "tests.MusicCatalogTest",
    "tests.SampleGameTest",
    "tests.RhythmDotgeoGameTest",
    "tests.SpeakiSongSoundsTest",
    "tests.TestPlayerTest",
    "tests.EditorSessionTest",
    "tests.EditorUiTest",
    "tests.ButtonTest",
    "tests.ComboBoxTest",
    "tests.ScrollAreaTest",
    "tests.EditorDialogTest",
    "tests.EditorWorkflowTest",
    "tests.MusicOnsetDetectorTest",
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
