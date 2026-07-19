# 리듬게임 프로젝트 초기화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** LÖVE2D 11.5에서 공통 실행기, 에디터 UI 골격, 샘플 게임 프로젝트를 실행할 수 있고 새 세션이 즉시 작업을 이어갈 수 있는 한국어 문서 세트를 구축한다.

**Architecture:** 루트 실행기가 `core`, `editor`, `projects/sample`의 공개 진입점만 조립하는 모노레포 구조를 사용한다. 코어 API 버전과 프로젝트 매니페스트 계약을 명시해 향후 코어·에디터를 별도 버전 패키지로 분리할 수 있게 하며, 이번 범위에서는 실제 리듬 판정과 Stage 편집을 구현하지 않는다.

**Tech Stack:** LÖVE2D 11.5, LuaJIT/Lua 5.1 호환 Lua, JSON 문서 형식, PowerShell 검증 명령, Git

## Global Constraints

- 모든 사용자 대상 문서는 한국어로 작성한다.
- LÖVE2D 버전은 정확히 11.5로 설정한다.
- 클래스 역할의 테이블과 파일 이름은 `PascalCase`, 변수와 함수는 `camelCase`, 상수는 `UPPER_SNAKE_CASE`를 사용한다.
- 에디터와 프로젝트는 `require("core")` 공개 진입점만 사용하고 코어 내부 모듈을 직접 불러오지 않는다.
- 프로젝트는 에디터 모듈을 불러오지 않는다.
- 에디터 상단 표기는 `Menu | Categories | Events | Properties | Values`로 고정한다.
- 초기 Stage는 고정 BPM 하나만 지원하며 JSON에는 `tempoMap` 배열로 기록한다.
- 실제 판정, 타임라인 편집, JSON 로딩, Pattern 전개와 TestPlayer 실행은 이번 계획에 포함하지 않는다.
- 외부 Lua 라이브러리와 테스트 프레임워크를 추가하지 않는다.
- 사용자 제공 `.references/` 파일은 수정하거나 커밋하지 않는다.

---

## 파일 책임 지도

```text
main.lua                              LÖVE 콜백을 테스트 러너 또는 Launcher에 위임
conf.lua                              LÖVE 11.5 및 창 설정
core/init.lua                         코어 공개 API 버전과 판정 결과 상수
launcher/ProjectLoader.lua            프로젝트 매니페스트 로드·검증·게임 생성
launcher/Launcher.lua                 메뉴/에디터/프로젝트 실행 모드 전환
editor/init.lua                       에디터 공개 진입점
editor/EditorApp.lua                  에디터 애플리케이션 골격
editor/ui/EditorLayout.lua            다섯 패널과 타임라인 배치·렌더링
editor/playback/TestPlayer.lua        아직 재생하지 않는 TestPlayer 경계 객체
projects/sample/project.lua           샘플 프로젝트 매니페스트
projects/sample/game/SampleGame.lua   독립 샘플 게임 화면
projects/sample/stages/tutorial.json  Stage JSON 최소 예시
tests/TestSupport.lua                 테스트 단언 함수
tests/TestRunner.lua                  무의존성 테스트 실행기
tests/CoreTest.lua                    코어 공개 API 테스트
tests/ProjectLoaderTest.lua           프로젝트 계약 테스트
tests/SampleGameTest.lua              샘플 게임 생성 테스트
tests/EditorTest.lua                  에디터 레이아웃 테스트
tests/LauncherTest.lua                실행 모드 전환 테스트
AGENTS.md                             새 세션 작업 규칙
README.md                             사용자·개발자 시작 문서
docs/ARCHITECTURE.md                  모듈 경계와 데이터 흐름
docs/WORKFLOW.md                      게임 제작 흐름
docs/STAGE_FORMAT.md                  Stage JSON 명세
docs/ROADMAP.md                       단계별 개발 순서
docs/HANDOFF.md                       현재 상태와 다음 작업 인수인계
```

### Task 1: 테스트 하네스와 코어 공개 API

**Files:**
- Create: `main.lua`
- Create: `conf.lua`
- Create: `tests/TestSupport.lua`
- Create: `tests/TestRunner.lua`
- Create: `tests/CoreTest.lua`
- Create: `core/init.lua`

**Interfaces:**
- Consumes: LÖVE 콜백 `love.load`, `love.update`, `love.draw`, `love.keypressed`; 명령행 인자 `--test`
- Produces: `Core.CORE_API_VERSION: integer`, `Core.JudgmentResult: table`, `TestRunner.run(): integer`

- [ ] **Step 1: LÖVE 버전을 확인한다**

Run:

```powershell
love --version
```

Expected:

```text
LOVE 11.5 (Mysterious Mysteries)
```

- [ ] **Step 2: 테스트 하네스와 실패하는 코어 테스트를 작성한다**

Create `conf.lua`:

```lua
function love.conf(config)
    config.identity = "rwd"
    config.version = "11.5"
    config.console = true
    config.window.title = "RWD"
    config.window.width = 1200
    config.window.height = 800
    config.window.resizable = true
end
```

Create `main.lua`:

```lua
local activeApp = nil

local function containsArgument(arguments, expected)
    for _, argument in ipairs(arguments or {}) do
        if argument == expected then
            return true
        end
    end

    return false
end

local function runTests()
    local succeeded, errorMessage = xpcall(function()
        local TestRunner = require("tests.TestRunner")
        TestRunner.run()
    end, debug.traceback)

    if not succeeded then
        io.stderr:write(errorMessage .. "\n")
    end

    love.event.quit(succeeded and 0 or 1)
end

function love.load(arguments)
    if containsArgument(arguments, "--test") then
        runTests()
        return
    end

    local Launcher = require("launcher.Launcher")
    activeApp = Launcher.new()
end

function love.update(deltaTime)
    if activeApp and activeApp.update then
        activeApp:update(deltaTime)
    end
end

function love.draw()
    if activeApp and activeApp.draw then
        activeApp:draw()
    end
end

function love.keypressed(key, scanCode, isRepeat)
    if activeApp and activeApp.keypressed then
        activeApp:keypressed(key, scanCode, isRepeat)
    end
end
```

