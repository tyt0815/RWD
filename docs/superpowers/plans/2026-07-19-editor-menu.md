# 에디터 Menu와 Stage 작업 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에디터에서 새 Stage 생성, 프로젝트 내부 JSON 열기·저장, dirty 보호, BPM 편집, Play/Pause 플레이헤드와 Project TestPlayer Canvas, Launcher 복귀를 마우스로 사용할 수 있게 한다.

**Architecture:** `EditorApp`은 입력과 화면만 조율하고 `EditorSession`, `StageDocument`, `StageStore`, `PlaybackClock`, `TestPlayer`, `EditorMenu`, `EditorDialog`에 상태와 동작을 위임한다. Stage 파일은 검증된 `projects/<projectId>/stages/<stageId>.json` 경계 안에서만 읽고 쓰며, TestPlayer는 Project 앱을 Canvas에 렌더링하지만 Stage Event는 아직 실행하지 않는다.

**Tech Stack:** LÖVE2D 11.5, LuaJIT/Lua 5.1 호환 Lua, dkjson 2.10 단일 파일, JSON schema version 1, 기존 무의존 테스트 러너, PowerShell, Git

## Global Constraints

- LÖVE 버전은 `11.5`로 유지한다.
- 클래스 역할의 테이블과 파일 이름은 `PascalCase`, 변수와 함수는 `camelCase`, 상수는 `UPPER_SNAKE_CASE`를 사용한다.
- 들여쓰기는 공백 4칸이며 한 파일은 한 가지 책임만 가진다.
- Editor와 Project는 `require("core")` 공개 진입점만 사용하고 Project는 Editor를 불러오지 않는다.
- Menu 항목은 `New`, `Open`, `Save`, `Save As`, `Play`, `Pause`, `Quit`만 허용하며 `Upload`를 추가하지 않는다.
- Menu는 마우스로만 조작하고 문자 입력용 키와 모달의 Enter/Escape만 지원한다.
- Stage 파일 이름은 항상 `<stageId>.json`이고 접근 범위는 선택 Project의 `stages` 폴더 안이다.
- Stage version 1은 `startBeat: 0`인 BPM 항목 하나를 사용하고 향후 BPM 변경을 위해 `tempoMap` 배열 형태를 유지한다.
- Play/Pause는 Event 실행, 오디오 동기화, 판정과 프로젝트 입력을 구현하지 않는다.
- 사용자 소유 `.references/` 파일은 수정, 삭제 또는 커밋하지 않는다.
- 기능 구현은 실패하는 테스트를 먼저 확인하고 각 Task 끝에 전체 `love . --test`를 실행한다.
- 화면 변경은 최종 Task에서 실제 LÖVE GUI와 마우스 기반 하네스로 확인한다.

---

## 파일 구조

```text
core/PlaybackClock.lua                 고정 BPM beat 시계
core/init.lua                          PlaybackClock 공개
editor/stage/StageDocument.lua         Stage v1 생성·검증·dirty 모델
editor/stage/NativeFileSystem.lua      원본 Project 폴더의 안전한 네이티브 I/O
editor/stage/StageStore.lua            Stage 목록·JSON 읽기·쓰기
editor/project/ProjectCatalog.lua      Project 매니페스트 탐색과 게임 생성
editor/EditorSession.lua               현재 Stage·저장·재생 상태
editor/menu/EditorMenu.lua             Menu 항목·활성 상태·hit test·그리기
editor/ui/EditorDialog.lua             입력·선택·확인·오류 모달
editor/ui/EditorLayout.lua             다섯 패널·타임라인·BPM·미리보기 배치
editor/playback/TestPlayer.lua         Project Canvas 호스트
editor/EditorApp.lua                   메뉴·모달·세션 통합
editor/init.lua                        onQuit/options 전달
launcher/Launcher.lua                  Editor Quit 콜백과 draw 크기 전달
main.lua                               마우스·문자 입력 콜백 전달
projects/sample/game/SampleGame.lua    draw(width, height) 계약 적용
vendor/dkjson.lua                      dkjson 2.10 원본
vendor/dkjson.LICENSE.txt              dkjson 라이선스
tests/PlaybackClockTest.lua            재생 시계 테스트
tests/StageDocumentTest.lua             Stage 모델 테스트
tests/ProjectCatalogTest.lua            Project 탐색 테스트
tests/StageStoreTest.lua                JSON 저장소 테스트
tests/TestPlayerTest.lua                Canvas 호스트 테스트
tests/EditorSessionTest.lua             편집 상태 흐름 테스트
tests/EditorUiTest.lua                  Menu·Layout 테스트
tests/EditorWorkflowTest.lua            모달·EditorApp 통합 테스트
tests/TestSupport.lua                   근삿값 단언 추가
tests/TestRunner.lua                    새 테스트 모듈 등록
README.md                               실행과 Menu 사용법
docs/ARCHITECTURE.md                    새 Editor/Core 경계
docs/WORKFLOW.md                        Stage 파일 작업 흐름
docs/STAGE_FORMAT.md                    현재 구현된 검증 규칙
docs/ROADMAP.md                         진행 상태
docs/HANDOFF.md                         구현·검증 인수인계
```

---

### Task 1: 고정 BPM PlaybackClock

**Files:**
- Create: `core/PlaybackClock.lua`
- Create: `tests/PlaybackClockTest.lua`
- Modify: `core/init.lua`
- Modify: `tests/TestSupport.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: 양수이면서 유한한 `bpm: number`, `deltaTime: number`
- Produces: `PlaybackClock.new(bpm): PlaybackClock|nil, error`; `play()`; `pause()`; `reset(bpm?)`; `update(deltaTime)`; `setBpm(bpm)`; `getBpm()`; `getBeat()`; `isPlaying()`

- [ ] **Step 1: 근삿값 단언과 실패 테스트를 작성한다**

`tests/TestSupport.lua`에 다음 함수를 추가한다.

```lua
function TestSupport.assertNear(actual, expected, tolerance, message)
    if math.abs(actual - expected) > tolerance then
        error(string.format(
            "%s\nexpected: %s ± %s\nactual: %s",
            message or "값이 허용 오차를 벗어났습니다.",
            tostring(expected),
            tostring(tolerance),
            tostring(actual)
        ), 2)
    end
end
```

`tests/PlaybackClockTest.lua`를 다음 다섯 테스트로 만든다.

```lua
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
```

`tests/TestRunner.lua`의 `TEST_MODULES`에서 `tests.CoreTest` 다음에 `tests.PlaybackClockTest`를 추가한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'core.PlaybackClock' not found`가 포함된 실패.

- [ ] **Step 3: 최소 PlaybackClock을 구현한다**

`core/PlaybackClock.lua`:

```lua
local PlaybackClock = {}
PlaybackClock.__index = PlaybackClock

local function isValidBpm(bpm)
    return type(bpm) == "number"
        and bpm == bpm
        and bpm > 0
        and bpm < math.huge
end

function PlaybackClock.new(bpm)
    if not isValidBpm(bpm) then
        return nil, "BPM must be a positive finite number."
    end

    return setmetatable({
        bpm = bpm,
        beat = 0,
        playing = false,
    }, PlaybackClock)
end

function PlaybackClock:play()
    self.playing = true
end

function PlaybackClock:pause()
    self.playing = false
end

function PlaybackClock:reset(bpm)
    if bpm ~= nil then
        local changed, errorMessage = self:setBpm(bpm)
        if not changed then
            return nil, errorMessage
        end
    end

    self.beat = 0
    self.playing = false
    return true, nil
end

function PlaybackClock:update(deltaTime)
    if self.playing then
        self.beat = self.beat + deltaTime * self.bpm / 60
    end
end

function PlaybackClock:setBpm(bpm)
    if not isValidBpm(bpm) then
        return nil, "BPM must be a positive finite number."
    end

    self.bpm = bpm
    return true, nil
end

function PlaybackClock:getBpm()
    return self.bpm
end

function PlaybackClock:getBeat()
    return self.beat
end

function PlaybackClock:isPlaying()
    return self.playing
end

return PlaybackClock
```

`core/init.lua`에서 공개한다.

```lua
Core.PlaybackClock = require("core.PlaybackClock")
```

- [ ] **Step 4: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 21 tests`.

- [ ] **Step 5: 커밋한다**

```powershell
git add core/PlaybackClock.lua core/init.lua tests/PlaybackClockTest.lua tests/TestSupport.lua tests/TestRunner.lua
git commit -m "feat: add fixed BPM playback clock"
```

---

### Task 2: StageDocument 생성·검증·dirty 모델

**Files:**
- Create: `editor/stage/StageDocument.lua`
- Create: `tests/StageDocumentTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: Stage version 1 Lua table 또는 `projectId`, `stageId`, `name`, `bpm`
- Produces: `StageDocument.create(...): StageDocument|nil,error`; `fromTable(data)`; `validate(data)`; `isSafeId(value)`; `toTable()`; `isDirty()`; `markClean()`; `setBpm(bpm)`; `cloneAs(stageId,name)`

- [ ] **Step 1: 여덟 개 실패 테스트를 작성한다**

`tests/StageDocumentTest.lua`는 다음 동작을 각각 별도 test case로 검증한다.

```lua
local function validStage()
    return {
        schemaVersion = 1,
        projectId = "sample",
        stageId = "tutorial",
        name = "Tutorial",
        tempoMap = { { startBeat = 0, bpm = 120 } },
        events = {},
    }
end

return {
    {
        name = "새 Stage는 단일 BPM과 빈 타임라인으로 생성된다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.create("sample", "new-stage", "New Stage", 120))
            local data = document:toTable()

            test.assertEqual(data.schemaVersion, 1)
            test.assertEqual(data.tempoMap[1].startBeat, 0)
            test.assertEqual(data.tempoMap[1].bpm, 120)
            test.assertEqual(#data.events, 0)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "Stage 식별자는 경로 문자를 허용하지 않는다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document, errorMessage = StageDocument.create("sample", "../escape", "Bad", 120)
            test.assertEqual(document, nil)
            test.assertContains(errorMessage, "$.stageId")
        end,
    },
    {
        name = "Stage는 0 이하와 유한하지 않은 BPM을 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local zeroDocument, zeroError = StageDocument.create("sample", "zero", "Zero", 0)
            local nanDocument, nanError = StageDocument.create("sample", "nan", "NaN", 0 / 0)
            test.assertEqual(zeroDocument, nil)
            test.assertContains(zeroError, "$.tempoMap[1].bpm")
            test.assertEqual(nanDocument, nil)
            test.assertContains(nanError, "$.tempoMap[1].bpm")
        end,
    },
    {
        name = "BPM 변경은 값을 바꾸고 dirty로 표시한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            test.assertEqual(document:isDirty(), false)
            assert(document:setBpm(90))
            test.assertEqual(document:getBpm(), 90)
            test.assertEqual(document:isDirty(), true)
        end,
    },
    {
        name = "같은 BPM은 clean Stage를 dirty로 바꾸지 않는다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local document = assert(StageDocument.fromTable(validStage()))
            assert(document:setBpm(120))
            test.assertEqual(document:isDirty(), false)
        end,
    },
    {
        name = "지원하지 않는 schemaVersion은 JSON 경로와 함께 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.schemaVersion = 2
            local errorMessage = StageDocument.validate(data)
            test.assertContains(errorMessage, "$.schemaVersion")
        end,
    },
    {
        name = "잘못된 Long Note는 Event JSON 경로와 함께 거부한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local data = validStage()
            data.events = {
                { id = "event-1", type = "longNote", startBeat = 4, durationBeats = 0 },
            }
            local errorMessage = StageDocument.validate(data)
            test.assertContains(errorMessage, "$.events[1].durationBeats")
        end,
    },
    {
        name = "Save As 복제는 원본을 바꾸지 않고 새 ID와 이름을 사용한다",
        run = function(test)
            local StageDocument = require("editor.stage.StageDocument")
            local original = assert(StageDocument.fromTable(validStage()))
            local copy = assert(original:cloneAs("tutorial-copy", "Tutorial Copy"))
            test.assertEqual(original:getStageId(), "tutorial")
            test.assertEqual(copy:getStageId(), "tutorial-copy")
            test.assertEqual(copy:getName(), "Tutorial Copy")
            test.assertEqual(copy:isDirty(), true)
        end,
    },
}
```

`tests/TestRunner.lua`에서 `tests.PlaybackClockTest` 다음에 `tests.StageDocumentTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.stage.StageDocument' not found`가 포함된 실패.

- [ ] **Step 3: StageDocument를 구현한다**

`editor/stage/StageDocument.lua`는 다음 검증 순서를 사용한다.