Create `tests/TestSupport.lua`:

```lua
local TestSupport = {}

function TestSupport.assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            "%s\nexpected: %s\nactual: %s",
            message or "값이 일치하지 않습니다.",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

function TestSupport.assertTrue(value, message)
    if not value then
        error(message or "참이어야 합니다.", 2)
    end
end

function TestSupport.assertContains(text, expected, message)
    if type(text) ~= "string" or not string.find(text, expected, 1, true) then
        error(message or string.format("문자열에 '%s'가 없습니다.", expected), 2)
    end
end

return TestSupport
```

Create `tests/TestRunner.lua`:

```lua
local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
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
```

Create `tests/CoreTest.lua`:

```lua
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
```

- [ ] **Step 3: 테스트가 코어 모듈 부재로 실패하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `1`, output contains `module 'core' not found`.

- [ ] **Step 4: 최소 코어 공개 API를 구현한다**

Create `core/init.lua`:

```lua
local Core = {}

Core.CORE_API_VERSION = 1

Core.JudgmentResult = {
    GOOD = "GOOD",
    BAD = "BAD",
    MISS = "MISS",
    EMPTY_INPUT = "EMPTY_INPUT",
}

return Core
```

- [ ] **Step 5: 코어 테스트가 통과하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `0`, output contains `PASS: 2 tests`.

- [ ] **Step 6: 테스트 하네스와 코어 API를 커밋한다**

```powershell
git add main.lua conf.lua core/init.lua tests/TestSupport.lua tests/TestRunner.lua tests/CoreTest.lua
git commit -m "feat: add core API and test harness"
```

### Task 2: 프로젝트 매니페스트 로더

**Files:**
- Create: `tests/ProjectLoaderTest.lua`
- Modify: `tests/TestRunner.lua`
- Create: `launcher/ProjectLoader.lua`
- Create: `projects/sample/project.lua`

**Interfaces:**
- Consumes: `Core.CORE_API_VERSION`
- Produces: `ProjectLoader.loadProject(projectId: string, coreApiVersion: integer): table|nil, string|nil`; 프로젝트 필드 `id`, `title`, `coreApiVersion`, `entryModule`

- [ ] **Step 1: 프로젝트 로드 계약 테스트를 작성한다**

Replace `tests/TestRunner.lua` with:

```lua
local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
    "tests.ProjectLoaderTest",
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
```

Create `tests/ProjectLoaderTest.lua`:

```lua
return {
    {
        name = "sample 프로젝트 매니페스트를 로드한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project, errorMessage = ProjectLoader.loadProject("sample", 1)

            test.assertEqual(errorMessage, nil)
            test.assertEqual(project.id, "sample")
            test.assertEqual(project.title, "Sample Project")
            test.assertEqual(project.entryModule, "projects.sample.game.SampleGame")
        end,
    },
    {
        name = "없는 프로젝트는 오류를 반환한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project, errorMessage = ProjectLoader.loadProject("missing", 1)

            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Failed to load project")
        end,
    },
    {
        name = "코어 API 버전이 다르면 프로젝트를 거부한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local moduleName = "projects.incompatible.project"

            package.preload[moduleName] = function()
                return {
                    id = "incompatible",
                    title = "Incompatible Project",
                    coreApiVersion = 999,
                    entryModule = "projects.sample.game.SampleGame",
                }
            end
            package.loaded[moduleName] = nil

            local project, errorMessage = ProjectLoader.loadProject("incompatible", 1)

            package.preload[moduleName] = nil
            package.loaded[moduleName] = nil

            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Core API version mismatch")
        end,
    },
}
```

- [ ] **Step 2: 테스트가 프로젝트 로더 부재로 실패하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `1`, output contains `module 'launcher.ProjectLoader' not found`.

- [ ] **Step 3: 프로젝트 매니페스트와 로더를 구현한다**

Create `projects/sample/project.lua`:

```lua
return {
    id = "sample",
    title = "Sample Project",
    coreApiVersion = 1,
    entryModule = "projects.sample.game.SampleGame",
}
```

Create `launcher/ProjectLoader.lua`:

```lua
local ProjectLoader = {}

local function validateProject(project, expectedCoreApiVersion)
    if type(project) ~= "table" then
        return "Project manifest must be a table."
    end

    local requiredStringFields = { "id", "title", "entryModule" }
    for _, fieldName in ipairs(requiredStringFields) do
        if type(project[fieldName]) ~= "string" or project[fieldName] == "" then
            return "Invalid project field: " .. fieldName
        end
    end

    if project.coreApiVersion ~= expectedCoreApiVersion then
        return string.format(
            "Core API version mismatch: project=%s, core=%s",
            tostring(project.coreApiVersion),
            tostring(expectedCoreApiVersion)
        )
    end

    return nil
end

function ProjectLoader.loadProject(projectId, coreApiVersion)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(require, moduleName)

    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. projectOrError
    end

    local validationError = validateProject(projectOrError, coreApiVersion)
    if validationError then
        return nil, validationError
    end

    return projectOrError, nil
end

return ProjectLoader
```

- [ ] **Step 4: 프로젝트 계약 테스트가 통과하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `0`, output contains `PASS: 5 tests`.

- [ ] **Step 5: 프로젝트 로더를 커밋한다**

```powershell
git add launcher/ProjectLoader.lua projects/sample/project.lua tests/TestRunner.lua tests/ProjectLoaderTest.lua
git commit -m "feat: add project manifest loader"
```

### Task 3: 독립 샘플 게임 프로젝트

**Files:**
- Create: `tests/SampleGameTest.lua`
- Modify: `tests/TestRunner.lua`
- Modify: `launcher/ProjectLoader.lua`
- Create: `projects/sample/game/SampleGame.lua`
- Create: `projects/sample/stages/tutorial.json`

**Interfaces:**
- Consumes: `ProjectLoader.loadProject(projectId, coreApiVersion)` 결과의 `entryModule`
- Produces: `ProjectLoader.createGame(project: table): SampleGame|nil, string|nil`; `SampleGame.new(project: table): SampleGame`; `SampleGame:update(deltaTime)`; `SampleGame:draw()`

- [ ] **Step 1: 샘플 게임 생성 테스트를 작성한다**

Replace `tests/TestRunner.lua` with:

```lua
local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
    "tests.ProjectLoaderTest",
    "tests.SampleGameTest",
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
```

Create `tests/SampleGameTest.lua`:

```lua
return {
    {
        name = "매니페스트의 진입 모듈로 샘플 게임을 생성한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = assert(ProjectLoader.loadProject("sample", 1))
            local game, errorMessage = ProjectLoader.createGame(project)

            test.assertEqual(errorMessage, nil)
            test.assertEqual(game.project.title, "Sample Project")
            test.assertEqual(game.elapsedTime, 0)
        end,
    },
    {
        name = "샘플 게임은 경과 시간을 갱신한다",
        run = function(test)
            local ProjectLoader = require("launcher.ProjectLoader")
            local project = assert(ProjectLoader.loadProject("sample", 1))
            local game = assert(ProjectLoader.createGame(project))

            game:update(0.25)
            test.assertEqual(game.elapsedTime, 0.25)
        end,
    },
}
```

- [ ] **Step 2: 테스트가 게임 생성 함수 부재로 실패하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `1`, output contains `attempt to call field 'createGame'`.

- [ ] **Step 3: 게임 생성 함수와 샘플 게임을 구현한다**

Replace `launcher/ProjectLoader.lua` with:

```lua
local ProjectLoader = {}

local function validateProject(project, expectedCoreApiVersion)
    if type(project) ~= "table" then
        return "Project manifest must be a table."
    end

    local requiredStringFields = { "id", "title", "entryModule" }
    for _, fieldName in ipairs(requiredStringFields) do
        if type(project[fieldName]) ~= "string" or project[fieldName] == "" then
            return "Invalid project field: " .. fieldName
        end
    end

    if project.coreApiVersion ~= expectedCoreApiVersion then
        return string.format(
            "Core API version mismatch: project=%s, core=%s",
            tostring(project.coreApiVersion),
            tostring(expectedCoreApiVersion)
        )
    end

    return nil
end

function ProjectLoader.loadProject(projectId, coreApiVersion)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(require, moduleName)

    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. projectOrError
    end

    local validationError = validateProject(projectOrError, coreApiVersion)
    if validationError then
        return nil, validationError
    end

    return projectOrError, nil
end

function ProjectLoader.createGame(project)
    local succeeded, gameModuleOrError = pcall(require, project.entryModule)

    if not succeeded then
        return nil, "Failed to load game entry module: " .. gameModuleOrError
    end

    if type(gameModuleOrError) ~= "table" or type(gameModuleOrError.new) ~= "function" then
        return nil, "Game entry module must provide new(project)."
    end

    return gameModuleOrError.new(project), nil
end

return ProjectLoader
```

Create `projects/sample/game/SampleGame.lua`:

```lua
local SampleGame = {}
SampleGame.__index = SampleGame

function SampleGame.new(project)
    return setmetatable({
        project = project,
        elapsedTime = 0,
    }, SampleGame)
end

function SampleGame:update(deltaTime)
    self.elapsedTime = self.elapsedTime + deltaTime
end

function SampleGame:draw()
    local width, height = love.graphics.getDimensions()

    love.graphics.clear(0.06, 0.08, 0.12, 1)
    love.graphics.setColor(0.55, 0.9, 1, 1)
    love.graphics.printf(self.project.title, 0, height * 0.4, width, "center")
    love.graphics.setColor(0.75, 0.78, 0.84, 1)
    love.graphics.printf("Standalone game project", 0, height * 0.4 + 36, width, "center")
    love.graphics.printf("Esc: Back to launcher", 0, height - 56, width, "center")
end

return SampleGame
```

Create `projects/sample/stages/tutorial.json`:

```json
{
  "schemaVersion": 1,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "tempoMap": [
    {
      "startBeat": 0,
      "bpm": 120
    }
  ],
  "events": []
}
```

- [ ] **Step 4: 샘플 게임 테스트와 JSON 문법을 검증한다**

Run:

```powershell
love . --test
Get-Content -Raw projects/sample/stages/tutorial.json | ConvertFrom-Json | Out-Null
```

Expected: test output contains `PASS: 7 tests`; `ConvertFrom-Json` exits without an error.

- [ ] **Step 5: 샘플 프로젝트를 커밋한다**

```powershell
git add launcher/ProjectLoader.lua projects/sample/game/SampleGame.lua projects/sample/stages/tutorial.json tests/TestRunner.lua tests/SampleGameTest.lua
git commit -m "feat: add sample game project"
```

### Task 4: 에디터 UI 골격

**Files:**
- Create: `tests/EditorTest.lua`
- Modify: `tests/TestRunner.lua`
- Create: `editor/init.lua`
- Create: `editor/EditorApp.lua`
- Create: `editor/ui/EditorLayout.lua`
- Create: `editor/playback/TestPlayer.lua`