```lua
local StageDocument = {}
StageDocument.__index = StageDocument

local SAFE_ID_PATTERN = "^[a-z0-9][a-z0-9_-]*$"

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

local function isArray(value)
    if type(value) ~= "table" then
        return false
    end

    local count = 0
    local maximum = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
        maximum = math.max(maximum, key)
    end
    return maximum == count
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(item, seen)
    end
    return setmetatable(copy, getmetatable(value))
end

function StageDocument.isSafeId(value)
    return type(value) == "string" and value:match(SAFE_ID_PATTERN) ~= nil
end

local function validateEvent(event, index)
    local path = "$.events[" .. index .. "]"
    if type(event) ~= "table" then
        return path .. " must be an object."
    end
    if type(event.id) ~= "string" or event.id == "" then
        return path .. ".id must be a non-empty string."
    end
    if not isFiniteNumber(event.startBeat) or event.startBeat < 0 then
        return path .. ".startBeat must be a non-negative finite number."
    end
    if event.type == "pattern" then
        if type(event.patternId) ~= "string" or event.patternId == "" then
            return path .. ".patternId must be a non-empty string."
        end
        if event.params ~= nil and type(event.params) ~= "table" then
            return path .. ".params must be an object."
        end
    elseif event.type == "tapNote" then
        return nil
    elseif event.type == "longNote" then
        if not isFiniteNumber(event.durationBeats) or event.durationBeats <= 0 then
            return path .. ".durationBeats must be a positive finite number."
        end
    else
        return path .. ".type must be pattern, tapNote, or longNote."
    end
    return nil
end

function StageDocument.validate(data)
    if type(data) ~= "table" then
        return "$ must be an object."
    end
    if data.schemaVersion ~= 1 then
        return "$.schemaVersion must be 1."
    end
    if not StageDocument.isSafeId(data.projectId) then
        return "$.projectId must be a safe identifier."
    end
    if not StageDocument.isSafeId(data.stageId) then
        return "$.stageId must be a safe identifier."
    end
    if type(data.name) ~= "string" or data.name == "" then
        return "$.name must be a non-empty string."
    end
    if not isArray(data.tempoMap) or #data.tempoMap ~= 1 then
        return "$.tempoMap must contain exactly one item."
    end
    local tempo = data.tempoMap[1]
    if type(tempo) ~= "table" or tempo.startBeat ~= 0 then
        return "$.tempoMap[1].startBeat must be 0."
    end
    if not isFiniteNumber(tempo.bpm) or tempo.bpm <= 0 then
        return "$.tempoMap[1].bpm must be a positive finite number."
    end
    if not isArray(data.events) then
        return "$.events must be an array."
    end
    local eventIds = {}
    for index, event in ipairs(data.events) do
        local eventError = validateEvent(event, index)
        if eventError then
            return eventError
        end
        if eventIds[event.id] then
            return "$.events[" .. index .. "].id must be unique."
        end
        eventIds[event.id] = true
    end
    return nil
end

local function newDocument(data, dirty)
    local validationError = StageDocument.validate(data)
    if validationError then
        return nil, validationError
    end
    return setmetatable({ data = deepCopy(data), dirty = dirty }, StageDocument), nil
end

function StageDocument.create(projectId, stageId, name, bpm)
    return newDocument({
        schemaVersion = 1,
        projectId = projectId,
        stageId = stageId,
        name = name,
        tempoMap = { { startBeat = 0, bpm = bpm } },
        events = {},
    }, true)
end

function StageDocument.fromTable(data)
    return newDocument(data, false)
end

function StageDocument:toTable()
    return deepCopy(self.data)
end

function StageDocument:getProjectId()
    return self.data.projectId
end

function StageDocument:getStageId()
    return self.data.stageId
end

function StageDocument:getName()
    return self.data.name
end

function StageDocument:getBpm()
    return self.data.tempoMap[1].bpm
end

function StageDocument:isDirty()
    return self.dirty
end

function StageDocument:markClean()
    self.dirty = false
end

function StageDocument:setBpm(bpm)
    if not isFiniteNumber(bpm) or bpm <= 0 then
        return nil, "$.tempoMap[1].bpm must be a positive finite number."
    end
    if self.data.tempoMap[1].bpm ~= bpm then
        self.data.tempoMap[1].bpm = bpm
        self.dirty = true
    end
    return true, nil
end

function StageDocument:cloneAs(stageId, name)
    local data = self:toTable()
    data.stageId = stageId
    data.name = name
    return newDocument(data, true)
end

return StageDocument
```

- [ ] **Step 4: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 29 tests`.

- [ ] **Step 5: 커밋한다**

```powershell
git add editor/stage/StageDocument.lua tests/StageDocumentTest.lua tests/TestRunner.lua
git commit -m "feat: add stage document model"
```

---

### Task 3: ProjectCatalog 탐색과 게임 생성

**Files:**
- Create: `editor/project/ProjectCatalog.lua`
- Create: `tests/ProjectCatalogTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: `projects/` 디렉터리 목록, `projects.<id>.project` 모듈, `Core.CORE_API_VERSION`
- Produces: `ProjectCatalog.new(options?)`; `listProjects(): Project[]`; `getProject(projectId): Project|nil,error`; `createGame(project): app|nil,error`

- [ ] **Step 1: 네 개 실패 테스트를 작성한다**

`tests/ProjectCatalogTest.lua`에서 주입한 `listDirectory`와 `loadModule`을 사용해 다음을 검증한다.

```lua
local function manifest(id, coreApiVersion)
    return {
        id = id,
        title = id .. " title",
        coreApiVersion = coreApiVersion or 1,
        entryModule = "games." .. id,
    }
end

return {
    {
        name = "Project 목록은 유효한 매니페스트만 제목 순으로 반환한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local modules = {
                ["projects.zeta.project"] = manifest("zeta"),
                ["projects.alpha.project"] = manifest("alpha"),
                ["projects.bad.project"] = { id = "bad" },
            }
            local catalog = ProjectCatalog.new({
                listDirectory = function() return { "zeta", "bad", "alpha" } end,
                loadModule = function(name) return modules[name] end,
                coreApiVersion = 1,
            })
            local projects = catalog:listProjects()
            test.assertEqual(#projects, 2)
            test.assertEqual(projects[1].id, "alpha")
            test.assertEqual(projects[2].id, "zeta")
        end,
    },
    {
        name = "Core API가 맞지 않는 Project는 열지 않는다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return { "future" } end,
                loadModule = function() return manifest("future", 2) end,
                coreApiVersion = 1,
            })
            local project, errorMessage = catalog:getProject("future")
            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Core API")
        end,
    },
    {
        name = "존재하지 않는 Project 오류를 문자열로 반환한다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function() error("missing") end,
                coreApiVersion = 1,
            })
            local project, errorMessage = catalog:getProject("missing")
            test.assertEqual(project, nil)
            test.assertContains(errorMessage, "Failed to load project")
        end,
    },
    {
        name = "Project 게임 생성자 예외를 안전한 오류로 바꾼다",
        run = function(test)
            local ProjectCatalog = require("editor.project.ProjectCatalog")
            local catalog = ProjectCatalog.new({
                listDirectory = function() return {} end,
                loadModule = function(name)
                    if name == "games.throwing" then
                        return { new = function() error("boom") end }
                    end
                    return manifest("throwing")
                end,
                coreApiVersion = 1,
            })
            local game, errorMessage = catalog:createGame(manifest("throwing"))
            test.assertEqual(game, nil)
            test.assertContains(errorMessage, "Failed to create game")
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.ProjectCatalogTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.project.ProjectCatalog' not found`가 포함된 실패.

- [ ] **Step 3: ProjectCatalog를 구현한다**

`editor/project/ProjectCatalog.lua`:

```lua
local Core = require("core")

local ProjectCatalog = {}
ProjectCatalog.__index = ProjectCatalog

local function defaultListDirectory()
    return love.filesystem.getDirectoryItems("projects")
end

local function defaultLoadModule(moduleName)
    return require(moduleName)
end

local function validateProject(project, expectedCoreApiVersion)
    if type(project) ~= "table" then
        return "Project manifest must be a table."
    end
    for _, fieldName in ipairs({ "id", "title", "entryModule" }) do
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

function ProjectCatalog.new(options)
    options = options or {}
    return setmetatable({
        listDirectory = options.listDirectory or defaultListDirectory,
        loadModule = options.loadModule or defaultLoadModule,
        coreApiVersion = options.coreApiVersion or Core.CORE_API_VERSION,
    }, ProjectCatalog)
end

function ProjectCatalog:getProject(projectId)
    local moduleName = "projects." .. projectId .. ".project"
    local succeeded, projectOrError = pcall(self.loadModule, moduleName)
    if not succeeded then
        return nil, "Failed to load project: " .. projectId .. "\n" .. tostring(projectOrError)
    end
    local validationError = validateProject(projectOrError, self.coreApiVersion)
    if validationError then
        return nil, validationError
    end
    if projectOrError.id ~= projectId then
        return nil, "Project id does not match directory: " .. projectId
    end
    return projectOrError, nil
end

function ProjectCatalog:listProjects()
    local projects = {}
    local succeeded, entriesOrError = pcall(self.listDirectory)
    if not succeeded then
        return projects, tostring(entriesOrError)
    end
    for _, projectId in ipairs(entriesOrError) do
        local project = self:getProject(projectId)
        if project then
            table.insert(projects, project)
        end
    end
    table.sort(projects, function(left, right)
        return left.title < right.title
    end)
    return projects, nil
end

function ProjectCatalog:createGame(project)
    local loaded, moduleOrError = pcall(self.loadModule, project.entryModule)
    if not loaded then
        return nil, "Failed to load game entry module: " .. tostring(moduleOrError)
    end
    if type(moduleOrError) ~= "table" or type(moduleOrError.new) ~= "function" then
        return nil, "Game entry module must provide new(project)."
    end
    local created, gameOrError = pcall(moduleOrError.new, project)
    if not created then
        return nil, "Failed to create game: " .. tostring(gameOrError)
    end
    if type(gameOrError) ~= "table" then
        return nil, "Game constructor must return a table."
    end
    return gameOrError, nil
end

return ProjectCatalog
```

- [ ] **Step 4: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 33 tests`.

- [ ] **Step 5: 커밋한다**

```powershell
git add editor/project/ProjectCatalog.lua tests/ProjectCatalogTest.lua tests/TestRunner.lua
git commit -m "feat: add editor project catalog"
```

---

### Task 4: dkjson과 StageStore 파일 경계

**Files:**
- Create: `vendor/dkjson.lua`
- Create: `vendor/dkjson.LICENSE.txt`
- Create: `editor/stage/NativeFileSystem.lua`
- Create: `editor/stage/StageStore.lua`
- Create: `tests/StageStoreTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: 검증된 Project/Stage ID, Stage version 1 table, Project 상대 경로용 파일 시스템 어댑터
- Produces: `StageStore.new(fileSystem?, json?)`; `listStages(projectId)`; `stageExists(projectId,stageId)`; `load(projectId,stageId)`; `save(data,overwrite)`; 오류 코드 `STAGE_EXISTS`

- [ ] **Step 1: dkjson 2.10 원본과 라이선스를 고정한다**

공식 URL `https://dkolf.de/dkjson-lua/dkjson-2.10.lua`를 임시 위치에 내려받아 첫 부분의 `json.version = "dkjson 2.10"`과 저작권 문구를 확인한다. 확인한 원본을 `vendor/dkjson.lua`로 추가한다. `vendor/dkjson.LICENSE.txt`에는 배포본의 다음 라이선스 본문을 그대로 기록한다.

```text
Copyright (C) 2010-2026 David Heiko Kolf

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

Verification:

```powershell
Select-String -Path vendor/dkjson.lua -Pattern 'dkjson 2.10'
Get-FileHash vendor/dkjson.lua -Algorithm SHA256
```

Expected: 버전 문자열이 한 번 이상 출력되고 SHA-256 값이 64자리 16진수로 출력된다. 해당 해시는 이후 `docs/HANDOFF.md`에 기록한다.

- [ ] **Step 2: 아홉 개 StageStore 실패 테스트를 작성한다**

`tests/StageStoreTest.lua`의 공통 fixture:

```lua
local function validStage(stageId)
    return {
        schemaVersion = 1,
        projectId = "sample",
        stageId = stageId or "tutorial",
        name = "Tutorial",
        tempoMap = { { startBeat = 0, bpm = 120 } },
        events = {},
    }
end

local function newFakeFileSystem()
    local fileSystem = {
        files = {},
        directoryItems = {},
        writeError = nil,
    }

    function fileSystem:list(relativePath)
        return self.directoryItems[relativePath] or {}, nil
    end

    function fileSystem:read(relativePath)
        local contents = self.files[relativePath]
        if contents == nil then
            return nil, "file not found: " .. relativePath
        end
        return contents, nil
    end

    function fileSystem:exists(relativePath)
        return self.files[relativePath] ~= nil
    end

    function fileSystem:writeAtomic(relativePath, contents)
        if self.writeError then
            return nil, self.writeError
        end
        self.files[relativePath] = contents
        return true, nil
    end

    return fileSystem