**Interfaces:**
- Consumes: LÖVE `love.graphics` API
- Produces: `Editor.createApp(): EditorApp`; `EditorLayout.getLayout(width, height): table`; `EditorLayout.draw(width, height)`; `TestPlayer.new(): TestPlayer`; `TestPlayer:isPlaying(): boolean`

- [ ] **Step 1: 에디터 패널과 공개 진입점 테스트를 작성한다**

Replace `tests/TestRunner.lua` with:

```lua
local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
    "tests.ProjectLoaderTest",
    "tests.SampleGameTest",
    "tests.EditorTest",
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
```

Create `tests/EditorTest.lua`:

```lua
return {
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
            test.assertEqual(layout.timeline.y, 368)
            test.assertEqual(layout.timeline.width, 1200)
            test.assertEqual(layout.timeline.height, 432)
        end,
    },
    {
        name = "에디터 공개 진입점은 비활성 TestPlayer를 가진 앱을 만든다",
        run = function(test)
            local Editor = require("editor")
            local app = Editor.createApp()

            test.assertTrue(type(app.draw) == "function")
            test.assertEqual(app.testPlayer:isPlaying(), false)
        end,
    },
}
```

- [ ] **Step 2: 테스트가 에디터 모듈 부재로 실패하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `1`, output contains `module 'editor.ui.EditorLayout' not found`.

- [ ] **Step 3: 레이아웃 계산과 에디터 앱을 구현한다**

Create `editor/playback/TestPlayer.lua`:

```lua
local TestPlayer = {}
TestPlayer.__index = TestPlayer

function TestPlayer.new()
    return setmetatable({
        playing = false,
    }, TestPlayer)
end

function TestPlayer:isPlaying()
    return self.playing
end

return TestPlayer
```

Create `editor/ui/EditorLayout.lua`:

```lua
local EditorLayout = {}

local PANEL_LABELS = {
    "Menu",
    "Categories",
    "Events",
    "Properties",
    "Values",
}

local PANEL_WEIGHTS = { 1, 1.5, 1.5, 1.25, 1.25 }
local TOP_HEIGHT_RATIO = 0.46
local TIMELINE_STEP_WIDTH = 32

function EditorLayout.getLayout(width, height)
    local topHeight = math.floor(height * TOP_HEIGHT_RATIO)
    local totalWeight = 0

    for _, weight in ipairs(PANEL_WEIGHTS) do
        totalWeight = totalWeight + weight
    end

    local panels = {}
    local currentX = 0

    for index, label in ipairs(PANEL_LABELS) do
        local panelWidth
        if index == #PANEL_LABELS then
            panelWidth = width - currentX
        else
            panelWidth = math.floor(width * PANEL_WEIGHTS[index] / totalWeight)
        end

        table.insert(panels, {
            label = label,
            x = currentX,
            y = 0,
            width = panelWidth,
            height = topHeight,
        })
        currentX = currentX + panelWidth
    end

    return {
        panels = panels,
        timeline = {
            x = 0,
            y = topHeight,
            width = width,
            height = height - topHeight,
        },
    }
end

local function drawPanel(panel)
    love.graphics.setColor(0.15, 0.16, 0.17, 1)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.28, 0.29, 0.31, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print(panel.label, panel.x + 12, panel.y + 10)
end

local function drawTimeline(timeline)
    love.graphics.setColor(0.18, 0.19, 0.21, 1)
    love.graphics.rectangle("fill", timeline.x, timeline.y, timeline.width, timeline.height)

    local stepIndex = 0
    for x = timeline.x, timeline.x + timeline.width, TIMELINE_STEP_WIDTH do
        if stepIndex % 2 == 0 then
            love.graphics.setColor(0.23, 0.24, 0.26, 1)
        else
            love.graphics.setColor(0.2, 0.21, 0.23, 1)
        end

        love.graphics.rectangle("fill", x, timeline.y + 32, TIMELINE_STEP_WIDTH, timeline.height - 32)

        if stepIndex % 4 == 0 then
            love.graphics.setColor(0.82, 0.83, 0.86, 1)
            love.graphics.print(tostring(stepIndex), x + 4, timeline.y + 8)
        end

        stepIndex = stepIndex + 1
    end
end

function EditorLayout.draw(width, height)
    local layout = EditorLayout.getLayout(width, height)

    love.graphics.push("all")
    love.graphics.clear(0.08, 0.08, 0.09, 1)

    for _, panel in ipairs(layout.panels) do
        drawPanel(panel)
    end

    drawTimeline(layout.timeline)
    love.graphics.pop()
end

return EditorLayout
```

Create `editor/EditorApp.lua`:

```lua
local EditorLayout = require("editor.ui.EditorLayout")
local TestPlayer = require("editor.playback.TestPlayer")

local EditorApp = {}
EditorApp.__index = EditorApp

function EditorApp.new()
    return setmetatable({
        testPlayer = TestPlayer.new(),
    }, EditorApp)
end

function EditorApp:update(deltaTime)
end

function EditorApp:draw()
    local width, height = love.graphics.getDimensions()
    EditorLayout.draw(width, height)
end

return EditorApp
```

Create `editor/init.lua`:

```lua
local EditorApp = require("editor.EditorApp")

local Editor = {}

function Editor.createApp()
    return EditorApp.new()
end

return Editor
```

- [ ] **Step 4: 에디터 테스트가 통과하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `0`, output contains `PASS: 10 tests`.

- [ ] **Step 5: 에디터 UI 골격을 커밋한다**

```powershell
git add editor/init.lua editor/EditorApp.lua editor/ui/EditorLayout.lua editor/playback/TestPlayer.lua tests/TestRunner.lua tests/EditorTest.lua
git commit -m "feat: add editor UI skeleton"
```

### Task 5: 공통 실행기와 모드 전환

**Files:**
- Create: `tests/LauncherTest.lua`
- Modify: `tests/TestRunner.lua`
- Create: `launcher/Launcher.lua`

**Interfaces:**
- Consumes: `Core.CORE_API_VERSION`, `Editor.createApp()`, `ProjectLoader.loadProject()`, `ProjectLoader.createGame()`
- Produces: `Launcher.new(): Launcher`; `Launcher:openEditor()`; `Launcher:openProject(projectId)`; `Launcher:returnToMenu()`; `Launcher:getMode(): string`; LÖVE 콜백 위임 대상

- [ ] **Step 1: 실행 모드 전환 테스트를 작성한다**

Replace `tests/TestRunner.lua` with:

```lua
local TestSupport = require("tests.TestSupport")

local TestRunner = {}

local TEST_MODULES = {
    "tests.CoreTest",
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
```

Create `tests/LauncherTest.lua`:

```lua
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
```

- [ ] **Step 2: 테스트가 실행기 모듈 부재로 실패하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `1`, output contains `module 'launcher.Launcher' not found`.

- [ ] **Step 3: 공통 실행기를 구현한다**

Create `launcher/Launcher.lua`:

```lua
local Core = require("core")
local Editor = require("editor")
local ProjectLoader = require("launcher.ProjectLoader")

local Launcher = {}
Launcher.__index = Launcher

function Launcher.new()
    return setmetatable({
        mode = "menu",
        activeApp = nil,
        errorMessage = nil,
    }, Launcher)
end

function Launcher:getMode()
    return self.mode
end

function Launcher:getErrorMessage()
    return self.errorMessage
end

function Launcher:openEditor()
    self.activeApp = Editor.createApp()
    self.mode = "editor"
    self.errorMessage = nil
    return true
end

function Launcher:openProject(projectId)
    local project, loadError = ProjectLoader.loadProject(projectId, Core.CORE_API_VERSION)
    if not project then
        self.activeApp = nil
        self.mode = "menu"
        self.errorMessage = loadError
        return false
    end

    local game, createError = ProjectLoader.createGame(project)
    if not game then
        self.activeApp = nil
        self.mode = "menu"
        self.errorMessage = createError
        return false
    end

    self.activeApp = game
    self.mode = "project:" .. project.id
    self.errorMessage = nil
    return true
end

function Launcher:returnToMenu()
    self.activeApp = nil
    self.mode = "menu"
    self.errorMessage = nil
end

function Launcher:update(deltaTime)
    if self.activeApp and self.activeApp.update then
        self.activeApp:update(deltaTime)
    end
end

local function drawMenu(errorMessage)
    local width, height = love.graphics.getDimensions()

    love.graphics.clear(0.07, 0.08, 0.1, 1)
    love.graphics.setColor(0.92, 0.93, 0.96, 1)
    love.graphics.printf("RWD", 0, height * 0.28, width, "center")
    love.graphics.printf("E: Editor", 0, height * 0.42, width, "center")
    love.graphics.printf("1: Sample Project", 0, height * 0.42 + 32, width, "center")
    love.graphics.printf("Esc: Quit", 0, height * 0.42 + 64, width, "center")

    if errorMessage then
        love.graphics.setColor(1, 0.45, 0.45, 1)
        love.graphics.printf(errorMessage, width * 0.15, height * 0.68, width * 0.7, "center")
    end
end

function Launcher:draw()
    if self.activeApp and self.activeApp.draw then
        self.activeApp:draw()
        return
    end

    drawMenu(self.errorMessage)
end

function Launcher:keypressed(key, scanCode, isRepeat)
    if self.activeApp then
        if key == "escape" then
            self:returnToMenu()
            return
        end

        if self.activeApp.keypressed then
            self.activeApp:keypressed(key, scanCode, isRepeat)
        end
        return
    end

    if key == "e" then
        self:openEditor()
    elseif key == "1" then
        self:openProject("sample")
    elseif key == "escape" then
        love.event.quit()
    end
end

return Launcher
```

- [ ] **Step 4: 전체 자동 테스트가 통과하는지 확인한다**

Run:

```powershell
love . --test
```

Expected: exit code `0`, output contains `PASS: 14 tests`.

- [ ] **Step 5: LÖVE 실행 화면을 확인한다**

Run:

```powershell
love .
```

Expected:

- 시작 화면에 `RWD`, `E: Editor`, `1: Sample Project`가 표시된다.
- `E`를 누르면 다섯 패널과 하단 타임라인이 표시된다.
- `Esc`를 누르면 시작 화면으로 돌아온다.
- `1`을 누르면 `Sample Project` 화면이 표시된다.
- `Esc`를 다시 누르면 시작 화면으로 돌아온다.

- [ ] **Step 6: 공통 실행기를 커밋한다**

```powershell
git add launcher/Launcher.lua tests/TestRunner.lua tests/LauncherTest.lua
git commit -m "feat: add common development launcher"
```

### Task 6: 프로젝트 문서와 인수인계

**Files:**
- Modify: `.gitignore`
- Create: `.gitattributes`
- Create: `AGENTS.md`
- Create: `README.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/WORKFLOW.md`
- Create: `docs/STAGE_FORMAT.md`
- Create: `docs/ROADMAP.md`
- Create: `docs/HANDOFF.md`

**Interfaces:**
- Consumes: Tasks 1~5에서 확정된 실행 명령, 파일 구조와 테스트 결과
- Produces: 새 세션이 `AGENTS.md` → `README.md` → `docs/HANDOFF.md` 순서로 작업을 재개할 수 있는 문서 체계