end
```

같은 파일의 반환 배열에 다음 아홉 case를 넣는다.

```lua
return {
    {
        name = "고정된 dkjson 버전을 사용한다",
        run = function(test)
            local json = require("vendor.dkjson")
            test.assertEqual(json.version, "dkjson 2.10")
        end,
    },
    {
        name = "Stage 목록은 JSON 확장자만 ID 순으로 반환한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.directoryItems["projects/sample/stages"] = {
                "zeta.json", "notes.txt", "alpha.json",
            }
            local store = StageStore.new(fileSystem)
            local stages = assert(store:listStages("sample"))
            test.assertEqual(#stages, 2)
            test.assertEqual(stages[1], "alpha")
            test.assertEqual(stages[2], "zeta")
        end,
    },
    {
        name = "StageStore는 경로 탈출 식별자를 거부한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local store = StageStore.new(newFakeFileSystem())
            local stages, errorMessage = store:listStages("../outside")
            test.assertEqual(stages, nil)
            test.assertContains(errorMessage, "projectId")
        end,
    },
    {
        name = "Stage JSON을 읽고 검증된 table을 반환한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/tutorial.json"] = json.encode(validStage())
            local store = StageStore.new(fileSystem, json)
            local data = assert(store:load("sample", "tutorial"))
            test.assertEqual(data.stageId, "tutorial")
            test.assertEqual(data.tempoMap[1].bpm, 120)
        end,
    },
    {
        name = "잘못된 JSON은 decode 오류를 반환한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.files["projects/sample/stages/broken.json"] = "{"
            local store = StageStore.new(fileSystem)
            local data, errorMessage = store:load("sample", "broken")
            test.assertEqual(data, nil)
            test.assertContains(errorMessage, "Invalid JSON")
        end,
    },
    {
        name = "선택 Project와 JSON projectId가 다르면 거부한다",
        run = function(test)
            local json = require("vendor.dkjson")
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local data = validStage("wrong")
            data.projectId = "other"
            fileSystem.files["projects/sample/stages/wrong.json"] = json.encode(data)
            local store = StageStore.new(fileSystem, json)
            local loaded, errorMessage = store:load("sample", "wrong")
            test.assertEqual(loaded, nil)
            test.assertContains(errorMessage, "$.projectId")
        end,
    },
    {
        name = "Stage 저장은 ID 기반 경로와 들여쓰기 JSON을 사용한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local store = StageStore.new(fileSystem)
            assert(store:save(validStage("saved"), false))
            local contents = fileSystem.files["projects/sample/stages/saved.json"]
            test.assertTrue(contents ~= nil)
            test.assertContains(contents, "\n")
            test.assertContains(contents, '"schemaVersion"')
        end,
    },
    {
        name = "overwrite가 false면 기존 Stage를 바꾸지 않는다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            local path = "projects/sample/stages/tutorial.json"
            fileSystem.files[path] = "original"
            local store = StageStore.new(fileSystem)
            local saved, errorMessage, errorCode = store:save(validStage(), false)
            test.assertEqual(saved, nil)
            test.assertEqual(errorCode, StageStore.ERROR_STAGE_EXISTS)
            test.assertEqual(fileSystem.files[path], "original")
            test.assertContains(errorMessage, "already exists")
        end,
    },
    {
        name = "원자 쓰기 실패를 호출자에게 전달한다",
        run = function(test)
            local StageStore = require("editor.stage.StageStore")
            local fileSystem = newFakeFileSystem()
            fileSystem.writeError = "disk full"
            local store = StageStore.new(fileSystem)
            local saved, errorMessage = store:save(validStage(), true)
            test.assertEqual(saved, nil)
            test.assertContains(errorMessage, "disk full")
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.StageStoreTest`를 등록한다.

- [ ] **Step 3: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.stage.StageStore' not found`가 포함된 실패.

- [ ] **Step 4: NativeFileSystem을 구현한다**

`editor/stage/NativeFileSystem.lua`:

```lua
local NativeFileSystem = {}
NativeFileSystem.__index = NativeFileSystem

local function normalizeRoot(rootPath)
    return rootPath:gsub("[\\/]+$", "")
end

local function join(rootPath, relativePath)
    return normalizeRoot(rootPath) .. "/" .. relativePath
end

local function nativeFileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

function NativeFileSystem.new(sourceRoot)
    return setmetatable({
        sourceRoot = sourceRoot or love.filesystem.getSource(),
    }, NativeFileSystem)
end

function NativeFileSystem:list(relativePath)
    local succeeded, itemsOrError = pcall(love.filesystem.getDirectoryItems, relativePath)
    if not succeeded then
        return nil, tostring(itemsOrError)
    end
    return itemsOrError, nil
end

function NativeFileSystem:read(relativePath)
    local contents, sizeOrError = love.filesystem.read(relativePath)
    if not contents then
        return nil, tostring(sizeOrError)
    end
    return contents, nil
end

function NativeFileSystem:exists(relativePath)
    return love.filesystem.getInfo(relativePath, "file") ~= nil
end

function NativeFileSystem:writeAtomic(relativePath, contents)
    if self.sourceRoot:lower():match("%.love$") then
        return nil, "Editor cannot write Stage files inside a packaged .love source."
    end

    local targetPath = join(self.sourceRoot, relativePath)
    local temporaryPath = targetPath .. ".tmp"
    local backupPath = targetPath .. ".bak"
    local file, openError = io.open(temporaryPath, "wb")
    if not file then
        return nil, "Failed to open temporary Stage file: " .. tostring(openError)
    end
    local wrote, writeError = file:write(contents)
    local closed, closeError = file:close()
    if not wrote or not closed then
        os.remove(temporaryPath)
        return nil, "Failed to write temporary Stage file: " .. tostring(writeError or closeError)
    end

    local hadTarget = nativeFileExists(targetPath)
    if hadTarget then
        os.remove(backupPath)
        local backedUp, backupError = os.rename(targetPath, backupPath)
        if not backedUp then
            os.remove(temporaryPath)
            return nil, "Failed to back up Stage file: " .. tostring(backupError)
        end
    end

    local replaced, replaceError = os.rename(temporaryPath, targetPath)
    if not replaced then
        if hadTarget then
            os.rename(backupPath, targetPath)
        end
        os.remove(temporaryPath)
        return nil, "Failed to replace Stage file: " .. tostring(replaceError)
    end
    if hadTarget then
        os.remove(backupPath)
    end
    return true, nil
end

return NativeFileSystem
```

- [ ] **Step 5: StageStore를 구현한다**

`editor/stage/StageStore.lua`:

```lua
local jsonDefault = require("vendor.dkjson")
local NativeFileSystem = require("editor.stage.NativeFileSystem")
local StageDocument = require("editor.stage.StageDocument")

local StageStore = {}
StageStore.__index = StageStore
StageStore.ERROR_STAGE_EXISTS = "STAGE_EXISTS"

local JSON_KEY_ORDER = {
    "schemaVersion", "projectId", "stageId", "name",
    "tempoMap", "events", "startBeat", "bpm", "id",
    "type", "patternId", "params", "durationBeats",
}

local function validateId(value, fieldName)
    if not StageDocument.isSafeId(value) then
        return nil, "$.'" .. fieldName .. "' must be a safe identifier."
    end
    return true, nil
end

local function stageDirectory(projectId)
    return "projects/" .. projectId .. "/stages"
end

local function stagePath(projectId, stageId)
    return stageDirectory(projectId) .. "/" .. stageId .. ".json"
end

function StageStore.new(fileSystem, json)
    return setmetatable({
        fileSystem = fileSystem or NativeFileSystem.new(),
        json = json or jsonDefault,
    }, StageStore)
end

function StageStore:listStages(projectId)
    local valid, validationError = validateId(projectId, "projectId")
    if not valid then
        return nil, validationError
    end
    local items, listError = self.fileSystem:list(stageDirectory(projectId))
    if not items then
        return nil, "Failed to list Stage files: " .. tostring(listError)
    end
    local stageIds = {}
    for _, fileName in ipairs(items) do
        local stageId = fileName:match("^([a-z0-9][a-z0-9_-]*)%.json$")
        if stageId then
            table.insert(stageIds, stageId)
        end
    end
    table.sort(stageIds)
    return stageIds, nil
end

function StageStore:stageExists(projectId, stageId)
    local validProject, projectError = validateId(projectId, "projectId")
    if not validProject then return nil, projectError end
    local validStage, stageError = validateId(stageId, "stageId")
    if not validStage then return nil, stageError end
    return self.fileSystem:exists(stagePath(projectId, stageId)), nil
end

function StageStore:load(projectId, stageId)
    local exists, existsError = self:stageExists(projectId, stageId)
    if exists == nil then return nil, existsError end
    if not exists then return nil, "Stage file does not exist: " .. stageId end
    local contents, readError = self.fileSystem:read(stagePath(projectId, stageId))
    if not contents then return nil, "Failed to read Stage: " .. tostring(readError) end
    local data, position, decodeError = self.json.decode(contents, 1, nil)
    if decodeError then return nil, "Invalid JSON: " .. decodeError end
    if contents:sub(position):match("^%s*$") == nil then
        return nil, "Invalid JSON: trailing content."
    end
    local validationError = StageDocument.validate(data)
    if validationError then return nil, validationError end
    if data.projectId ~= projectId then
        return nil, "$.projectId must match selected Project."
    end
    if data.stageId ~= stageId then
        return nil, "$.stageId must match the file name."
    end
    return data, nil
end

function StageStore:save(data, overwrite)
    local validationError = StageDocument.validate(data)
    if validationError then return nil, validationError end
    local path = stagePath(data.projectId, data.stageId)
    if self.fileSystem:exists(path) and not overwrite then
        return nil, "Stage already exists: " .. data.stageId, StageStore.ERROR_STAGE_EXISTS
    end
    local encoded, encodeError
    local succeeded, valueOrError = pcall(self.json.encode, data, {
        indent = true,
        keyorder = JSON_KEY_ORDER,
    })
    if succeeded then encoded = valueOrError else encodeError = valueOrError end
    if not encoded then return nil, "Failed to encode Stage: " .. tostring(encodeError) end
    local written, writeError = self.fileSystem:writeAtomic(path, encoded .. "\n")
    if not written then return nil, "Failed to save Stage: " .. tostring(writeError) end
    return true, nil
end

return StageStore
```

- [ ] **Step 6: GREEN과 JSON 형식을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 42 tests`.

Run: `Get-Content -Raw projects/sample/stages/tutorial.json | ConvertFrom-Json | Out-Null`

Expected: exit code `0`, 출력 없음.

- [ ] **Step 7: 커밋한다**

```powershell
git add vendor/dkjson.lua vendor/dkjson.LICENSE.txt editor/stage/NativeFileSystem.lua editor/stage/StageStore.lua tests/StageStoreTest.lua tests/TestRunner.lua
git commit -m "feat: add project scoped stage storage"
```

---

### Task 5: Project TestPlayer Canvas와 draw 크기 계약

**Files:**
- Modify: `editor/playback/TestPlayer.lua`
- Modify: `projects/sample/game/SampleGame.lua`
- Modify: `launcher/Launcher.lua`
- Create: `tests/TestPlayerTest.lua`
- Modify: `tests/SampleGameTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: `createGame(project): app|nil,error`, Project `update(deltaTime)`, Project `draw(width,height)`, preview rect `{x,y,width,height}`
- Produces: `TestPlayer.new(options?)`; `start(project)`; `stop()`; `isPlaying()`; `update(deltaTime)`; `draw(rect)`

- [ ] **Step 1: 다섯 개 실패 테스트를 작성한다**

`tests/TestPlayerTest.lua`는 fake game과 fake graphics를 사용해 다음을 검증한다.

```lua
local function newGraphics()
    local graphics = { draws = 0 }
    function graphics.newCanvas(width, height) return { width = width, height = height } end
    function graphics.push() end
    function graphics.pop() end
    function graphics.setCanvas() end
    function graphics.clear() end
    function graphics.draw() graphics.draws = graphics.draws + 1 end
    return graphics
end

return {
    {
        name = "TestPlayer는 Project 게임을 생성해 시작한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local game = {}
            local player = TestPlayer.new({
                createGame = function() return game, nil end,
                graphics = newGraphics(),
            })
            test.assertEqual(player:isPlaying(), false)
            assert(player:start({ id = "sample" }))
            test.assertEqual(player:isPlaying(), true)
        end,
    },
    {
        name = "TestPlayer update는 Project 게임에 deltaTime을 전달한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local received = 0
            local player = TestPlayer.new({
                createGame = function()
                    return { update = function(_, deltaTime) received = deltaTime end }, nil
                end,
                graphics = newGraphics(),
            })
            assert(player:start({ id = "sample" }))
            assert(player:update(0.25))
            test.assertEqual(received, 0.25)
        end,
    },
    {
        name = "TestPlayer는 게임 생성 오류를 반환하고 비활성 상태를 유지한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local player = TestPlayer.new({
                createGame = function() return nil, "preview failed" end,
                graphics = newGraphics(),
            })
            local started, errorMessage = player:start({ id = "sample" })
            test.assertEqual(started, nil)
            test.assertEqual(player:isPlaying(), false)
            test.assertContains(errorMessage, "preview failed")
        end,
    },
    {
        name = "TestPlayer는 update 예외를 오류로 반환한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local player = TestPlayer.new({
                createGame = function()
                    return { update = function() error("update exploded") end }, nil
                end,
                graphics = newGraphics(),
            })
            assert(player:start({ id = "sample" }))
            local updated, errorMessage = player:update(0.1)
            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "update exploded")
        end,
    },
    {
        name = "TestPlayer는 Canvas 크기를 draw에 전달하고 stop으로 해제한다",
        run = function(test)
            local TestPlayer = require("editor.playback.TestPlayer")
            local receivedWidth, receivedHeight
            local graphics = newGraphics()
            local player = TestPlayer.new({
                createGame = function()
                    return {
                        draw = function(_, width, height)
                            receivedWidth, receivedHeight = width, height
                        end,
                    }, nil
                end,
                graphics = graphics,
            })
            assert(player:start({ id = "sample" }))
            assert(player:draw({ x = 10, y = 20, width = 400, height = 240 }))
            test.assertEqual(receivedWidth, 400)
            test.assertEqual(receivedHeight, 240)
            test.assertEqual(graphics.draws, 1)
            player:stop()
            test.assertEqual(player:isPlaying(), false)
        end,
    },
}
```

`tests/SampleGameTest.lua`의 첫 번째 생성 테스트에서 기존 단언 뒤에 다음 코드를 추가해 `draw(width,height)` 계약도 같은 case에서 검증한다.

```lua
local previousLove = love
love = {
    graphics = {
        clear = function() end,
        setColor = function() end,
        printf = function() end,
    },
}
local drawn, drawError = pcall(function()
    game:draw(320, 180)
end)
love = previousLove
test.assertTrue(drawn, drawError)
```

`tests/TestRunner.lua`에 `tests.TestPlayerTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `TestPlayer.start`가 없거나 인자를 받지 않는다는 실패.

- [ ] **Step 3: TestPlayer를 Canvas 호스트로 교체한다**

`editor/playback/TestPlayer.lua`의 핵심 구현은 다음과 같다.

```lua
local TestPlayer = {}
TestPlayer.__index = TestPlayer

local function defaultGraphics()
    return love.graphics
end

function TestPlayer.new(options)
    options = options or {}
    return setmetatable({
        createGame = options.createGame,
        graphics = options.graphics or defaultGraphics(),
        game = nil,
        canvas = nil,
        canvasWidth = nil,
        canvasHeight = nil,
        playing = false,
    }, TestPlayer)
end

function TestPlayer:start(project)
    if type(self.createGame) ~= "function" then
        return nil, "TestPlayer requires createGame(project)."
    end
    local game, errorMessage = self.createGame(project)
    if not game then
        self:stop()
        return nil, errorMessage
    end
    self.game = game
    self.playing = true
    return true, nil
end

function TestPlayer:stop()
    self.game = nil
    self.canvas = nil
    self.canvasWidth = nil
    self.canvasHeight = nil
    self.playing = false
end

function TestPlayer:isPlaying()
    return self.playing
end

function TestPlayer:update(deltaTime)
    if not self.playing or not self.game or not self.game.update then
        return true, nil
    end
    local succeeded, errorMessage = pcall(self.game.update, self.game, deltaTime)
    if not succeeded then
        return nil, "Project preview update failed: " .. tostring(errorMessage)
    end
    return true, nil
end

function TestPlayer:draw(rect)
    if not self.playing or not self.game then
        return true, nil
    end
    if self.canvasWidth ~= rect.width or self.canvasHeight ~= rect.height then
        self.canvas = self.graphics.newCanvas(rect.width, rect.height)
        self.canvasWidth = rect.width
        self.canvasHeight = rect.height
    end
    self.graphics.push("all")
    self.graphics.setCanvas(self.canvas)
    self.graphics.clear(0, 0, 0, 1)
    local succeeded, errorMessage = pcall(function()
        if self.game.draw then
            self.game:draw(rect.width, rect.height)
        end
    end)
    self.graphics.pop()
    if not succeeded then
        return nil, "Project preview draw failed: " .. tostring(errorMessage)
    end
    self.graphics.draw(self.canvas, rect.x, rect.y)
    return true, nil
end

return TestPlayer
```

- [ ] **Step 4: Project와 Launcher draw 계약을 갱신한다**

`projects/sample/game/SampleGame.lua`:

```lua
function SampleGame:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()

    love.graphics.clear(0.06, 0.08, 0.12, 1)
    love.graphics.setColor(0.55, 0.9, 1, 1)
    love.graphics.printf(self.project.title, 0, height * 0.4, width, "center")
    love.graphics.setColor(0.75, 0.78, 0.84, 1)
    love.graphics.printf("Standalone game project", 0, height * 0.4 + 36, width, "center")
    love.graphics.printf("Esc: Back to launcher", 0, height - 56, width, "center")
end
```

`launcher/Launcher.lua`의 active app draw 호출을 다음처럼 바꾼다.

```lua
local width, height = love.graphics.getDimensions()
self.activeApp:draw(width, height)
```

- [ ] **Step 5: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 47 tests`.

- [ ] **Step 6: 커밋한다**

```powershell
git add editor/playback/TestPlayer.lua projects/sample/game/SampleGame.lua launcher/Launcher.lua tests/TestPlayerTest.lua tests/SampleGameTest.lua tests/TestRunner.lua
git commit -m "feat: render project previews in test player"
```

---

### Task 6: EditorSession Stage·저장·재생 상태

**Files:**
- Create: `editor/EditorSession.lua`
- Create: `tests/EditorSessionTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: `ProjectCatalog`, `StageStore`, `TestPlayer`, `clockFactory`
- Produces: Stage 조회, Project/Stage 목록, `createStage`, `openStage`, `save`, `saveAs`, `setBpm`, `play`, `pause`, `update`, `drawPreview`, `handlePreviewError`, timeline view 조회

- [ ] **Step 1: 열 개 실패 테스트를 작성한다**

`tests/EditorSessionTest.lua`는 fake ProjectCatalog, StageStore와 TestPlayer를 만들고 다음 case를 각각 검증한다.

```lua
local function newFixture(options)
    options = options or {}
    local stored = options.stored
    local project = { id = "sample", title = "Sample", entryModule = "sample.game" }
    local catalog = {
        listProjects = function() return { project }, nil end,
        getProject = function(_, projectId)
            if projectId == "sample" then return project, nil end
            return nil, "missing project"
        end,
        createGame = function() return {}, nil end,
    }
    local store = {
        listStages = function() return { "tutorial" }, nil end,
        stageExists = function(_, _, stageId) return stageId == "existing", nil end,
        load = function()
            if options.loadError then return nil, options.loadError end
            return stored, nil
        end,
        save = function(_, data, overwrite)
            if options.saveError then return nil, options.saveError end
            if options.conflict and not overwrite then
                return nil, "already exists", "STAGE_EXISTS"
            end
            options.lastSaved = data
            return true, nil
        end,
    }
    local testPlayer = {
        playing = false,
        start = function(self)
            if options.previewError then return nil, options.previewError end
            self.playing = true
            return true, nil
        end,
        stop = function(self) self.playing = false end,
        update = function()
            if options.updateError then return nil, options.updateError end
            return true, nil
        end,
        draw = function() return true, nil end,
    }
    return catalog, store, testPlayer, options
end
```

fixture 아래에 실제 세션을 만드는 helper와 열 case를 그대로 추가한다.

```lua
local VALID_STAGE = {
    schemaVersion = 1,
    projectId = "sample",
    stageId = "tutorial",
    name = "Tutorial",
    tempoMap = { { startBeat = 0, bpm = 120 } },
    events = {},
}

local function newSession(options)
    local EditorSession = require("editor.EditorSession")
    local catalog, store, testPlayer, state = newFixture(options)
    return EditorSession.new({
        projectCatalog = catalog,
        stageStore = store,
        testPlayer = testPlayer,
    }), testPlayer, state
end

return {
    {
        name = "에디터 세션은 Stage 없이 시작한다",
        run = function(test)
            local session = newSession()
            test.assertEqual(session:hasStage(), false)
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(session:isPlaying(), false)
        end,
    },
    {
        name = "새 Stage 생성은 현재 Project와 dirty Stage를 설정한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "new-stage", "New Stage", 128))
            test.assertEqual(session:getProject().id, "sample")
            test.assertEqual(session:getDocument():getStageId(), "new-stage")
            test.assertEqual(session:getBpm(), 128)
            test.assertEqual(#session:getDocument():toTable().events, 0)
            test.assertEqual(session:isDirty(), true)
        end,
    },
    {
        name = "기존 Stage Open은 clean 상태와 0 beat로 교체한다",
        run = function(test)
            local session = newSession({ stored = VALID_STAGE })
            assert(session:openStage("sample", "tutorial"))
            test.assertEqual(session:getDocument():getStageId(), "tutorial")
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(session:getBeat(), 0)
        end,
    },
    {
        name = "Open 실패는 현재 Stage와 dirty 상태를 보존한다",
        run = function(test)
            local session = newSession({ loadError = "broken Stage" })
            assert(session:createStage("sample", "current", "Current", 120))
            local opened, errorMessage = session:openStage("sample", "broken")
            test.assertEqual(opened, nil)
            test.assertContains(errorMessage, "broken Stage")
            test.assertEqual(session:getDocument():getStageId(), "current")
            test.assertEqual(session:isDirty(), true)
        end,
    },
    {
        name = "Save 성공은 dirty를 해제하고 실패는 유지한다",
        run = function(test)
            local session, _, state = newSession()
            assert(session:createStage("sample", "saved", "Saved", 120))
            assert(session:save())
            test.assertEqual(session:isDirty(), false)
            test.assertEqual(state.lastSaved.stageId, "saved")

            local failingSession = newSession({ saveError = "disk failed" })
            assert(failingSession:createStage("sample", "failed", "Failed", 120))
            local saved, errorMessage = failingSession:save()
            test.assertEqual(saved, nil)
            test.assertContains(errorMessage, "disk failed")
            test.assertEqual(failingSession:isDirty(), true)
        end,
    },
    {
        name = "Save As 충돌은 원본 ID를 보존한다",
        run = function(test)
            local session = newSession({ conflict = true })
            assert(session:createStage("sample", "source", "Source", 120))
            local saved, _, errorCode = session:saveAs("copy", "Copy", false)
            test.assertEqual(saved, nil)
            test.assertEqual(errorCode, "STAGE_EXISTS")
            test.assertEqual(session:getDocument():getStageId(), "source")
        end,
    },
    {
        name = "BPM 변경은 Document와 Clock을 함께 변경한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "tempo", "Tempo", 120))
            assert(session:setBpm(90))
            test.assertEqual(session:getBpm(), 90)
            session:play()
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 1.5, 0.000001)
        end,
    },
    {
        name = "Play와 Pause는 beat를 보존하고 TestPlayer를 전환한다",
        run = function(test)
            local session, testPlayer = newSession()
            assert(session:createStage("sample", "preview", "Preview", 120))
            assert(session:play())
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 2, 0.000001)
            test.assertEqual(testPlayer.playing, true)
            session:pause()
            assert(session:update(1, 16))
            test.assertNear(session:getBeat(), 2, 0.000001)
            test.assertEqual(testPlayer.playing, false)
        end,
    },
    {
        name = "Project preview update 실패는 재생을 중지한다",
        run = function(test)
            local session = newSession({ updateError = "preview update failed" })
            assert(session:createStage("sample", "error", "Error", 120))
            assert(session:play())
            local updated, errorMessage = session:update(0.1, 16)
            test.assertEqual(updated, nil)
            test.assertContains(errorMessage, "preview update failed")
            test.assertEqual(session:isPlaying(), false)
        end,
    },
    {
        name = "타임라인은 플레이헤드를 4박자 단위로 자동 추적한다",
        run = function(test)
            local session = newSession()
            assert(session:createStage("sample", "follow", "Follow", 120))
            assert(session:play())
            assert(session:update(7, 12))
            test.assertNear(session:getBeat(), 14, 0.000001)
            test.assertEqual(session:getTimelineStartBeat(), 4)
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.EditorSessionTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.EditorSession' not found`가 포함된 실패.

- [ ] **Step 3: EditorSession의 생성과 조회를 구현한다**

`editor/EditorSession.lua`의 생성부와 조회 API:

```lua
local Core = require("core")
local StageDocument = require("editor.stage.StageDocument")

local EditorSession = {}
EditorSession.__index = EditorSession

function EditorSession.new(options)
    assert(options and options.projectCatalog, "projectCatalog is required")
    assert(options.stageStore, "stageStore is required")
    assert(options.testPlayer, "testPlayer is required")
    return setmetatable({
        projectCatalog = options.projectCatalog,
        stageStore = options.stageStore,
        testPlayer = options.testPlayer,
        clockFactory = options.clockFactory or Core.PlaybackClock.new,
        project = nil,
        document = nil,
        clock = nil,
        timelineStartBeat = 0,
    }, EditorSession)
end

function EditorSession:hasStage() return self.document ~= nil end
function EditorSession:isDirty() return self.document ~= nil and self.document:isDirty() end
function EditorSession:isPlaying() return self.clock ~= nil and self.clock:isPlaying() end
function EditorSession:getProject() return self.project end
function EditorSession:getDocument() return self.document end
function EditorSession:getBpm() return self.document and self.document:getBpm() or nil end
function EditorSession:getBeat() return self.clock and self.clock:getBeat() or 0 end
function EditorSession:getTimelineStartBeat() return self.timelineStartBeat end
function EditorSession:listProjects() return self.projectCatalog:listProjects() end
function EditorSession:listStages(projectId) return self.stageStore:listStages(projectId) end
```

- [ ] **Step 4: Stage와 저장 명령을 구현한다**

같은 파일에 다음 동작을 추가한다.

```lua
function EditorSession:replaceStage(project, document)
    local clock, clockError = self.clockFactory(document:getBpm())
    if not clock then return nil, clockError end
    self.testPlayer:stop()
    self.project = project
    self.document = document
    self.clock = clock
    self.timelineStartBeat = 0
    return true, nil
end

function EditorSession:createStage(projectId, stageId, name, bpm)
    local project, projectError = self.projectCatalog:getProject(projectId)
    if not project then return nil, projectError end
    local exists, existsError = self.stageStore:stageExists(projectId, stageId)
    if exists == nil then return nil, existsError end
    if exists then return nil, "Stage already exists: " .. stageId end
    local document, documentError = StageDocument.create(projectId, stageId, name, bpm)
    if not document then return nil, documentError end
    return self:replaceStage(project, document)
end

function EditorSession:openStage(projectId, stageId)
    local project, projectError = self.projectCatalog:getProject(projectId)
    if not project then return nil, projectError end
    local data, loadError = self.stageStore:load(projectId, stageId)
    if not data then return nil, loadError end
    local document, documentError = StageDocument.fromTable(data)
    if not document then return nil, documentError end
    return self:replaceStage(project, document)
end

function EditorSession:save()
    if not self.document then return nil, "No Stage is open." end
    local saved, errorMessage, errorCode = self.stageStore:save(self.document:toTable(), true)
    if not saved then return nil, errorMessage, errorCode end
    self.document:markClean()
    return true, nil
end

function EditorSession:saveAs(stageId, name, overwrite)
    if not self.document then return nil, "No Stage is open." end
    local copy, copyError = self.document:cloneAs(stageId, name)
    if not copy then return nil, copyError end
    local saved, errorMessage, errorCode = self.stageStore:save(copy:toTable(), overwrite == true)
    if not saved then return nil, errorMessage, errorCode end
    copy:markClean()
    self.document = copy
    return true, nil
end

function EditorSession:setBpm(bpm)
    if not self.document then return nil, "No Stage is open." end
    local changed, errorMessage = self.document:setBpm(bpm)
    if not changed then return nil, errorMessage end
    return self.clock:setBpm(bpm)
end
```

- [ ] **Step 5: 재생과 자동 추적을 구현한다**

```lua
function EditorSession:play()
    if not self.document then return nil, "No Stage is open." end
    local started, errorMessage = self.testPlayer:start(self.project)
    if not started then return nil, errorMessage end
    self.clock:play()
    return true, nil
end

function EditorSession:pause()
    if self.clock then self.clock:pause() end
    self.testPlayer:stop()
end

function EditorSession:update(deltaTime, visibleBeatCount)
    if not self:isPlaying() then return true, nil end
    self.clock:update(deltaTime)
    local updated, errorMessage = self.testPlayer:update(deltaTime)
    if not updated then
        self:pause()
        return nil, errorMessage
    end
    if visibleBeatCount and self:getBeat() >= self.timelineStartBeat + visibleBeatCount then
        local requiredStart = self:getBeat() - visibleBeatCount + 4
        self.timelineStartBeat = math.max(0, math.floor(requiredStart / 4) * 4)
    end
    return true, nil
end

function EditorSession:drawPreview(rect)
    local drawn, errorMessage = self.testPlayer:draw(rect)
    if not drawn then
        self:pause()
        return nil, errorMessage
    end
    return true, nil
end

function EditorSession:handlePreviewError()
    self:pause()
end

return EditorSession
```

- [ ] **Step 6: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 57 tests`.

- [ ] **Step 7: 커밋한다**

```powershell
git add editor/EditorSession.lua tests/EditorSessionTest.lua tests/TestRunner.lua
git commit -m "feat: add editor stage session"
```

---

### Task 7: Menu와 EditorLayout 표시·hit test

**Files:**
- Create: `editor/menu/EditorMenu.lua`
- Create: `tests/EditorUiTest.lua`
- Modify: `editor/ui/EditorLayout.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: EditorSession 조회 API, 마우스 좌표, 창 크기
- Produces: `EditorMenu.getItems(session)`; `getRows(panel,items)`; `hitTest(panel,items,x,y)`; `draw(...)`; `EditorLayout.getPreviewRect`; `getBpmValueRect`; `getVisibleBeatCount`; `draw(width,height,viewModel,drawPreview)`

- [ ] **Step 1: 여섯 개 UI 실패 테스트를 작성한다**

`tests/EditorUiTest.lua`:

```lua
local function sessionState(values)
    values = values or {}
    return {
        hasStage = function() return values.hasStage == true end,
        isDirty = function() return values.dirty == true end,
        isPlaying = function() return values.playing == true end,
    }
end

return {
    {
        name = "Menu는 요청한 일곱 항목만 순서대로 제공한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            local labels = { "New", "Open", "Save", "Save As", "Play", "Pause", "Quit" }
            test.assertEqual(#items, #labels)
            for index, label in ipairs(labels) do
                test.assertEqual(items[index].label, label)
            end
        end,
    },
    {
        name = "Stage가 없으면 저장과 재생 항목이 비활성화된다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            test.assertEqual(items[3].enabled, false)
            test.assertEqual(items[4].enabled, false)
            test.assertEqual(items[5].enabled, false)
            test.assertEqual(items[6].enabled, false)
        end,
    },
    {
        name = "dirty Stage는 Save 별표를 표시한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState({ hasStage = true, dirty = true }))
            test.assertEqual(items[3].label, "Save*")
        end,
    },
    {
        name = "Play와 Pause 활성 상태는 재생 여부에 따라 교대한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local stopped = EditorMenu.getItems(sessionState({ hasStage = true }))
            local playing = EditorMenu.getItems(sessionState({ hasStage = true, playing = true }))
            test.assertEqual(stopped[5].enabled, true)
            test.assertEqual(stopped[6].enabled, false)
            test.assertEqual(playing[5].enabled, false)
            test.assertEqual(playing[6].enabled, true)
        end,
    },
    {
        name = "Menu hit test는 클릭한 활성 항목을 반환한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local panel = { x = 0, y = 0, width = 180, height = 360 }
            local items = EditorMenu.getItems(sessionState())
            local item = EditorMenu.hitTest(panel, items, 20, 44)
            test.assertEqual(item.action, "new")
        end,
    },
    {
        name = "Properties와 Values 합친 영역과 BPM Value 영역을 계산한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)
            local preview = EditorLayout.getPreviewRect(layout)
            local bpm = EditorLayout.getBpmValueRect(layout)
            test.assertEqual(preview.x, layout.panels[4].x)
            test.assertEqual(preview.width, layout.panels[4].width + layout.panels[5].width)
            test.assertEqual(bpm.x, layout.panels[5].x)
            test.assertEqual(bpm.y, 32)
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.EditorUiTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.menu.EditorMenu' not found`가 포함된 실패.

- [ ] **Step 3: EditorMenu를 구현한다**

`editor/menu/EditorMenu.lua`:

```lua
local EditorMenu = {}

local HEADER_HEIGHT = 32
local ROW_HEIGHT = 24
local ROW_PADDING = 4

local DEFINITIONS = {
    { action = "new", label = "New" },
    { action = "open", label = "Open" },
    { action = "save", label = "Save" },
    { action = "saveAs", label = "Save As" },
    { action = "play", label = "Play" },
    { action = "pause", label = "Pause" },
    { action = "quit", label = "Quit" },
}

function EditorMenu.getItems(session)
    local hasStage = session:hasStage()
    local playing = session:isPlaying()
    local items = {}
    for _, definition in ipairs(DEFINITIONS) do
        local enabled = true
        if definition.action == "save" or definition.action == "saveAs" then
            enabled = hasStage
        elseif definition.action == "play" then
            enabled = hasStage and not playing
        elseif definition.action == "pause" then
            enabled = hasStage and playing
        end
        local label = definition.label
        if definition.action == "save" and session:isDirty() then
            label = "Save*"
        end
        table.insert(items, {
            action = definition.action,
            label = label,
            enabled = enabled,
        })
    end
    return items
end

function EditorMenu.getRows(panel, items)
    local rows = {}
    for index, item in ipairs(items) do
        rows[index] = {
            x = panel.x + ROW_PADDING,
            y = panel.y + HEADER_HEIGHT + (index - 1) * ROW_HEIGHT,
            width = panel.width - ROW_PADDING * 2,
            height = ROW_HEIGHT,
            item = item,
        }
    end
    return rows
end

function EditorMenu.hitTest(panel, items, x, y)
    for _, row in ipairs(EditorMenu.getRows(panel, items)) do
        if x >= row.x and x < row.x + row.width
            and y >= row.y and y < row.y + row.height then
            return row.item
        end
    end
    return nil
end

function EditorMenu.draw(panel, items, hoveredAction)
    for _, row in ipairs(EditorMenu.getRows(panel, items)) do
        if row.item.action == hoveredAction and row.item.enabled then
            love.graphics.setColor(0.25, 0.27, 0.3, 1)
            love.graphics.rectangle("fill", row.x, row.y, row.width, row.height)
        end
        if row.item.enabled then
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
        else
            love.graphics.setColor(0.48, 0.49, 0.52, 1)
        end
        love.graphics.print(row.item.label, row.x + 4, row.y + 3)
    end
end

return EditorMenu
```

- [ ] **Step 4: EditorLayout의 순수 계산 API를 추가한다**

`editor/ui/EditorLayout.lua`의 기존 패널 계산은 유지하고 다음 상수와 함수를 추가한다.

```lua
local HEADER_HEIGHT = 32
local PROPERTY_ROW_HEIGHT = 24

function EditorLayout.getPreviewRect(layout)
    local properties = layout.panels[4]
    local values = layout.panels[5]
    return {
        x = properties.x,
        y = properties.y,
        width = properties.width + values.width,
        height = properties.height,
    }
end

function EditorLayout.getBpmValueRect(layout)
    local values = layout.panels[5]
    return {
        x = values.x,
        y = values.y + HEADER_HEIGHT,
        width = values.width,
        height = PROPERTY_ROW_HEIGHT,
    }
end

function EditorLayout.getVisibleBeatCount(layout)
    return math.max(1, math.floor(layout.timeline.width / TIMELINE_STEP_WIDTH))
end

function EditorLayout.hitTestBpmValue(layout, x, y)
    local rect = EditorLayout.getBpmValueRect(layout)
    return x >= rect.x and x < rect.x + rect.width
        and y >= rect.y and y < rect.y + rect.height
end
```

- [ ] **Step 5: EditorLayout 그리기를 view model 방식으로 바꾼다**

`EditorLayout.draw`의 새 계약은 `draw(width, height, viewModel, drawPreview)`다. 다음 표시 규칙을 그대로 코드화한다.

```lua
local EditorMenu = require("editor.menu.EditorMenu")

local function drawPanelContent(layout, viewModel)
    if not viewModel.hasStage then return end
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print("> Global", layout.panels[2].x + 12, HEADER_HEIGHT + 3)
    love.graphics.print("> Mixtape Properties", layout.panels[3].x + 12, HEADER_HEIGHT + 3)
    if not viewModel.playing then
        love.graphics.print("BPM", layout.panels[4].x + 12, HEADER_HEIGHT + 3)
        love.graphics.print(tostring(viewModel.bpm), layout.panels[5].x + 12, HEADER_HEIGHT + 3)
    end
end

local function drawTimeline(timeline, viewModel)
    love.graphics.setColor(0.18, 0.19, 0.21, 1)
    love.graphics.rectangle("fill", timeline.x, timeline.y, timeline.width, timeline.height)
    local visibleSteps = math.ceil(timeline.width / TIMELINE_STEP_WIDTH)
    for step = 0, visibleSteps do
        local beat = viewModel.timelineStartBeat + step
        local x = timeline.x + step * TIMELINE_STEP_WIDTH
        love.graphics.setColor(step % 2 == 0 and 0.23 or 0.2, step % 2 == 0 and 0.24 or 0.21, step % 2 == 0 and 0.26 or 0.23, 1)
        love.graphics.rectangle("fill", x, timeline.y + 32, TIMELINE_STEP_WIDTH, timeline.height - 32)
        if beat % 4 == 0 then
            love.graphics.setColor(0.82, 0.83, 0.86, 1)
            love.graphics.print(tostring(beat), x + 4, timeline.y + 8)
        end
    end
    if viewModel.hasStage then
        local playheadX = timeline.x + (viewModel.beat - viewModel.timelineStartBeat) * TIMELINE_STEP_WIDTH
        love.graphics.setColor(1, 0.45, 0.2, 1)
        love.graphics.rectangle("fill", playheadX, timeline.y, 2, timeline.height)
    end
end

function EditorLayout.draw(width, height, viewModel, drawPreview)
    local layout = EditorLayout.getLayout(width, height)
    love.graphics.push("all")
    love.graphics.clear(0.08, 0.08, 0.09, 1)
    for index, panel in ipairs(layout.panels) do
        if not (viewModel.playing and (index == 4 or index == 5)) then
            drawPanel(panel)
        end
    end
    EditorMenu.draw(layout.panels[1], viewModel.menuItems, viewModel.hoveredAction)
    drawPanelContent(layout, viewModel)
    if viewModel.playing then
        drawPreview(EditorLayout.getPreviewRect(layout))
    end
    drawTimeline(layout.timeline, viewModel)
    love.graphics.pop()
    return layout
end
```

기존 `drawTimeline(timeline)` 구현은 위 계약으로 교체하고 `drawPanel`과 패널 비율 상수는 유지한다.

- [ ] **Step 6: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 63 tests`.

- [ ] **Step 7: 커밋한다**

```powershell
git add editor/menu/EditorMenu.lua editor/ui/EditorLayout.lua tests/EditorUiTest.lua tests/TestRunner.lua
git commit -m "feat: draw interactive editor menu"
```

---

### Task 8: EditorDialog 입력·선택·결과 모델

**Files:**
- Create: `editor/ui/EditorDialog.lua`
- Create: `tests/EditorDialogTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: factory별 Project/Stage option, 텍스트와 마우스·키 입력
- Produces: `newStage`, `openStage`, `saveAs`, `editBpm`, `unsaved`, `overwrite`, `error`; `getKind`; `getValue`; `getSelection`; `setSelectorOptions`; `getLayout`; `textinput`; `keypressed`; `mousepressed`; `consumeResult`; `draw`

- [ ] **Step 1: 여섯 개 실패 테스트를 작성한다**

`tests/EditorDialogTest.lua`:

```lua
local PROJECTS = {
    { id = "alpha", title = "Alpha" },
    { id = "sample", title = "Sample" },
}

return {
    {
        name = "New Stage 모달은 Project와 세 입력값을 가진다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.newStage(PROJECTS)
            test.assertEqual(dialog:getKind(), "newStage")
            test.assertEqual(dialog:getSelection("projectId"), "alpha")
            test.assertEqual(dialog:getValue("bpm"), "120")
        end,
    },
    {
        name = "활성 입력 필드는 textinput과 Backspace를 처리한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.editBpm(120)
            dialog:textinput("5")
            test.assertEqual(dialog:getValue("bpm"), "1205")
            dialog:keypressed("backspace")
            test.assertEqual(dialog:getValue("bpm"), "120")
        end,
    },
    {
        name = "Tab은 다음 텍스트 입력 필드로 이동한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.newStage(PROJECTS)
            test.assertEqual(dialog:getFocusedFieldId(), "stageId")
            dialog:keypressed("tab")
            test.assertEqual(dialog:getFocusedFieldId(), "name")
        end,
    },
    {
        name = "Open Stage selector option을 교체하고 선택할 수 있다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.openStage(PROJECTS, { "one" })
            dialog:setSelectorOptions("stageId", {
                { value = "one", label = "one" },
                { value = "two", label = "two" },
            })
            local layout = dialog:getLayout(1000, 700)
            local secondStageOption
            for _, rect in ipairs(layout.selectorOptions) do
                if rect.selectorId == "stageId" and rect.optionIndex == 2 then
                    secondStageOption = rect
                end
            end
            assert(secondStageOption)
            dialog:mousepressed(
                secondStageOption.x + secondStageOption.width / 2,
                secondStageOption.y + secondStageOption.height / 2
            )
            test.assertEqual(dialog:getSelection("stageId"), "two")
        end,
    },
    {
        name = "Enter는 기본 버튼 결과를 만들고 Escape는 cancel 결과를 만든다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local enterDialog = EditorDialog.editBpm(120)
            enterDialog:keypressed("return")
            test.assertEqual(enterDialog:consumeResult().buttonId, "confirm")
            local escapeDialog = EditorDialog.editBpm(120)
            escapeDialog:keypressed("escape")
            test.assertEqual(escapeDialog:consumeResult().buttonId, "cancel")
        end,
    },
    {
        name = "Unsaved 모달은 Save Discard Cancel 결과를 구분한다",
        run = function(test)
            local EditorDialog = require("editor.ui.EditorDialog")
            local dialog = EditorDialog.unsaved("quit")
            dialog:submit("discard")
            local result = dialog:consumeResult()
            test.assertEqual(result.buttonId, "discard")
            test.assertEqual(result.context.pendingAction, "quit")
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.EditorDialogTest`를 등록한다.

- [ ] **Step 2: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `module 'editor.ui.EditorDialog' not found`가 포함된 실패.

- [ ] **Step 3: 모달 factory와 상태를 구현한다**

`editor/ui/EditorDialog.lua`의 데이터 생성부:

```lua
local utf8 = require("utf8")

local EditorDialog = {}
EditorDialog.__index = EditorDialog

local function projectOptions(projects)
    local options = {}
    for _, project in ipairs(projects) do
        table.insert(options, { value = project.id, label = project.title })
    end
    return options
end

local function stringOptions(values)
    local options = {}
    for _, value in ipairs(values) do
        table.insert(options, { value = value, label = value })
    end
    return options
end

local function newDialog(config)
    config.fields = config.fields or {}
    config.selectors = config.selectors or {}
    config.buttons = config.buttons or {}
    config.focusedFieldIndex = #config.fields > 0 and 1 or nil
    config.result = nil
    return setmetatable(config, EditorDialog)
end

function EditorDialog.newStage(projects)
    return newDialog({
        kind = "newStage", title = "New Stage",
        selectors = { { id = "projectId", label = "Project", options = projectOptions(projects), selectedIndex = 1 } },
        fields = {
            { id = "stageId", label = "Stage ID", value = "" },
            { id = "name", label = "Name", value = "" },
            { id = "bpm", label = "BPM", value = "120" },
        },
        buttons = { { id = "confirm", label = "Create", default = true }, { id = "cancel", label = "Cancel", cancel = true } },
    })
end

function EditorDialog.openStage(projects, stageIds)
    return newDialog({
        kind = "openStage", title = "Open Stage",
        selectors = {
            { id = "projectId", label = "Project", options = projectOptions(projects), selectedIndex = 1 },
            { id = "stageId", label = "Stage", options = stringOptions(stageIds), selectedIndex = 1 },
        },
        buttons = { { id = "confirm", label = "Open", default = true }, { id = "cancel", label = "Cancel", cancel = true } },
    })
end

function EditorDialog.saveAs(stageId, name)
    return newDialog({
        kind = "saveAs", title = "Save As",
        fields = {
            { id = "stageId", label = "Stage ID", value = stageId },
            { id = "name", label = "Name", value = name },
        },
        buttons = { { id = "confirm", label = "Save", default = true }, { id = "cancel", label = "Cancel", cancel = true } },
    })
end

function EditorDialog.editBpm(bpm)
    return newDialog({
        kind = "editBpm", title = "Edit BPM",
        fields = { { id = "bpm", label = "BPM", value = tostring(bpm) } },
        buttons = { { id = "confirm", label = "Apply", default = true }, { id = "cancel", label = "Cancel", cancel = true } },
    })
end

function EditorDialog.unsaved(pendingAction)
    return newDialog({
        kind = "unsaved", title = "Unsaved Changes",
        message = "Save changes before continuing?",
        context = { pendingAction = pendingAction },
        buttons = {
            { id = "save", label = "Save", default = true },
            { id = "discard", label = "Discard" },
            { id = "cancel", label = "Cancel", cancel = true },
        },
    })
end

function EditorDialog.overwrite(payload)
    return newDialog({
        kind = "overwrite", title = "Confirm Overwrite",
        message = "Stage already exists. Overwrite it?",
        context = payload,
        buttons = { { id = "confirm", label = "Overwrite", default = true }, { id = "cancel", label = "Cancel", cancel = true } },
    })
end

function EditorDialog.error(message)
    return newDialog({
        kind = "error", title = "Error", message = tostring(message),
        buttons = { { id = "ok", label = "OK", default = true, cancel = true } },
    })
end
```

- [ ] **Step 4: 값·키·결과 API를 구현한다**

같은 파일에 다음 메서드를 추가한다.

```lua
function EditorDialog:getKind() return self.kind end

function EditorDialog:getFocusedFieldId()
    local field = self.focusedFieldIndex and self.fields[self.focusedFieldIndex]
    return field and field.id or nil
end

function EditorDialog:getValue(fieldId)
    for _, field in ipairs(self.fields) do
        if field.id == fieldId then return field.value end
    end
    return nil
end

function EditorDialog:getSelection(selectorId)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then
            local option = selector.options[selector.selectedIndex]
            return option and option.value or nil
        end
    end
    return nil
end

function EditorDialog:setSelectorOptions(selectorId, options)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then
            selector.options = options
            selector.selectedIndex = #options > 0 and 1 or 0
            return true
        end
    end
    return false
end

function EditorDialog:textinput(text)
    local field = self.focusedFieldIndex and self.fields[self.focusedFieldIndex]
    if field then field.value = field.value .. text end
end

function EditorDialog:submit(buttonId)
    local values = {}
    local selections = {}
    for _, field in ipairs(self.fields) do values[field.id] = field.value end
    for _, selector in ipairs(self.selectors) do selections[selector.id] = self:getSelection(selector.id) end
    self.result = { buttonId = buttonId, values = values, selections = selections, context = self.context or {} }
end

function EditorDialog:keypressed(key)
    if key == "backspace" and self.focusedFieldIndex then
        local field = self.fields[self.focusedFieldIndex]
        local offset = utf8.offset(field.value, -1)
        if offset then field.value = field.value:sub(1, offset - 1) end
        return true
    elseif key == "tab" and #self.fields > 0 then
        self.focusedFieldIndex = self.focusedFieldIndex % #self.fields + 1
        return true
    elseif key == "return" or key == "kpenter" then
        for _, button in ipairs(self.buttons) do
            if button.default then self:submit(button.id); return true end
        end
    elseif key == "escape" then
        for _, button in ipairs(self.buttons) do
            if button.cancel then self:submit(button.id); return true end
        end
    end
    return false
end

function EditorDialog:consumeResult()
    local result = self.result
    self.result = nil
    return result
end
```

- [ ] **Step 5: 마우스 layout과 draw를 구현한다**

같은 파일에 고정 크기 모달의 layout, hit test와 draw를 추가한다. `getLayout`은 GUI 하네스도 클릭 좌표를 재사용할 수 있는 공개 API다.

```lua
local MODAL_WIDTH = 560
local MODAL_HEIGHT = 420
local PADDING = 24
local LABEL_WIDTH = 120
local ROW_HEIGHT = 32
local OPTION_HEIGHT = 28
local ROW_GAP = 8

local function contains(rect, x, y)
    return x >= rect.x and x < rect.x + rect.width
        and y >= rect.y and y < rect.y + rect.height
end

function EditorDialog:getLayout(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    local modal = {
        x = math.floor((width - MODAL_WIDTH) / 2),
        y = math.floor((height - MODAL_HEIGHT) / 2),
        width = MODAL_WIDTH,
        height = MODAL_HEIGHT,
    }
    local contentX = modal.x + PADDING
    local contentWidth = modal.width - PADDING * 2
    local cursorY = modal.y + 58
    local layout = {
        modal = modal,
        selectorLabels = {},
        selectorOptions = {},
        fields = {},
        buttons = {},
    }

    if self.message then
        cursorY = cursorY + 44
    end

    for selectorIndex, selector in ipairs(self.selectors) do
        table.insert(layout.selectorLabels, {
            x = contentX,
            y = cursorY,
            label = selector.label,
        })
        cursorY = cursorY + 20
        for optionIndex, option in ipairs(selector.options) do
            table.insert(layout.selectorOptions, {
                x = contentX + LABEL_WIDTH,
                y = cursorY,
                width = contentWidth - LABEL_WIDTH,
                height = OPTION_HEIGHT,
                selectorIndex = selectorIndex,
                selectorId = selector.id,
                optionIndex = optionIndex,
                label = option.label,
                selected = selector.selectedIndex == optionIndex,
            })
            cursorY = cursorY + OPTION_HEIGHT + 4
        end
    end

    for fieldIndex, field in ipairs(self.fields) do
        table.insert(layout.fields, {
            x = contentX + LABEL_WIDTH,
            y = cursorY,
            width = contentWidth - LABEL_WIDTH,
            height = ROW_HEIGHT,
            labelX = contentX,
            fieldIndex = fieldIndex,
            fieldId = field.id,
            label = field.label,
            value = field.value,
            focused = self.focusedFieldIndex == fieldIndex,
        })
        cursorY = cursorY + ROW_HEIGHT + ROW_GAP
    end

    local buttonGap = 8
    local buttonWidth = math.floor(
        (contentWidth - buttonGap * math.max(0, #self.buttons - 1)) / math.max(1, #self.buttons)
    )
    local buttonY = modal.y + modal.height - PADDING - ROW_HEIGHT
    for buttonIndex, button in ipairs(self.buttons) do
        table.insert(layout.buttons, {
            x = contentX + (buttonIndex - 1) * (buttonWidth + buttonGap),
            y = buttonY,
            width = buttonWidth,
            height = ROW_HEIGHT,
            buttonId = button.id,
            label = button.label,
        })
    end

    self.lastLayout = layout
    return layout
end

function EditorDialog:mousepressed(x, y)
    local layout = self.lastLayout or self:getLayout()
    for _, rect in ipairs(layout.fields) do
        if contains(rect, x, y) then
            self.focusedFieldIndex = rect.fieldIndex
            return true
        end
    end
    for _, rect in ipairs(layout.selectorOptions) do
        if contains(rect, x, y) then
            self.selectors[rect.selectorIndex].selectedIndex = rect.optionIndex
            return true
        end
    end
    for _, rect in ipairs(layout.buttons) do
        if contains(rect, x, y) then
            self:submit(rect.buttonId)
            return true
        end
    end
    return true
end

function EditorDialog:draw(width, height)
    local graphics = love.graphics
    local layout = self:getLayout(width, height)
    graphics.push("all")
    graphics.setColor(0, 0, 0, 0.65)
    graphics.rectangle("fill", 0, 0, width, height)
    graphics.setColor(0.13, 0.14, 0.16, 1)
    graphics.rectangle("fill", layout.modal.x, layout.modal.y, layout.modal.width, layout.modal.height)
    graphics.setColor(0.85, 0.86, 0.89, 1)
    graphics.rectangle("line", layout.modal.x, layout.modal.y, layout.modal.width, layout.modal.height)
    graphics.print(self.title, layout.modal.x + PADDING, layout.modal.y + 20)
    if self.message then
        graphics.printf(
            self.message,
            layout.modal.x + PADDING,
            layout.modal.y + 54,
            layout.modal.width - PADDING * 2,
            "left"
        )
    end

    for _, label in ipairs(layout.selectorLabels) do
        graphics.setColor(0.75, 0.77, 0.81, 1)
        graphics.print(label.label, label.x, label.y)
    end
    for _, rect in ipairs(layout.selectorOptions) do
        graphics.setColor(rect.selected and 0.27 or 0.19, rect.selected and 0.38 or 0.2, 0.24, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.92, 0.93, 0.96, 1)
        graphics.print(rect.label, rect.x + 8, rect.y + 6)
    end
    for _, rect in ipairs(layout.fields) do
        graphics.setColor(0.75, 0.77, 0.81, 1)
        graphics.print(rect.label, rect.labelX, rect.y + 7)
        graphics.setColor(0.09, 0.1, 0.12, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(rect.focused and 1 or 0.45, rect.focused and 0.55 or 0.47, 0.22, 1)
        graphics.rectangle("line", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.94, 0.94, 0.96, 1)
        graphics.print(rect.value, rect.x + 8, rect.y + 7)
    end
    for _, rect in ipairs(layout.buttons) do
        graphics.setColor(0.24, 0.25, 0.29, 1)
        graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
        graphics.setColor(0.92, 0.93, 0.96, 1)
        graphics.printf(rect.label, rect.x, rect.y + 7, rect.width, "center")
    end
    graphics.pop()
end
```

`mousepressed`는 바깥 클릭도 `true`로 소비해 뒤쪽 Editor UI 입력을 차단한다. 옵션이 많아 고정 높이를 넘는 selector 스크롤은 이 Menu 단계의 범위 밖이며 후속 에디터 탐색 기능에서 다룬다.

- [ ] **Step 6: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 69 tests`.

- [ ] **Step 7: 커밋한다**

```powershell
git add editor/ui/EditorDialog.lua tests/EditorDialogTest.lua tests/TestRunner.lua
git commit -m "feat: add editor workflow dialogs"
```

---

### Task 9: EditorApp 메뉴·모달 통합과 Launcher Quit

**Files:**
- Modify: `editor/EditorApp.lua`
- Modify: `editor/init.lua`
- Modify: `editor/ui/EditorDialog.lua`
- Modify: `launcher/Launcher.lua`
- Modify: `main.lua`
- Create: `tests/EditorWorkflowTest.lua`
- Modify: `tests/EditorTest.lua`
- Modify: `tests/LauncherTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: 이전 Task의 모든 Editor 서비스와 LÖVE mouse/text/key callbacks
- Produces: `EditorApp.new(options?)`; `executeAction(action)`; `getDialog()`; `getSession()`; `update`; `draw`; `mousemoved`; `mousepressed`; `textinput`; `keypressed`; Editor `onQuit` 콜백

- [ ] **Step 1: EditorDialog에 테스트와 통합용 값 설정 API를 추가한다**

`editor/ui/EditorDialog.lua`:

```lua
function EditorDialog:setValue(fieldId, value)
    for _, field in ipairs(self.fields) do
        if field.id == fieldId then
            field.value = tostring(value)
            return true
        end
    end
    return false
end

function EditorDialog:select(selectorId, value)
    for _, selector in ipairs(self.selectors) do
        if selector.id == selectorId then
            for index, option in ipairs(selector.options) do
                if option.value == value then
                    selector.selectedIndex = index
                    return true
                end
            end
        end
    end
    return false
end
```

- [ ] **Step 2: 여덟 개 Editor workflow 실패 테스트를 작성한다**

`tests/EditorWorkflowTest.lua`는 실제 `StageDocument`, `PlaybackClock`, `EditorSession`, `EditorDialog`를 사용하고 ProjectCatalog, StageStore, TestPlayer만 fake로 주입한다. 공통 fixture는 다음 값을 노출한다.

```lua
local function newFixture(config)
    config = config or {}
    local state = { saved = {}, quitCount = 0, previewPlaying = false }
    local project = { id = "sample", title = "Sample", entryModule = "sample.game" }
    local catalog = {
        listProjects = function() return { project }, nil end,
        getProject = function(_, projectId)
            if projectId == "sample" then return project, nil end
            return nil, "missing project"
        end,
        createGame = function() return {}, nil end,
    }
    local store = {
        listStages = function() return { "tutorial" }, nil end,
        stageExists = function(_, _, stageId) return state.saved[stageId] ~= nil, nil end,
        load = function(_, _, stageId)
            local data = state.saved[stageId]
            if not data then return nil, "missing Stage" end
            return data, nil
        end,
        save = function(_, data, overwrite)
            if config.saveError then return nil, config.saveError end
            if state.saved[data.stageId] and not overwrite then
                return nil, "already exists", "STAGE_EXISTS"
            end
            state.saved[data.stageId] = data
            return true, nil
        end,
    }
    local testPlayer = {
        start = function()
            if config.previewError then return nil, config.previewError end
            state.previewPlaying = true
            return true, nil
        end,
        stop = function() state.previewPlaying = false end,
        update = function()
            if config.previewUpdateError then return nil, config.previewUpdateError end
            return true, nil
        end,
        draw = function() return true, nil end,
    }
    local EditorApp = require("editor.EditorApp")
    local app = EditorApp.new({
        projectCatalog = catalog,
        stageStore = store,
        testPlayer = testPlayer,
        onQuit = function() state.quitCount = state.quitCount + 1 end,
    })
    return app, state
end

local function createStageThroughDialog(app, stageId)
    app:executeAction("new")
    local dialog = app:getDialog()
    assert(dialog:select("projectId", "sample"))
    assert(dialog:setValue("stageId", stageId))
    assert(dialog:setValue("name", "Stage " .. stageId))
    assert(dialog:setValue("bpm", "120"))
    dialog:submit("confirm")
    app:update(0)
end
```

반환 배열의 여덟 case는 다음과 같이 구현한다.

```lua
return {
    {
        name = "New dialog 결과는 dirty Stage를 생성한다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "new-stage")
            test.assertEqual(app:getSession():getDocument():getStageId(), "new-stage")
            test.assertEqual(app:getSession():isDirty(), true)
        end,
    },
    {
        name = "Save 메뉴는 Stage를 저장하고 Save 별표를 해제한다",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "saved-stage")
            app:executeAction("save")
            test.assertTrue(state.saved["saved-stage"] ~= nil)
            test.assertEqual(app:getSession():isDirty(), false)
        end,
    },
    {
        name = "dirty New 요청은 Save Discard Cancel 분기를 처리한다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "current")
            app:executeAction("new")
            test.assertEqual(app:getDialog():getKind(), "unsaved")
            app:getDialog():submit("cancel")
            app:update(0)
            test.assertEqual(app:getSession():getDocument():getStageId(), "current")
            test.assertEqual(app:getDialog(), nil)

            local discardApp = newFixture()
            createStageThroughDialog(discardApp, "discard-current")
            discardApp:executeAction("new")
            discardApp:getDialog():submit("discard")
            discardApp:update(0)
            test.assertEqual(discardApp:getDialog():getKind(), "newStage")

            local saveApp, saveState = newFixture()
            createStageThroughDialog(saveApp, "save-current")
            saveApp:executeAction("new")
            saveApp:getDialog():submit("save")
            saveApp:update(0)
            test.assertTrue(saveState.saved["save-current"] ~= nil)
            test.assertEqual(saveApp:getDialog():getKind(), "newStage")
        end,
    },
    {
        name = "dirty Open 요청은 Save Discard Cancel 분기를 처리한다",
        run = function(test)
            local app = newFixture()
            createStageThroughDialog(app, "current")
            app:executeAction("open")
            app:getDialog():submit("discard")
            app:update(0)
            test.assertEqual(app:getDialog():getKind(), "openStage")

            local cancelApp = newFixture()
            createStageThroughDialog(cancelApp, "cancel-open")
            cancelApp:executeAction("open")
            cancelApp:getDialog():submit("cancel")
            cancelApp:update(0)
            test.assertEqual(cancelApp:getDialog(), nil)
            test.assertEqual(cancelApp:getSession():getDocument():getStageId(), "cancel-open")

            local saveApp, saveState = newFixture()
            createStageThroughDialog(saveApp, "save-open")
            saveApp:executeAction("open")
            saveApp:getDialog():submit("save")
            saveApp:update(0)
            test.assertTrue(saveState.saved["save-open"] ~= nil)
            test.assertEqual(saveApp:getDialog():getKind(), "openStage")
        end,
    },
    {
        name = "Save As 충돌은 Overwrite 확인 후 새 ID로 저장한다",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "source")
            state.saved.copy = { occupied = true }
            app:executeAction("saveAs")
            assert(app:getDialog():setValue("stageId", "copy"))
            assert(app:getDialog():setValue("name", "Copy"))
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertEqual(app:getDialog():getKind(), "overwrite")
            app:getDialog():submit("confirm")
            app:update(0)
            test.assertEqual(app:getSession():getDocument():getStageId(), "copy")
        end,
    },
    {
        name = "Play과 Pause는 TestPlayer 화면 상태를 전환한다",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "preview")
            app:executeAction("play")
            test.assertEqual(app:getViewModel().playing, true)
            test.assertEqual(state.previewPlaying, true)
            app:executeAction("pause")
            test.assertEqual(app:getViewModel().playing, false)
            test.assertEqual(state.previewPlaying, false)
        end,
    },
    {
        name = "Preview update 오류는 Error dialog와 편집 상태로 복귀한다",
        run = function(test)
            local app = newFixture({ previewUpdateError = "preview exploded" })
            createStageThroughDialog(app, "preview-error")
            app:executeAction("play")
            app:update(0.1)
            test.assertEqual(app:getSession():isPlaying(), false)
            test.assertEqual(app:getDialog():getKind(), "error")
        end,
    },
    {
        name = "dirty Quit은 Save Discard Cancel과 저장 실패를 처리한다",
        run = function(test)
            local app, state = newFixture()
            createStageThroughDialog(app, "quit-stage")
            app:executeAction("quit")
            app:getDialog():submit("save")
            app:update(0)
            test.assertTrue(state.saved["quit-stage"] ~= nil)
            test.assertEqual(state.quitCount, 1)

            local cancelApp, cancelState = newFixture()
            createStageThroughDialog(cancelApp, "cancel-quit")
            cancelApp:executeAction("quit")
            cancelApp:getDialog():submit("cancel")
            cancelApp:update(0)
            test.assertEqual(cancelState.quitCount, 0)
            test.assertEqual(cancelApp:getDialog(), nil)

            local discardApp, discardState = newFixture()
            createStageThroughDialog(discardApp, "discard-quit")
            discardApp:executeAction("quit")
            discardApp:getDialog():submit("discard")
            discardApp:update(0)
            test.assertEqual(discardState.quitCount, 1)

            local failingApp, failingState = newFixture({ saveError = "save failed" })
            createStageThroughDialog(failingApp, "failed-quit")
            failingApp:executeAction("quit")
            failingApp:getDialog():submit("save")
            failingApp:update(0)
            test.assertEqual(failingState.quitCount, 0)
            test.assertEqual(failingApp:getDialog():getKind(), "error")
            test.assertEqual(failingApp:getSession():isDirty(), true)
        end,
    },
}
```

`tests/TestRunner.lua`에 `tests.EditorWorkflowTest`를 등록한다.

- [ ] **Step 3: RED를 확인한다**

Run: `love . --test`

Expected: exit code `1`, `EditorApp.new`가 options를 처리하지 못하거나 `executeAction`이 없다는 실패.

- [ ] **Step 4: EditorApp의 의존성 조립과 view model을 구현한다**

`editor/EditorApp.lua`의 생성부:

```lua
local EditorSession = require("editor.EditorSession")
local EditorDialog = require("editor.ui.EditorDialog")
local EditorLayout = require("editor.ui.EditorLayout")
local EditorMenu = require("editor.menu.EditorMenu")
local ProjectCatalog = require("editor.project.ProjectCatalog")
local StageStore = require("editor.stage.StageStore")
local TestPlayer = require("editor.playback.TestPlayer")

local EditorApp = {}
EditorApp.__index = EditorApp

function EditorApp.new(options)
    options = options or {}
    local projectCatalog = options.projectCatalog or ProjectCatalog.new()
    local stageStore = options.stageStore or StageStore.new()
    local testPlayer = options.testPlayer or TestPlayer.new({
        createGame = function(project)
            return projectCatalog:createGame(project)
        end,
    })
    local session = options.session or EditorSession.new({
        projectCatalog = projectCatalog,
        stageStore = stageStore,
        testPlayer = testPlayer,
    })
    return setmetatable({
        session = session,
        onQuit = options.onQuit or function() end,
        dialog = nil,
        hoveredAction = nil,
        layout = EditorLayout.getLayout(1200, 800),
    }, EditorApp)
end

function EditorApp:getSession() return self.session end
function EditorApp:getDialog() return self.dialog end

function EditorApp:getViewModel()
    return {
        hasStage = self.session:hasStage(),
        playing = self.session:isPlaying(),
        dirty = self.session:isDirty(),
        bpm = self.session:getBpm(),
        beat = self.session:getBeat(),
        timelineStartBeat = self.session:getTimelineStartBeat(),
        menuItems = EditorMenu.getItems(self.session),
        hoveredAction = self.hoveredAction,
    }
end

function EditorApp:showError(message)
    self.dialog = EditorDialog.error(message)
end
```

- [ ] **Step 5: Menu 명령과 dirty guard를 구현한다**

같은 파일에 다음 workflow를 추가한다.

```lua
function EditorApp:openNewDialog()
    local projects, errorMessage = self.session:listProjects()
    if not projects or #projects == 0 then
        self:showError(errorMessage or "No compatible Projects found.")
        return
    end
    self.dialog = EditorDialog.newStage(projects)
end

function EditorApp:openOpenDialog()
    local projects, errorMessage = self.session:listProjects()
    if not projects or #projects == 0 then
        self:showError(errorMessage or "No compatible Projects found.")
        return
    end
    local stageIds, stageError = self.session:listStages(projects[1].id)
    if not stageIds then self:showError(stageError); return end
    self.dialog = EditorDialog.openStage(projects, stageIds)
end

function EditorApp:continueAction(action)
    if action == "new" then
        self:openNewDialog()
    elseif action == "open" then
        self:openOpenDialog()
    elseif action == "quit" then
        self.session:pause()
        self.onQuit()
    end
end

function EditorApp:requestGuarded(action)
    if self.session:isDirty() then
        self.dialog = EditorDialog.unsaved(action)
    else
        self:continueAction(action)
    end
end

function EditorApp:executeAction(action)
    if action == "new" or action == "open" or action == "quit" then
        self:requestGuarded(action)
    elseif action == "save" then
        local saved, errorMessage = self.session:save()
        if not saved then self:showError(errorMessage) end
    elseif action == "saveAs" then
        local document = self.session:getDocument()
        self.dialog = EditorDialog.saveAs(document:getStageId(), document:getName())
    elseif action == "play" then
        local started, errorMessage = self.session:play()
        if not started then self:showError(errorMessage) end
    elseif action == "pause" then
        self.session:pause()
    end
end
```

- [ ] **Step 6: Dialog 결과 state machine을 구현한다**

`EditorApp:processDialogResult()`는 `self.dialog:consumeResult()`를 읽고 다음 코드를 실행한다.

```lua
function EditorApp:processDialogResult()
    if not self.dialog then return end
    local result = self.dialog:consumeResult()
    if not result then return end
    local kind = self.dialog:getKind()
    if result.buttonId == "cancel" or result.buttonId == "ok" then
        self.dialog = nil
        return
    end

    if kind == "newStage" and result.buttonId == "confirm" then
        local created, errorMessage = self.session:createStage(
            result.selections.projectId,
            result.values.stageId,
            result.values.name,
            tonumber(result.values.bpm)
        )
        self.dialog = nil
        if not created then self:showError(errorMessage) end
    elseif kind == "openStage" and result.buttonId == "confirm" then
        local opened, errorMessage = self.session:openStage(
            result.selections.projectId,
            result.selections.stageId
        )
        self.dialog = nil
        if not opened then self:showError(errorMessage) end
    elseif kind == "saveAs" and result.buttonId == "confirm" then
        local saved, errorMessage, errorCode = self.session:saveAs(
            result.values.stageId,
            result.values.name,
            false
        )
        self.dialog = nil
        if not saved and errorCode == "STAGE_EXISTS" then
            self.dialog = EditorDialog.overwrite({
                stageId = result.values.stageId,
                name = result.values.name,
            })
        elseif not saved then
            self:showError(errorMessage)
        end
    elseif kind == "overwrite" and result.buttonId == "confirm" then
        local saved, errorMessage = self.session:saveAs(
            result.context.stageId,
            result.context.name,
            true
        )
        self.dialog = nil
        if not saved then self:showError(errorMessage) end
    elseif kind == "editBpm" and result.buttonId == "confirm" then
        local changed, errorMessage = self.session:setBpm(tonumber(result.values.bpm))
        self.dialog = nil
        if not changed then self:showError(errorMessage) end
    elseif kind == "unsaved" then
        local pendingAction = result.context.pendingAction
        if result.buttonId == "discard" then
            self.dialog = nil
            self:continueAction(pendingAction)
        elseif result.buttonId == "save" then
            local saved, errorMessage = self.session:save()
            self.dialog = nil
            if saved then self:continueAction(pendingAction) else self:showError(errorMessage) end
        end
    elseif kind == "error" then
        self.dialog = nil
    end
end
```

- [ ] **Step 7: LÖVE update/draw/input을 통합한다**

`EditorApp`에 다음 메서드를 추가한다.

```lua
function EditorApp:update(deltaTime)
    self:processDialogResult()
    if self.dialog then return end
    local visibleBeatCount = EditorLayout.getVisibleBeatCount(self.layout)
    local updated, errorMessage = self.session:update(deltaTime, visibleBeatCount)
    if not updated then self:showError(errorMessage) end
end

function EditorApp:draw(width, height)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    local previewError
    self.layout = EditorLayout.draw(width, height, self:getViewModel(), function(rect)
        local drawn, errorMessage = self.session:drawPreview(rect)
        if not drawn then previewError = errorMessage end
    end)
    if previewError and not self.dialog then self:showError(previewError) end
    if self.dialog then self.dialog:draw(width, height) end
end

function EditorApp:mousemoved(x, y)
    if self.dialog then return true end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    self.hoveredAction = item and item.enabled and item.action or nil
    return true
end

function EditorApp:mousepressed(x, y, button)
    if button ~= 1 then return true end
    if self.dialog then
        local previousProject = self.dialog:getSelection("projectId")
        self.dialog:mousepressed(x, y)
        local currentProject = self.dialog:getSelection("projectId")
        if self.dialog:getKind() == "openStage" and currentProject ~= previousProject then
            local stageIds, errorMessage = self.session:listStages(currentProject)
            if stageIds then
                local options = {}
                for _, stageId in ipairs(stageIds) do table.insert(options, { value = stageId, label = stageId }) end
                self.dialog:setSelectorOptions("stageId", options)
            else
                self:showError(errorMessage)
            end
        end
        return true
    end
    local items = EditorMenu.getItems(self.session)
    local item = EditorMenu.hitTest(self.layout.panels[1], items, x, y)
    if item and item.enabled then self:executeAction(item.action); return true end
    if self.session:hasStage() and not self.session:isPlaying()
        and EditorLayout.hitTestBpmValue(self.layout, x, y) then
        self.dialog = EditorDialog.editBpm(self.session:getBpm())
    end
    return true
end

function EditorApp:textinput(text)
    if self.dialog then self.dialog:textinput(text) end
    return true
end

function EditorApp:keypressed(key)
    if self.dialog then self.dialog:keypressed(key) end
    return true
end
```

모달이 열려 있을 때 `update`가 Session을 호출하지 않으므로 재생 clock과 preview가 임시 정지된다. 모달 취소 후에는 clock의 `playing` 상태가 그대로여서 다음 update부터 이어진다.

- [ ] **Step 8: Editor/Launcher/main 콜백 경계를 연결한다**

`editor/init.lua`:

```lua
function Editor.createApp(options)
    return EditorApp.new(options)
end
```

`launcher/Launcher.lua`의 `openEditor`:

```lua
function Launcher:openEditor()
    local launcher = self
    self.activeApp = Editor.createApp({
        onQuit = function()
            launcher:returnToMenu()
        end,
    })
    self.mode = "editor"
    self.errorMessage = nil
    return true
end
```

같은 파일의 active app 키 처리는 앱이 `true`를 반환하면 Launcher fallback을 실행하지 않게 바꾼다.

```lua
if self.activeApp.keypressed
    and self.activeApp:keypressed(key, scanCode, isRepeat) then
    return
end
if key == "escape" then
    self:returnToMenu()
end
```

`main.lua`에 다음 callback을 추가한다.

```lua
function love.mousemoved(x, y, deltaX, deltaY, isTouch)
    if activeApp and activeApp.mousemoved then
        activeApp:mousemoved(x, y, deltaX, deltaY, isTouch)
    end
end

function love.mousepressed(x, y, button, isTouch, presses)
    if activeApp and activeApp.mousepressed then
        activeApp:mousepressed(x, y, button, isTouch, presses)
    end
end

function love.textinput(text)
    if activeApp and activeApp.textinput then
        activeApp:textinput(text)
    end
end
```

- [ ] **Step 9: 기존 Editor와 Launcher 테스트를 새 계약에 맞춘다**

`tests/EditorTest.lua`의 세 번째 case를 다음 코드로 교체한다. 세 fake는 Session 생성에 필요한 최소 계약만 제공한다.

```lua
{
    name = "에디터 공개 진입점은 Stage 없는 세션을 가진 앱을 만든다",
    run = function(test)
        local Editor = require("editor")
        local app = Editor.createApp({
            projectCatalog = {
                listProjects = function() return {}, nil end,
                getProject = function() return nil, "missing" end,
            },
            stageStore = {
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
```

`tests/LauncherTest.lua`의 반환 배열 끝에 다음 두 case를 추가한다.

```lua
{
    name = "에디터가 Escape를 소비하면 Launcher는 editor 모드에 남는다",
    run = function(test)
        local Launcher = require("launcher.Launcher")
        local launcher = Launcher.new()
        launcher:openEditor()

        launcher:keypressed("escape")

        test.assertEqual(launcher:getMode(), "editor")
        test.assertTrue(launcher.activeApp ~= nil)
    end,
},
{
    name = "에디터 Menu Quit은 Launcher 메뉴로 돌아온다",
    run = function(test)
        local Launcher = require("launcher.Launcher")
        local launcher = Launcher.new()
        launcher:openEditor()

        launcher.activeApp:executeAction("quit")

        test.assertEqual(launcher:getMode(), "menu")
        test.assertEqual(launcher.activeApp, nil)
    end,
},
```

기존 Sample Project의 Escape 복귀 test는 그대로 통과해야 한다.

이 두 Launcher case가 추가되므로 전체 기대 테스트 수는 79다.

- [ ] **Step 10: GREEN을 확인한다**

Run: `love . --test`

Expected: exit code `0`, `PASS: 79 tests`.

- [ ] **Step 11: 커밋한다**

```powershell
git add editor/EditorApp.lua editor/init.lua editor/ui/EditorDialog.lua launcher/Launcher.lua main.lua tests/EditorWorkflowTest.lua tests/EditorTest.lua tests/LauncherTest.lua tests/TestRunner.lua
git commit -m "feat: complete editor menu workflows"
```

---

### Task 10: 문서, 실제 Stage I/O와 GUI 완료 검증

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/WORKFLOW.md`
- Modify: `docs/STAGE_FORMAT.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/HANDOFF.md`
- Create ignored verification artifact: `.superpowers/editor-menu-smoke/`

**Interfaces:**
- Consumes: 완성된 Menu/Stage/TestPlayer 기능
- Produces: 한국어 사용법과 인수인계, 실제 source Stage 저장·열기 증거, 편집/재생/Pause/Launcher 화면 캡처

- [ ] **Step 1: 사용자 문서를 현재 구현 상태로 갱신한다**

`README.md`의 현재 상태와 실행 설명을 다음 내용으로 바꾼다.

```markdown
## 에디터 Menu

Launcher에서 `E`를 눌러 에디터를 연다. 에디터 Menu는 마우스로 조작한다.

- `New`: Project, Stage ID, Name과 BPM으로 빈 Stage 생성
- `Open`: Project의 `stages/*.json` 열기
- `Save`: 현재 `<stageId>.json` 저장
- `Save As`: 같은 Project 안에 새 Stage ID로 저장
- `Play`: 현재 beat부터 Project 화면 미리보기와 플레이헤드 재생
- `Pause`: 현재 beat를 보존하고 편집 화면으로 복귀
- `Quit`: 미저장 변경을 확인한 뒤 Launcher로 복귀

Stage가 수정되면 `Save*`로 표시된다. 에디터 화면에서 Escape는 Menu Quit을 대신하지 않으며, 모달 취소에만 사용한다.
```

`docs/ARCHITECTURE.md`에는 `Core.PlaybackClock`, `StageDocument`, `StageStore`, `EditorSession`, `TestPlayer Canvas`, Project `draw(width,height)`와 `onQuit` 콜백 경계를 추가한다.

`docs/WORKFLOW.md`의 Stage 편집과 테스트 플레이 절을 다음 순서로 갱신한다.

```text
Project 선택 → New/Open → Mixtape Properties에서 BPM 편집
→ Save/Save As → Play로 Project Canvas 확인 → Pause로 편집 복귀
```

Stage Event가 아직 TestPlayer에 전달되지 않는다는 제한을 같은 절에 명시한다.

`docs/STAGE_FORMAT.md`는 version 1 로더가 실제로 단일 BPM, 안전한 ID, Event 구조, Project/file ID 일치를 검증하며 파일명이 `<stageId>.json`이라고 현재형으로 기록한다.

`docs/ROADMAP.md`에서 다음 항목을 완료 처리한다.

- 고정 BPM 재생 시계
- Stage JSON 검증과 로딩
- 프로젝트와 Stage 선택
- JSON 저장과 불러오기
- 기본 Project Canvas 렌더링
- 재생, 일시정지와 자동 플레이헤드 추적

Pattern 참조 전개, Event 실행, 오디오 동기화, 프로젝트 입력 전달은 미완료로 유지한다.

- [ ] **Step 2: HANDOFF에 정확한 상태와 검증 기준을 기록한다**

`docs/HANDOFF.md`의 현재 상태에 다음을 포함한다.

- Menu 일곱 항목과 dirty 보호 완료
- Stage source JSON 저장·열기 완료
- BPM 편집과 고정 BPM clock 완료
- Project Canvas는 표시하지만 Event는 실행하지 않음
- 자동 테스트 `79 tests`
- dkjson 버전, 공식 URL과 실제 SHA-256
- 다음 작업은 Project Event 등록 계약과 Stage Event 실행 연결

현재 범위 밖 목록에서는 완료된 JSON 로딩·저장과 기본 TestPlayer를 제거하고, 남은 제한을 Event 실행·오디오·판정·입력으로 구체화한다.

- [ ] **Step 3: 실제 source 폴더 Stage 왕복 스모크를 실행한다**

무시되는 `.superpowers/editor-menu-smoke/io-main.lua`에서 production `ProjectCatalog`, `StageStore`, `EditorSession`을 사용해 다음을 수행한다.

```lua
local ProjectCatalog = require("editor.project.ProjectCatalog")
local StageStore = require("editor.stage.StageStore")
local StageDocument = require("editor.stage.StageDocument")

local catalog = ProjectCatalog.new()
local store = StageStore.new()
local project = assert(catalog:getProject("sample"))
local stageId = "editor-menu-smoke"
local path = "projects/sample/stages/" .. stageId .. ".json"
assert(not store:stageExists(project.id, stageId), "temporary Stage already exists")
local document = assert(StageDocument.create(project.id, stageId, "Editor Menu Smoke", 123))
assert(store:save(document:toTable(), false))
local loaded = assert(store:load(project.id, stageId))
assert(loaded.projectId == "sample")
assert(loaded.stageId == stageId)
assert(loaded.tempoMap[1].bpm == 123)
local absolutePath = love.filesystem.getSource():gsub("[\\/]+$", "") .. "/" .. path
assert(os.remove(absolutePath), "failed to remove temporary Stage")
print("PASS: native Stage save/open round trip")
love.event.quit(0)
```

하네스의 `package.path`는 저장소 루트의 `?.lua`와 `?/init.lua`를 먼저 사용하게 설정한다. 실행 전후 정확한 임시 경로가 저장소 아래인지 확인한다.

Run: `love .superpowers/editor-menu-smoke --io`

Expected: exit code `0`, `PASS: native Stage save/open round trip`, 실행 후 `projects/sample/stages/editor-menu-smoke.json`이 존재하지 않음.

- [ ] **Step 4: 마우스 기반 GUI 하네스를 작성한다**

`.superpowers/editor-menu-smoke/main.lua`는 production `Launcher`로 시작하고 다음 phase를 프레임 단위로 실행한다.

```text
launcher
→ Launcher:keypressed("e")
→ Menu의 New row 중심을 EditorApp:mousepressed로 클릭
→ dialog:getLayout()의 Project option과 Stage ID/Name/BPM field를 마우스로 선택
→ EditorApp:textinput으로 editor-menu-smoke / Editor Menu Smoke / 123 입력
→ Create button rect 중심을 마우스로 클릭
→ Menu Save row 중심 클릭
→ Menu Open row 중심 클릭 후 sample과 editor-menu-smoke option 선택, Open 클릭
→ Menu Play row 중심 클릭, 0.5초 이상 update
→ Menu Pause row 중심 클릭
→ Menu Quit row 중심 클릭
→ Launcher menu 복귀 확인
```

New modal의 기본 BPM `120`과 입력 필드 기존 값은 field 클릭 후 Backspace를 현재 UTF-8 문자 수만큼 전달해 비운 뒤 새 값을 입력한다. 각 phase에서 `Launcher:getMode()`, `EditorApp:getDialog():getKind()`, `EditorSession`의 Stage ID·dirty·playing 상태를 단언한다.

캡처 파일:

```text
launcher.png
new-dialog.png
editor-dirty.png
editor-saved.png
open-dialog.png
playing.png
paused.png
launcher-return.png
result.txt
```

`playing.png`에서 Properties와 Values 대신 Project Canvas가 보여야 하고 `paused.png`에서는 두 패널과 `BPM | 123`이 복원되어야 한다. `launcher.png`와 `launcher-return.png`의 SHA-256은 같아야 한다.

하네스 종료 전에 생성한 `projects/sample/stages/editor-menu-smoke.json`의 절대 경로를 검증하고 `os.remove`로 제거한다. 기존 파일이 있으면 하네스를 시작하지 않는다.

- [ ] **Step 5: GUI 하네스를 실행하고 캡처를 확인한다**

```powershell
$env:RWD_SMOKE_OUTPUT = (Resolve-Path '.superpowers\editor-menu-smoke\output').Path
& 'C:\Program Files\LOVE\lovec.exe' '.superpowers\editor-menu-smoke'
$rwdSmokeExit = $LASTEXITCODE
Remove-Item Env:RWD_SMOKE_OUTPUT
if ($rwdSmokeExit -ne 0) { exit $rwdSmokeExit }
Get-Content -Raw -Encoding utf8 '.superpowers\editor-menu-smoke\output\result.txt'
Get-FileHash '.superpowers\editor-menu-smoke\output\launcher.png', '.superpowers\editor-menu-smoke\output\launcher-return.png' -Algorithm SHA256
```

Expected:

```text
PASS: editor menu GUI smoke
launcher -> editor -> new -> save -> open -> play -> pause -> launcher
```

두 Launcher PNG의 SHA-256이 같고 `view_image`로 `new-dialog.png`, `editor-dirty.png`, `playing.png`, `paused.png`를 확인한다.

- [ ] **Step 6: 전체 자동 검증을 새로 실행한다**

```powershell
& 'C:\Program Files\LOVE\lovec.exe' --version
& 'C:\Program Files\LOVE\lovec.exe' . --test
Get-ChildItem -Path projects -Recurse -Filter '*.json' | ForEach-Object {
    Get-Content -Raw -Encoding utf8 -LiteralPath $_.FullName | ConvertFrom-Json | Out-Null
}
rg -n 'require\("core\.' editor projects
rg -n 'require\("editor' projects
Select-String -Path vendor/dkjson.lua -Pattern 'dkjson 2.10'
Get-FileHash vendor/dkjson.lua -Algorithm SHA256
git diff --check
git status --short
```

Expected:

- `LOVE 11.5 (Mysterious Mysteries)`
- `PASS: 79 tests`
- 모든 JSON parse 성공
- 두 금지 의존성 `rg` 검색 결과 없음
- dkjson 2.10 문자열과 64자리 SHA-256 출력
- `git diff --check` 출력 없음
- `git status --short`에는 사용자 소유 `.references/` 외 추적/미추적 제품 파일이 남지 않음

- [ ] **Step 7: 실제 GUI 시작을 확인한다**

`love .`을 실행해 Launcher가 보이고 응답하는지 확인한다. `E`로 Editor에 들어가 Menu 일곱 항목과 비어 있는 나머지 패널, 타임라인을 확인한 뒤 창을 닫는다.

Expected: LÖVE 오류 화면 없음, 창 `Responding=True`, Menu에 Upload 없음.

- [ ] **Step 8: 문서와 검증 결과를 커밋한다**

```powershell
git add README.md docs/ARCHITECTURE.md docs/WORKFLOW.md docs/STAGE_FORMAT.md docs/ROADMAP.md docs/HANDOFF.md
git commit -m "docs: document editor menu workflow"
```

`.superpowers/`와 `.references/`는 커밋하지 않는다.

---

## 최종 완료 체크리스트

- [ ] `New | Open | Save | Save As | Play | Pause | Quit`만 표시된다.
- [ ] New가 Project, Stage ID, Name, BPM으로 `events: []` Stage를 만든다.
- [ ] Open/Save/Save As가 Project `stages` 경계 안에서만 동작한다.
- [ ] dirty 상태가 `Save*`로 보이고 New/Open/Quit에 Save/Discard/Cancel이 적용된다.
- [ ] `Global → Mixtape Properties` 선택 상태에서 `BPM | 값`이 동시에 보이고 편집된다.
- [ ] Play가 현재 beat부터 clock과 Project Canvas를 시작한다.
- [ ] Pause가 beat를 보존하고 Properties/Values를 복원한다.
- [ ] Event 실행, 오디오, 판정과 Project 입력은 구현되지 않는다.
- [ ] 파일·preview 오류가 Editor와 Launcher를 중단시키지 않는다.
- [ ] 자동 테스트, 실제 JSON 왕복, GUI 캡처와 실제 `love .` 실행이 모두 검증된다.