- [ ] **Step 1: 생성물 무시 규칙과 텍스트 줄바꿈 규칙을 작성한다**

Create `.gitignore`:

```gitignore
.worktrees/
.superpowers/
dist/
*.love
Thumbs.db
.DS_Store
```

Create `.gitattributes`:

```gitattributes
* text=auto
*.lua text eol=lf
*.md text eol=lf
*.json text eol=lf
```

- [ ] **Step 2: 루트 작업 지침을 작성한다**

Create `AGENTS.md`:

```markdown
# AGENTS.md

## 세션 시작 순서

1. `README.md`에서 프로젝트 목표와 실행법을 확인한다.
2. `docs/HANDOFF.md`에서 현재 상태, 마지막 검증 결과와 다음 작업을 확인한다.
3. 변경할 영역의 문서를 읽는다. 구조 변경은 `docs/ARCHITECTURE.md`, Stage 변경은 `docs/STAGE_FORMAT.md`, 제작 흐름 변경은 `docs/WORKFLOW.md`를 먼저 읽는다.
4. 다단계 작업은 구현 전에 성공 기준과 짧은 계획을 작성한다.

## 프로젝트 원칙

- LÖVE2D 11.5와 LuaJIT/Lua 5.1 호환 문법을 사용한다.
- 요청된 기능에 필요한 최소 코드만 작성한다.
- 관련 없는 코드, 문서, 포맷을 함께 정리하지 않는다.
- 모호한 요구사항은 구현 전에 질문하고 선택한 해석을 문서에 남긴다.
- 사용자 소유 변경과 `.references/` 파일을 임의로 수정하거나 삭제하지 않는다.

## 모듈 경계

- `core/`는 리듬게임 공통 규칙을 소유하며 게임별 UI, 사운드와 연출을 소유하지 않는다.
- `editor/`와 `projects/`는 `require("core")`만 사용한다. `core` 내부 경로를 직접 불러오지 않는다.
- `projects/`는 `editor/`를 불러오지 않는다.
- `launcher/`는 모듈을 조립하지만 게임 규칙이나 에디터 기능을 구현하지 않는다.
- 프로젝트별 코드와 리소스는 `projects/<projectId>/` 안에 둔다.

## 코드 컨벤션

- 클래스 역할의 테이블과 파일 이름: `PascalCase`
- 변수와 함수: `camelCase`
- 상수: `UPPER_SNAKE_CASE`
- 들여쓰기: 공백 4칸
- 한 파일은 한 가지 책임만 가진다.

## 검증

- 기능 또는 버그 수정은 먼저 실패하는 테스트로 요구사항을 재현한다.
- 전체 자동 테스트는 `love . --test`로 실행한다.
- LÖVE 화면 변경은 `love .`로 직접 확인한다.
- Stage JSON은 PowerShell의 `ConvertFrom-Json`으로 문법을 확인한다.
- 완료를 보고하기 전에 실행한 명령과 결과를 `docs/HANDOFF.md`에 기록한다.

## 문서와 인수인계

- 사용자 대상 문서는 한국어로 작성한다.
- 공개 모듈 경계가 바뀌면 `docs/ARCHITECTURE.md`를 갱신한다.
- 제작 흐름이 바뀌면 `docs/WORKFLOW.md`를 갱신한다.
- Stage 필드가 바뀌면 `docs/STAGE_FORMAT.md`와 `schemaVersion` 정책을 함께 갱신한다.
- 각 작업을 마칠 때 `docs/ROADMAP.md`의 진행 상태와 `docs/HANDOFF.md`의 현재 상태, 검증 결과, 다음 작업을 갱신한다.
```

- [ ] **Step 3: 프로젝트 소개와 아키텍처 문서를 작성한다**

Create `README.md`:

````markdown
# RWD

RWD는 LÖVE2D 11.5로 여러 개의 리듬게임을 제작하기 위한 코어, 스테이지 에디터와 게임 프로젝트 모음이다. 게임 화면에는 노트를 직접 표시하지 않으며, 플레이어는 사운드와 시각적 신호에 맞춰 입력한다.

## 현재 상태

프로젝트 초기 골격 단계다. 공통 실행기, 에디터 UI 골격, 샘플 프로젝트와 Stage JSON 형식 문서가 있다. 실제 리듬 판정, 타임라인 편집과 테스트 플레이는 아직 구현하지 않았다.

## 실행 환경

- LÖVE2D 11.5
- Windows PowerShell 기준 명령

## 실행

```powershell
love .
```

- `E`: 에디터 UI 골격 열기
- `1`: Sample Project 열기
- `Esc`: 현재 화면에서 실행기로 돌아가기, 실행기에서는 종료

자동 테스트:

```powershell
love . --test
```

## 구조

```text
core/       공통 리듬게임 API
editor/     Stage 에디터와 TestPlayer 경계
launcher/   개발용 모드 및 프로젝트 선택
projects/   서로 독립적인 게임 프로젝트
tests/      외부 프레임워크 없는 스모크 테스트
docs/       아키텍처, 제작 흐름, Stage 형식, 로드맵, 인수인계
```

## 제작 방향

1. 프로젝트가 코드로 Pattern과 타임라인 Event를 정의한다.
2. 에디터가 프로젝트의 Categories와 Events를 표시한다.
3. 제작자가 Event 참조를 박자 기반 타임라인에 배치한다.
4. 에디터가 배치 정보를 Stage JSON으로 저장한다.
5. 런타임이 Pattern을 Tap Note와 Long Note 일정으로 전개한다.
6. 코어가 입력을 판정하고 프로젝트가 결과를 사운드·화면 연출로 표현한다.

자세한 내용은 `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `docs/STAGE_FORMAT.md`를 참고한다. 새 세션에서는 `docs/HANDOFF.md`를 먼저 확인한다.
````

Create `docs/ARCHITECTURE.md`:

````markdown
# 아키텍처

## 의존 방향

```text
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
Editor → Project Manifest
```

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못한다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. 현재는 `CORE_API_VERSION`과 `JudgmentResult` 상수만 제공한다. 향후 시간 변환, Pattern 전개, Tap/Long Note 판정을 이 경계 뒤에 추가한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values` 상단 영역과 하단 타임라인을 가진다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

현재 구현은 고정 패널과 타임라인을 렌더링하고, 비활성 TestPlayer 객체만 소유한다. Event 편집과 실제 프로젝트 미리보기는 현재 범위에 없다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. 실행기는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, 게임 화면, UI/UX, 사운드, 연출, 리소스와 Stage를 소유한다. 배포 도구가 추가되면 선택 프로젝트와 Core만 독립 패키지에 포함한다.

## 데이터 흐름

```text
Project가 Categories/Events 등록
→ Editor가 TimelineEvent 배치
→ Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개
→ Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
````

- [ ] **Step 4: 제작 흐름과 Stage 형식 문서를 작성한다**

Create `docs/WORKFLOW.md`:

```markdown
# 게임 제작 워크플로우

## 1. 프로젝트 생성

게임별 코드는 `projects/<projectId>/`에 둔다. `project.lua`는 프로젝트 ID, 표시 이름, 요구 코어 API 버전과 게임 진입 모듈을 선언한다. UI, 사운드, 연출과 리소스는 해당 프로젝트 밖으로 새지 않게 한다.

## 2. Pattern 작성

Pattern은 여러 박자에 걸친 신호와 플레이어 반응을 코드로 묶는 재사용 단위다. 예를 들어 첫 4박자에 효과음을 들려주고 다음 4박자에 네 번 탭하도록 만드는 Pattern을 정의할 수 있다.

Core가 판정하는 원시 노트 종류는 Tap Note와 Long Note뿐이다. Pattern은 실행 시 이 두 노트의 일정을 생성한다.

## 3. 에디터 등록

프로젝트는 에디터에 Categories와 Events를 제공한다. Categories에는 `Global`, `Game Manager`, 미니게임 단위가 들어갈 수 있다. Events에는 Pattern, 개별 Tap/Long Note와 게임 관리 항목이 들어갈 수 있다.

## 4. Stage 편집

제작자는 에디터에서 프로젝트와 Stage를 선택하고 Event를 박자 기반 타임라인에 배치한다. Stage JSON에는 Pattern이 만든 노트를 펼치지 않고 `patternId`, `startBeat`, `params`를 저장한다.

## 5. 테스트 플레이

완성될 TestPlayer는 Stage 배치를 읽고 프로젝트 코드를 에디터 우측 상단 Canvas에서 실시간 실행한다. 에디터 타임라인과 TestPlayer는 같은 코어 재생 시계를 공유한다.

## 6. 게임 연출

Core는 `JudgmentResult`만 전달한다. Project는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT`에 대응하는 화면, 사운드와 UX를 구현한다.

## 7. 독립 배포

배포 시에는 선택 프로젝트의 코드·리소스·Stage와 호환 Core만 포함한다. Editor와 다른 Project는 포함하지 않는다. 패키징 도구는 로드맵의 후속 단계에서 구현한다.
```

Create `docs/STAGE_FORMAT.md`:

````markdown
# Stage JSON 형식

## 버전 1 예시

```json
{
  "schemaVersion": 1,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "tempoMap": [
    {
      "startBeat": 0,
      "bpm": 120
    }
  ],
  "events": [
    {
      "id": "event-001",
      "type": "pattern",
      "patternId": "fourTapResponse",
      "startBeat": 8,
      "params": {}
    },
    {
      "id": "event-002",
      "type": "tapNote",
      "startBeat": 24
    },
    {
      "id": "event-003",
      "type": "longNote",
      "startBeat": 28,
      "durationBeats": 2
    }
  ]
}
```

## 상위 필드

- `schemaVersion`: 형식 버전. 현재 지원 값은 정수 `1`이다.
- `projectId`: Stage를 해석할 프로젝트 ID다.
- `stageId`: 프로젝트 안에서 고유한 Stage ID다.
- `name`: 표시 이름이다.
- `tempoMap`: BPM 항목 배열이다. 현재는 `startBeat: 0`인 항목 하나만 허용한다.
- `events`: 타임라인 배치 항목 배열이다.

## Event 공통 필드

- `id`: Stage 안에서 고유한 문자열이다.
- `type`: `pattern`, `tapNote`, `longNote` 중 하나다.
- `startBeat`: 0 이상의 박자 위치다.

`pattern`은 프로젝트 코드에 등록된 `patternId`와 JSON 객체인 `params`를 사용한다. `params`를 생략하면 빈 객체로 취급한다. `longNote`는 0보다 큰 `durationBeats`를 사용한다.

## 변경 규칙

버전 1 런타임은 템포 항목을 하나만 처리한다. 향후 BPM 변경을 구현할 때 `tempoMap`에 추가 항목을 허용한다. 기존 필드 의미를 깨는 변경은 `schemaVersion`을 증가시키고 이전 버전 변환 정책을 함께 문서화한다.

## 로드 오류 원칙

- 지원하지 않는 `schemaVersion`은 Stage를 적용하지 않고 거부한다.
- 존재하지 않는 `patternId`는 해당 Event `id`와 함께 보고하고 테스트 플레이를 차단한다.
- 잘못된 필드 값은 가능한 경우 JSON 경로를 오류에 포함한다.
- 로드가 실패하면 현재 편집 중인 Stage 상태를 변경하지 않는다.
````

- [ ] **Step 5: 로드맵을 작성한다**

Create `docs/ROADMAP.md`:

```markdown
# 개발 로드맵

## 0. 프로젝트 초기화

- [x] Core, Editor, Project 모듈 경계 설계
- [x] LÖVE2D 11.5 공통 실행기
- [x] 에디터 UI 골격
- [x] Sample Project
- [x] Stage JSON 버전 1 문서
- [x] 자동 스모크 테스트와 인수인계 문서

## 1. 시간과 판정 코어

- [ ] 고정 BPM 재생 시계
- [ ] 박자와 초 변환
- [ ] Tap Note 판정
- [ ] Long Note 판정 방식 설계 및 구현
- [ ] `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 판정 테스트

## 2. Pattern과 Stage 런타임

- [ ] 프로젝트 Event 등록 계약
- [ ] Stage JSON 검증과 로딩
- [ ] Pattern 참조와 파라미터 전개
- [ ] 존재하지 않는 Pattern 오류 처리

## 3. 에디터 편집 기능

- [ ] 프로젝트와 Stage 선택
- [ ] Categories와 Events 목록
- [ ] Properties와 Values 편집
- [ ] 타임라인 배치, 이동, 삭제
- [ ] JSON 저장과 불러오기

## 4. TestPlayer

- [ ] 프로젝트 실시간 Canvas 렌더링
- [ ] 에디터 타임라인과 공통 재생 시계
- [ ] 재생, 일시정지와 위치 이동
- [ ] 프로젝트 입력 전달

## 5. 배포와 엔진 버전 관리

- [ ] 선택 Project와 Core만 포함하는 독립 패키징
- [ ] Core API 호환 버전 검사 확장
- [ ] 버전형 Core·Editor 패키지 분리 검토
```

- [ ] **Step 6: 자동·수동 검증을 모두 실행한다**

Run:

```powershell
love --version
love . --test
Get-Content -Raw projects/sample/stages/tutorial.json | ConvertFrom-Json | Out-Null
rg -n 'require\("core\.' editor projects
rg -n 'require\("editor' projects
git diff --check
```

Expected:

- LÖVE output is `LOVE 11.5 (Mysterious Mysteries)`.
- Tests output `PASS: 14 tests` and exit code `0`.
- JSON parsing exits without an error.
- Both forbidden-dependency `rg` commands produce no matches.
- `git diff --check` produces no output.

Run the GUI once more:

```powershell
love .
```

Expected: Launcher, Editor, Sample Project and both `Esc` return transitions match Task 5 Step 5.

- [ ] **Step 7: 검증 결과를 담은 인수인계 문서를 작성한다**

Create `docs/HANDOFF.md`:

```markdown
# 인수인계

## 현재 상태

프로젝트 초기화 단계가 완료되었다. LÖVE2D 11.5 공통 실행기에서 에디터 UI 골격과 Sample Project를 열 수 있다. Core는 API 버전과 네 가지 판정 결과 상수만 제공하며 실제 리듬 판정은 아직 없다.

## 완료된 작업

- Core, Editor, Launcher, Project의 공개 경계 생성
- 프로젝트 매니페스트와 Core API 버전 호환 검사
- 독립 Sample Project 화면과 빈 Tutorial Stage JSON 생성
- `Menu | Categories | Events | Properties | Values` 에디터 패널과 하단 타임라인 렌더링
- 외부 프레임워크 없는 14개 자동 테스트 작성
- 아키텍처, 제작 흐름, Stage 형식과 로드맵 문서 작성

## 최근 검증

- `love --version`: `LOVE 11.5 (Mysterious Mysteries)` 확인
- `love . --test`: `PASS: 14 tests` 확인
- `tutorial.json`: PowerShell `ConvertFrom-Json` 통과
- 금지된 내부 Core 의존성과 Project→Editor 의존성 없음
- `love .`: Launcher, Editor, Sample Project 화면과 `Esc` 복귀 동작 확인

## 다음 작업

다음 개발 단위는 고정 BPM 재생 시계다. 구현 전에 박자 기준 시각, 오디오 재생 위치 보정 방식, 일시정지와 위치 이동 동작을 별도 설계로 확정한다. Tap/Long Note 판정 허용 범위와 Long Note 판정 방식은 재생 시계 이후 별도 설계한다.

## 현재 범위 밖인 기능

- 실제 리듬 판정
- Stage JSON 로딩과 검증
- Pattern 등록 및 전개
- 에디터 Event 편집과 저장
- 실시간 TestPlayer
- 독립 게임 패키징

## 세션 재개 순서

1. `README.md`를 읽는다.
2. `docs/ARCHITECTURE.md`와 `docs/ROADMAP.md`를 확인한다.
3. `love . --test`를 실행한다.
4. 다음 작업인 고정 BPM 재생 시계를 설계한다.
```

- [ ] **Step 8: 문서와 저장소 설정을 커밋한다**

```powershell
git add .gitignore .gitattributes AGENTS.md README.md docs/ARCHITECTURE.md docs/WORKFLOW.md docs/STAGE_FORMAT.md docs/ROADMAP.md docs/HANDOFF.md
git diff --cached --check
git commit -m "docs: add project guides and handoff"
```

- [ ] **Step 9: 최종 상태를 확인한다**

Run:

```powershell
git log --oneline -6
git status --short
```

Expected: 구현 계획의 기능·문서 커밋이 최근 기록에 나타난다. `git status --short`에는 사용자가 제공한 `.references/`만 나타나며, `.superpowers/`는 `.gitignore`로 제외된다.
