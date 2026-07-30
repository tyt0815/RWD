# Core Stage 소유권 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stage 형식·저장 절차·Project manifest 검증을 Core 공개 API로 통합하고, Project Event를 Category 범위의 ID로 전환하며, Launcher가 조립한 하나의 Stage Repository를 Editor와 Project가 함께 사용하게 한다.

**Architecture:** `Core.StageSchema`, `Core.StageRepository`, `Core.ProjectManifest`가 공통 데이터 계약을 소유한다. Launcher는 네이티브 파일 접근·Project 경로·JSON을 조립하고, Editor와 Project는 주입받은 동일 Repository만 사용한다. Editor의 `StageDocument`는 편집 snapshot과 dirty/mutation만 소유하며, Project Event의 저장·조회·실행 식별자는 `categoryId + eventId`다.

**Tech Stack:** LÖVE2D 11.5, LuaJIT/Lua 5.1, dkjson, PowerShell, Python unittest, 프로젝트 내장 Lua 테스트 러너

## Global Constraints

- 설계 기준은 `docs/superpowers/specs/2026-07-30-core-stage-ownership-design.md`다. 구현 중 설계와 충돌하면 임의로 범위를 넓히지 말고 설계 문서를 다시 확인한다.
- LÖVE2D 11.5와 LuaJIT/Lua 5.1 호환 문법만 사용한다. `goto`, Lua 5.2+ 전용 API와 문법을 사용하지 않는다.
- `editor/`와 `projects/`는 `require("core")` 공개 진입점만 사용한다. `core.*` 내부 경로를 직접 require하지 않는다.
- `projects/`는 `editor.*`와 `launcher.*`를 require하지 않는다. `launcher/`는 조립만 하고 Stage 형식·검증 규칙을 구현하지 않는다.
- Stage v2 호환 loader나 migration branch를 추가하지 않는다. 저장소의 Stage와 테스트 fixture를 v3로 직접 갱신한다.
- 공개 Event 조회 계약과 Project 생성 옵션이 깨지므로 `Core.CORE_API_VERSION`을 1에서 2로 올린다. Sample과 Rhythm Dotgeo manifest도 함께 2로 갱신한다.
- `StageSchema.validate(stage)` 성공값은 `true, nil, nil`, 실패값은 `nil, userMessage, "INVALID_STAGE"`다.
- `StageSchema.normalize(stage)`는 입력을 변경하지 않고 방어적으로 복제한 sparse 저장형 table을 반환한다. 실패 계약은 `validate`와 같다.
- `StageSchema.resolveEditorSettings(stage)`는 매번 새로운 fully-resolved table을 반환한다. 반환 table과 입력 Stage 사이에 공유되는 하위 table이 없어야 한다.
- `ProjectManifest.validate(project, options)` 성공값은 `true, nil, nil`, 실패값은 `nil, userMessage, "INVALID_PROJECT"`다.
- Repository의 사용자·I/O 오류는 예외가 아니라 `nil, userMessage, errorCode`로 반환한다. 초기 코드는 `INVALID_STAGE`, `NOT_FOUND`, `STAGE_EXISTS`, `DECODE_FAILED`, `READ_FAILED`, `WRITE_FAILED`만 사용한다.
- 주입 객체의 필수 메서드가 없는 경우는 프로그래머 계약 위반이므로 constructor에서 `assert`한다.
- Core는 Dialog/Toast를 만들지 않는다. 기존 EditorApp이 반환된 메시지와 코드를 현재 Dialog/Toast 흐름에 연결한다.
- Editor의 New/Open/Save/Save As, Project/Stage/Music/Auto Play 선택, Timeline 배치·선택·drag·clipboard·Undo/Redo, Property 편집, Play/Pause와 preview 사용감은 바꾸지 않는다.
- 이번 계획은 StageRuntime 이중 소유 제거, Launcher 메뉴 자동 생성, EditorApp/EditorSession 추가 분리, 실제 `.love` 패키징과 Metronome 6건 수정을 포함하지 않는다.
- production 변경은 먼저 새 기대를 표현하는 실패 테스트를 추가하고 RED를 확인한 뒤 최소 구현으로 GREEN을 만든다.
- 현재 전체 suite에는 Metronome 진폭 기대 불일치로 6건의 기존 실패가 있다. 각 단계의 GREEN은 “관련 새 실패 0건, 전체 suite 실패는 기존 Metronome 6건만 남음”을 뜻한다.
- `.references/`와 사용자 소유 변경은 건드리지 않는다.

---

## File Structure

### 새 파일

- `core/StageSettings.lua`: Stage에 저장되는 Editor 설정의 기본값·범위·compact 규칙. Core 내부 구현이며 외부 소비자는 직접 require하지 않는다.
- `core/StageSchema.lua`: Stage v3 형식, ID, Event, JSON table kind, normalize와 resolved Editor settings 공개 계약.
- `core/ProjectManifest.lua`: Project manifest와 Category/Event/property 구조의 단일 검증 권위.
- `core/StageRepository.lua`: Stage 목록·존재·decode·검증·normalize·encode·원자 저장 절차.
- `launcher/NativeFileSystem.lua`: source root와 packaged `.love` 차이를 처리하는 네이티브 파일 primitive adapter.
- `tests/StageSchemaTest.lua`: Stage v3, sparse normalize, JSON object/array/null과 Editor 설정 계약.
- `tests/ProjectManifestTest.lua`: manifest/API version/Category 범위 Event ID 계약.
- `tests/StageRepositoryTest.lua`: fake JSON/FileSystem/path를 사용한 Repository 오류 코드와 저장 절차.
- `tests/NativeFileSystemTest.lua`: source root 경로 변환과 packaged source 쓰기 거부.
- `tests/ModuleBoundaryTest.lua`: Core/Editor/Project/Launcher require 경계 회귀 검사.

### 주요 수정 파일

- `core/init.lua`: 새 Core 공개 API export와 API version 2.
- `core/ProjectEvents.lua`: manifest 검증 제거, `getEvent(project, categoryId, eventId)` 조회만 제공.
- `core/ProjectCategories.lua`: Category별 Event Runtime table과 `categoryId + eventId` dispatch.
- `editor/stage/StageDocument.lua`: Core StageSchema 기반 편집 모델로 축소.
- `editor/EditorSession.lua`: `stageRepository` 사용, Category-qualified Project Event 검증·편집.
- `editor/EditorApp.lua`: Repository 필수 주입과 `project:<categoryId>:<eventId>` 내부 key 사용.
- `editor/project/ProjectCatalog.lua`: Core.ProjectManifest만 사용.
- `editor/properties/PropertyCatalog.lua`: Category-qualified Event 조회와 Timeline type 생성.
- `launcher/ProjectLoader.lua`: Core.ProjectManifest와 필수 `stageRepository` 전달.
- `launcher/Launcher.lua`: NativeFileSystem·Stage path·JSON으로 Repository를 한 번 조립하고 Editor/Project에 같은 인스턴스 전달.
- `projects/rhythm_dotgeo/game/Game.lua`, `projects/rhythm_dotgeo/game/StageSelect.lua`: `stageRepository` 옵션과 필드 사용.
- `tools/create_project.py`, `tests_python/test_create_project.py`: 새 Project template의 Repository 계약 갱신.
- `projects/sample/stages/test.json`, `projects/rhythm_dotgeo/stages/speaki_song.json`: schemaVersion 3과 Project Event `categoryId`.
- 관련 Lua tests: v3 fixture, 새 option 이름, Event composite identity와 GUI 회귀 기대값.

### 제거 파일

- `editor/stage/EditorSettings.lua`: 규칙이 `core/StageSettings.lua`와 `Core.StageSchema`로 이동한다.
- `editor/stage/StageStore.lua`: 저장 절차가 `Core.StageRepository`로 이동한다.
- `editor/stage/NativeFileSystem.lua`: 환경 adapter가 `launcher/NativeFileSystem.lua`로 이동한다.
- `tests/EditorSettingsTest.lua`: `tests/StageSchemaTest.lua`로 흡수한다.
- `tests/StageStoreTest.lua`: `tests/StageRepositoryTest.lua`와 `tests/NativeFileSystemTest.lua`로 분리한다.

### 의도적으로 변경하지 않는 파일

- `core/StageRuntime.lua`: Phase 2에서 단일 실행 권위로 재설계한다.
- `editor/playback/TestPlayer.lua`: 같은 Project 생성 factory를 계속 사용한다.
- `editor/playback/MetronomePlayback.lua`, `tests/MetronomePlaybackTest.lua`: 기존 6건 실패는 이번 범위 밖이다.
- `launcher/Launcher.lua`의 표시 메뉴와 키 `1`, `2`: 자동 Project 메뉴는 Phase 3 범위다.
- Project Category Runtime/Event/Actor/Sprite/SFX 구현: occurrence에 `categoryId`가 추가되지만 Runtime 내부 handler의 `event.eventId` 사용은 그대로다.

---

### Task 1: Core StageSchema와 Stage 설정 계약

**Files:**
- Create: `core/StageSettings.lua`
- Create: `core/StageSchema.lua`
- Create: `tests/StageSchemaTest.lua`
- Modify: `core/init.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Add: `Core.StageSchema.validate(stage) -> true,nil,nil | nil,message,"INVALID_STAGE"`
- Add: `Core.StageSchema.normalize(stage) -> normalized,nil,nil | nil,message,"INVALID_STAGE"`
- Add: `Core.StageSchema.resolveEditorSettings(stage) -> settings`
- Add: `Core.StageSchema.isSafeId(value) -> boolean`
- Internal only: `StageSettings.validate(value)`, `StageSettings.resolve(value)`, `StageSettings.compact(value)`
- Keep temporarily: `editor.stage.EditorSettings`, `StageDocument.validate`와 schemaVersion 2 소비 경로. 이 Task에서는 새 계약을 병렬로 추가만 한다.

- [ ] **Step 1: Stage v3 최소 유효 Stage와 오류 계약 RED 테스트 작성**

`tests/StageSchemaTest.lua`의 첫 fixture와 테스트는 정확히 v3를 요구한다.

```lua
local function validStage()
    return {
        schemaVersion = 3,
        projectId = "sample",
        stageId = "test",
        name = "Test",
        bpm = 120,
        events = {},
    }
end

return {
    {
        name = "StageSchema는 schemaVersion 3 최소 Stage를 검증한다",
        run = function(test)
            local Schema = require("core").StageSchema
            local valid, message, code = Schema.validate(validStage())
            test.assertEqual(valid, true)
            test.assertEqual(message, nil)
            test.assertEqual(code, nil)

            local invalid = validStage()
            invalid.schemaVersion = 2
            local rejected, errorMessage, errorCode = Schema.validate(invalid)
            test.assertEqual(rejected, nil)
            test.assertContains(errorMessage, "$.schemaVersion")
            test.assertEqual(errorCode, "INVALID_STAGE")
        end,
    },
}
```

`tests/TestRunner.lua`에서 `tests.EditorSettingsTest` 앞에 `tests.StageSchemaTest`를 등록한다.

- [ ] **Step 2: StageSchema export 부재로 RED 확인**

Run: `love . --test`

Expected: 기존 Metronome 6건 외에 `StageSchema는 schemaVersion 3 최소 Stage를 검증한다`가 `StageSchema` nil로 실패한다.

- [ ] **Step 3: EditorSettings 규칙을 Core 내부 StageSettings로 그대로 이동**

`editor/stage/EditorSettings.lua`의 현재 기본값과 범위를 동작 변경 없이 `core/StageSettings.lua`로 복사한다. 다음 값을 유지한다.

```lua
local DEFAULTS = {
    metronome = false,
    metronomePeriod = 4,
    snap = 1,
    onsetThreshold = 0.01,
    scale = 1,
    playbackRate = 1,
    autoPlay = "none",
    trackCount = 10,
    previewAspectWidth = 16,
    previewAspectHeight = 9,
}
```

이 파일은 `core/init.lua`에서 export하지 않는다. 외부 코드가 `Core.StageSchema`를 건너뛰지 못하게 한다.

- [ ] **Step 4: StageSchema 최소 공개 계약 구현**

`core/StageSchema.lua`는 `Core`를 다시 require하지 않고 필요한 sibling만 직접 require한다.

```lua
local MixtapeSettings = require("core.MixtapeSettings")
local StageSettings = require("core.StageSettings")

local StageSchema = {}
local ERROR_INVALID_STAGE = "INVALID_STAGE"
local SAFE_ID_PATTERN = "^[a-z0-9][a-z0-9_-]*$"
```

다음 규칙을 `StageDocument`에서 이동한다.

- JSON object/array 판별은 dkjson의 `__jsontype`과 `__tojson`을 보존한다.
- `projectId`, `stageId`는 safe ID이며 Windows 예약 basename을 거부한다.
- `schemaVersion == 3`, non-empty `name`, positive finite `bpm`, array `events`를 요구한다.
- `mixtape`와 `editorSettings`는 object이며 기존 MixtapeSettings/StageSettings 규칙을 통과해야 한다.
- Event ID는 Stage 안에서 고유하고 `startBeat >= 0`, track은 resolved `trackCount` 안의 정수다.
- `projectEvent`는 `track`, non-empty `categoryId`, non-empty `eventId`, object `params`를 모두 요구한다.
- `pattern`, `tapNote`, `longNote`, `end`, `setInputEnabled`의 현재 규칙과 End 단일성은 유지한다.
- `tempoMap`은 v3에서도 아직 지원하지 않는다. 오류 문구만 schemaVersion 3 기준으로 갱신한다.

`core/init.lua`에 다음 한 줄만 추가하고 아직 API version은 올리지 않는다.

```lua
Core.StageSchema = require("core.StageSchema")
```

- [ ] **Step 5: normalize와 resolved settings의 불변성 테스트 추가**

`tests/StageSchemaTest.lua`에 다음 계약을 추가한다.

```lua
{
    name = "StageSchema normalize은 입력을 바꾸지 않고 sparse 저장형을 만든다",
    run = function(test)
        local Schema = require("core").StageSchema
        local stage = validStage()
        stage.editorSettings = { scale = 2, snap = 1 }
        stage.events = {
            {
                id = "event-001",
                type = "projectEvent",
                categoryId = "sampleGameplay",
                eventId = "spawnActors",
                startBeat = 0,
                track = 1,
                params = {},
            },
        }

        local normalized = assert(Schema.normalize(stage))
        test.assertEqual(stage.editorSettings.snap, 1)
        test.assertEqual(normalized.editorSettings.snap, nil)
        test.assertEqual(normalized.editorSettings.scale, 2)
        test.assertTrue(normalized ~= stage)
        test.assertTrue(normalized.events ~= stage.events)
        test.assertEqual(getmetatable(normalized.events[1].params).__jsontype, "object")
    end,
},
{
    name = "StageSchema resolved Editor 설정은 매번 독립된 전체 값이다",
    run = function(test)
        local Schema = require("core").StageSchema
        local stage = validStage()
        stage.editorSettings = { scale = 2 }
        local first = Schema.resolveEditorSettings(stage)
        local second = Schema.resolveEditorSettings(stage)
        first.scale = 7
        test.assertEqual(second.scale, 2)
        test.assertEqual(second.snap, 1)
        test.assertEqual(second.trackCount, 10)
    end,
},
```

기존 `tests/EditorSettingsTest.lua`의 기본값·compact·범위 cases를 이 파일에 같은 기대값으로 복제한다. 아직 기존 테스트 파일은 삭제하지 않는다.

- [ ] **Step 6: normalize 구현과 StageSchema 전체 GREEN 확인**

`normalize`은 다음 순서를 지킨다.

1. `validate(stage)` 호출
2. metatable을 보존하는 cycle-safe deep copy
3. `MixtapeSettings.compact`와 `StageSettings.compact`; compact 결과가 빈 table이면 해당 optional section을 nil로 만들어 `{}`를 불필요하게 저장하지 않음
4. 빈 `pattern.params`와 `projectEvent.params`에 `{ __jsontype = "object" }` metatable 부여
5. 복제본 반환

Run: `love . --test`

Expected: StageSchema/기존 EditorSettings 관련 테스트는 통과하고 전체 실패는 기존 Metronome 6건만 남는다.

- [ ] **Step 7: Task 1 커밋**

```powershell
git add core/StageSettings.lua core/StageSchema.lua core/init.lua tests/StageSchemaTest.lua tests/TestRunner.lua
git commit -m "feat: add core stage schema"
```

---

### Task 2: ProjectManifest 검증 권위 단일화

**Files:**
- Create: `core/ProjectManifest.lua`
- Create: `tests/ProjectManifestTest.lua`
- Modify: `core/init.lua`
- Modify: `core/ProjectEvents.lua`
- Modify: `core/ProjectCategories.lua`
- Modify: `launcher/ProjectLoader.lua`
- Modify: `editor/project/ProjectCatalog.lua`
- Modify: `tests/ProjectEventsTest.lua`
- Modify: `tests/ProjectCategoriesTest.lua`
- Modify: `tests/ProjectLoaderTest.lua`
- Modify: `tests/ProjectCatalogTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Add: `Core.ProjectManifest.validate(project, options) -> true,nil,nil | nil,message,"INVALID_PROJECT"`
- Keep for this Task: `Core.ProjectEvents.getEvent(project, eventId)`; composite lookup은 Task 4에서 전환한다.
- Remove: `Core.ProjectEvents.validate(project)`
- Change: ProjectLoader와 ProjectCatalog가 동일 `Core.ProjectManifest.validate` 결과를 사용한다.

- [ ] **Step 1: Category 범위 Event ID RED 테스트 작성**

`tests/ProjectManifestTest.lua`에 같은 Event ID가 다른 Category에서 허용되고 같은 Category에서는 거부되는 테스트를 작성한다.

```lua
local function projectWith(categories)
    return {
        id = "sample",
        title = "Sample",
        coreApiVersion = 1,
        entryModule = "projects.sample.game.SampleGame",
        eventCategories = categories,
    }
end

local function category(id, events)
    return {
        id = id,
        label = id,
        runtimeModule = "projects.sample.game." .. id .. ".Runtime",
        events = events,
    }
end

local function event(id)
    return { id = id, label = id, properties = {} }
end
```

검증 호출은 다음과 같이 고정한다.

```lua
local valid, message, code = Core.ProjectManifest.validate(project, {
    expectedId = "sample",
    expectedCoreApiVersion = 1,
})
```

Assertions:

- `category("first", { event("spawn") })`와 `category("second", { event("spawn") })` 조합은 성공한다.
- 한 Category 안의 `event("spawn")` 두 개는 `INVALID_PROJECT`로 실패한다.
- Category ID 중복, expected ID 불일치, Core API version 불일치, 빈 `entryModule`, 잘못된 number property default는 각각 실패한다.

- [ ] **Step 2: ProjectManifest 부재 RED 확인**

`tests/TestRunner.lua`에서 `tests.ProjectEventsTest` 앞에 `tests.ProjectManifestTest`를 등록한다.

Run: `love . --test`

Expected: 새 ProjectManifest 테스트가 export 부재로 실패하고 기존 Metronome 6건이 유지된다.

- [ ] **Step 3: ProjectManifest 구현**

`core/ProjectManifest.lua`는 다음 순서로 검증한다.

1. manifest table
2. non-empty `id`, `title`, `entryModule`
3. `options.expectedId`가 있으면 manifest ID 일치
4. `options.expectedCoreApiVersion`가 있으면 `coreApiVersion` 일치
5. `eventCategories`가 nil 또는 array
6. Category ID는 `^[A-Za-z0-9_][A-Za-z0-9_-]*$` identifier, label은 non-empty string, Project 범위 Category ID는 고유, `runtimeModule`은 존재할 때 non-empty string
7. Category별 새 `eventIds` table을 만들고 같은 Category 안에서만 Event ID 고유성 검사. Event ID도 같은 identifier pattern을 사용해 composite timeline key의 `:` 구분자와 충돌하지 않게 한다.
8. Event label, properties array, Category Event 안의 property ID 고유성, property kind/default/min/max의 현재 number 계약

모든 실패는 helper 하나로 다음 형태를 반환한다.

```lua
local function invalid(message)
    return nil, message, "INVALID_PROJECT"
end
```

`core/init.lua`에 export한다.

```lua
Core.ProjectManifest = require("core.ProjectManifest")
```

- [ ] **Step 4: Launcher와 Editor의 중복 검증 제거**

`launcher/ProjectLoader.lua`의 parameter 이름을 `loadProject(projectId, expectedCoreApiVersion)`로 명확히 하고, local `validateProject`를 삭제한 뒤 다음 호출만 사용한다.

```lua
local valid, validationError, validationCode = Core.ProjectManifest.validate(
    projectOrError,
    {
        expectedId = projectId,
        expectedCoreApiVersion = expectedCoreApiVersion,
    }
)
if not valid then
    return nil, validationError, validationCode
end
```

ProjectCatalog도 같은 호출을 사용하되 `expectedCoreApiVersion = self.coreApiVersion`을 전달한다. 별도의 `projectOrError.id ~= projectId` branch는 expectedId 검사가 같은 책임을 이미 가지므로 삭제한다.

- [ ] **Step 5: ProjectEvents 구조 검증 제거와 discovery 중복 제거**

`core/ProjectEvents.lua`에서 `validate`와 그 전용 `isFinite` 사용을 삭제한다. `getCategories`, `getEvent`, `getDefaultParams`, `validateParams`만 유지한다. `validateParams`가 finite number helper를 계속 쓰므로 helper 자체는 유지한다.

`core/ProjectCategories.lua`의 discovery는 Definition table, Runtime.lua 존재와 runtimeModule 조립까지만 담당한다. 임시 Project를 만들어 `ProjectEvents.validate`하는 코드를 삭제한다. 완성된 manifest는 ProjectLoader/ProjectCatalog의 ProjectManifest에서 한 번 검증된다.

- [ ] **Step 6: 기존 manifest 소비 테스트를 새 오류 계약으로 갱신**

- `tests/ProjectEventsTest.lua`: `ProjectEvents.validate(project)` assertion을 제거하고 Event lookup/default params/params validation만 검증한다.
- `tests/ProjectLoaderTest.lua`: invalid manifest가 세 번째 값 `INVALID_PROJECT`를 반환하는지 추가한다.
- `tests/ProjectCatalogTest.lua`: directory ID 불일치와 API mismatch가 `Core.ProjectManifest`와 같은 메시지/code를 쓰는지 확인한다.
- `tests/ProjectCategoriesTest.lua`: discovery 테스트는 파일 발견과 runtimeModule 조립만 검증한다.

Run: `love . --test`

Expected: ProjectManifest, ProjectLoader, ProjectCatalog와 ProjectCategories 관련 새 실패가 없고 기존 Metronome 6건만 남는다.

- [ ] **Step 7: duplicate validator가 사라졌는지 정적 확인**

Run:

```powershell
rg -n 'local function validateProject|ProjectEvents\.validate' launcher editor core tests
```

Expected: 검색 결과 없음.

- [ ] **Step 8: Task 2 커밋**

```powershell
git add core/ProjectManifest.lua core/ProjectEvents.lua core/ProjectCategories.lua core/init.lua launcher/ProjectLoader.lua editor/project/ProjectCatalog.lua tests/ProjectManifestTest.lua tests/ProjectEventsTest.lua tests/ProjectCategoriesTest.lua tests/ProjectLoaderTest.lua tests/ProjectCatalogTest.lua tests/TestRunner.lua
git commit -m "refactor: centralize project manifest validation"
```

---

### Task 3: Core StageRepository와 Launcher 파일 adapter

**Files:**
- Create: `core/StageRepository.lua`
- Create: `launcher/NativeFileSystem.lua`
- Create: `tests/StageRepositoryTest.lua`
- Create: `tests/NativeFileSystemTest.lua`
- Modify: `core/init.lua`
- Modify: `tests/TestRunner.lua`
- Reference only: `editor/stage/StageStore.lua`
- Reference only: `editor/stage/NativeFileSystem.lua`

**Interfaces:**
- Add: `Core.StageRepository.new({ fileSystem, paths, json }) -> repository`
- Add: `repository:listStages(projectId) -> stageIds,nil,nil | nil,message,code`
- Add: `repository:stageExists(projectId, stageId) -> boolean,nil,nil | nil,message,code`
- Add: `repository:load(projectId, stageId) -> normalizedStage,nil,nil | nil,message,code`
- Add: `repository:save(stage, overwrite) -> true,nil,nil | nil,message,code`
- Add Launcher primitive adapter: `list`, `read`, `isFile`, `exists`, `write`, `remove`, `rename`, `copy`
- Keep temporarily: Editor StageStore/NativeFileSystem와 현재 소비 경로. Task 5에서 제거한다.

- [ ] **Step 1: Repository fake dependency와 constructor RED 테스트 작성**

`tests/StageRepositoryTest.lua`의 paths 계약을 다음처럼 고정한다.

```lua
local PATHS = {
    stageDirectory = function(projectId)
        return "projects/" .. projectId .. "/stages"
    end,
    stageFile = function(projectId, stageId)
        return "projects/" .. projectId .. "/stages/" .. stageId .. ".json"
    end,
}
```

fake FileSystem은 relative path를 key로 갖는 `files` table과 다음 메서드를 제공한다.

```lua
list(path)
read(path)
isFile(path)
exists(path)
write(path, contents)
remove(path)
rename(sourcePath, targetPath)
copy(sourcePath, targetPath)
```

첫 테스트는 constructor와 목록 정렬을 검증한다.

```lua
local repository = Core.StageRepository.new({
    fileSystem = fileSystem,
    paths = PATHS,
    json = require("vendor.dkjson"),
})
local stageIds = assert(repository:listStages("sample"))
test.assertEqual(stageIds[1], "alpha")
test.assertEqual(stageIds[2], "zeta")
```

- [ ] **Step 2: StageRepository 부재 RED 확인**

`tests/TestRunner.lua`에 `tests.StageRepositoryTest`, `tests.NativeFileSystemTest`를 StageDocument 계열 앞에 등록한다.

Run: `love . --test`

Expected: StageRepository/NativeFileSystem module not found가 새 실패로 나타나고 기존 Metronome 6건이 유지된다.

- [ ] **Step 3: Repository read/error code 테스트 추가**

다음 cases를 각각 독립 테스트로 작성한다.

- unsafe project/stage ID -> `INVALID_STAGE`
- 없는 Stage -> `NOT_FOUND`
- list/read primitive 실패 -> `READ_FAILED`
- JSON syntax 오류 또는 trailing content -> `DECODE_FAILED`
- decoded v2 또는 필드 오류 -> `INVALID_STAGE`
- JSON `projectId`와 선택 Project 불일치 -> `INVALID_STAGE`
- JSON `stageId`와 파일명 불일치 -> `INVALID_STAGE`
- 정상 load -> StageSchema가 normalize한 방어적 v3 table

오류 비교는 메시지 전체가 아니라 의미 있는 substring과 정확한 code를 함께 검사한다.

- [ ] **Step 4: Repository write/atomic rollback 테스트 추가**

정상 save가 아래 순서로 primitive를 호출하는지 fake operation log로 검증한다.

```text
write(target.tmp)
rename(target, target.bak)       # 기존 파일이 있을 때만
rename(target.tmp, target)
remove(target.bak)               # 교체 성공 후
```

추가 cases:

- overwrite false + 기존 파일 -> 원본 보존, `STAGE_EXISTS`
- StageSchema 실패 -> 어떤 write도 하지 않고 `INVALID_STAGE`
- JSON encode 예외 -> 어떤 write도 하지 않고 `WRITE_FAILED`
- temp write 실패 -> temp cleanup 시도, `WRITE_FAILED`
- 새 파일 replace 실패 -> temp cleanup, `WRITE_FAILED`
- 기존 파일 replace 실패 + backup rename rollback 성공 -> 원본 복원
- rollback rename 실패 + copy 성공 -> 원본 복원, backup 정리
- rollback rename과 copy 모두 실패 -> backup을 보존하고 메시지에 `.bak` 경로 포함

Core가 원자 교체 순서를 소유하고 NativeFileSystem은 위 primitive만 구현하게 한다. `writeAtomic`을 Launcher adapter에 다시 만들지 않는다.

- [ ] **Step 5: StageRepository 최소 구현**

constructor에서 다음 계약을 assert한다.

```lua
assert(type(options.fileSystem) == "table", "fileSystem is required")
assert(type(options.paths) == "table", "paths is required")
assert(type(options.paths.stageDirectory) == "function", "paths.stageDirectory is required")
assert(type(options.paths.stageFile) == "function", "paths.stageFile is required")
assert(type(options.json) == "table", "json is required")
assert(type(options.json.decode) == "function", "json.decode is required")
assert(type(options.json.encode) == "function", "json.encode is required")
```

JSON key order는 기존 StageStore 순서를 옮기고 `categoryId`를 `eventId` 앞에 둔다.

```lua
local JSON_KEY_ORDER = {
    "schemaVersion", "projectId", "stageId", "name", "bpm",
    "mixtape", "editorSettings", "events",
    "music", "volume", "beat0Offset",
    "snap", "scale", "playbackRate", "metronome", "metronomePeriod",
    "onsetThreshold", "previewAspectWidth", "previewAspectHeight",
    "id", "startBeat", "type", "categoryId", "eventId", "patternId",
    "params", "durationBeats", "responseDelayBeats",
}
```

`load`는 decode와 trailing content 확인 후 `StageSchema.normalize`을 호출한다. `save`도 먼저 normalize하고 normalized table만 encode한다. 입력 table은 변경하지 않는다.

- [ ] **Step 6: Launcher NativeFileSystem 구현과 테스트**

기존 `editor/stage/NativeFileSystem.lua`에서 root normalize/join, native read/write/copy와 packaged read 분기를 `launcher/NativeFileSystem.lua`로 옮긴다. atomic 알고리즘은 옮기지 않는다.

primitive 계약:

- unpackaged source: relative path를 source root에 join해 native operation 호출
- packaged `.love`: `list/read/isFile/exists`는 LÖVE filesystem 사용
- packaged `.love`: `write/remove/rename/copy`는 mutation 없이 `nil, "Cannot write Stage files inside a packaged .love source."` 반환

`tests/NativeFileSystemTest.lua`는 fake native operations와 임시 `love.filesystem` 대체를 사용해 경로와 packaged policy를 검증하고, 테스트 뒤 반드시 원래 `love`를 복구한다.

- [ ] **Step 7: Repository와 Native adapter GREEN 확인**

`core/init.lua`에 export한다.

```lua
Core.StageRepository = require("core.StageRepository")
```

Run: `love . --test`

Expected: 새 Repository/NativeFileSystem 테스트 전체 통과, 기존 Editor StageStore 테스트도 그대로 통과, 전체 실패는 Metronome 6건만 남는다.

- [ ] **Step 8: Task 3 커밋**

```powershell
git add core/StageRepository.lua core/init.lua launcher/NativeFileSystem.lua tests/StageRepositoryTest.lua tests/NativeFileSystemTest.lua tests/TestRunner.lua
git commit -m "feat: add core stage repository"
```

---

### Task 4: Stage v3와 Category-qualified Project Event 수직 전환

**Files:**
- Modify: `core/init.lua`
- Modify: `core/ProjectEvents.lua`
- Modify: `core/ProjectCategories.lua`
- Modify: `editor/stage/StageDocument.lua`
- Modify: `editor/stage/StageStore.lua`
- Modify: `editor/properties/PropertyCatalog.lua`
- Modify: `editor/EditorSession.lua`
- Modify: `editor/EditorApp.lua`
- Modify: `projects/sample/project.lua`
- Modify: `projects/rhythm_dotgeo/project.lua`
- Modify: `projects/sample/stages/test.json`
- Modify: `projects/rhythm_dotgeo/stages/speaki_song.json`
- Modify: `tests/CoreTest.lua`
- Modify: `tests/ProjectEventsTest.lua`
- Modify: `tests/ProjectCategoriesTest.lua`
- Modify: `tests/ProjectGameplayTest.lua`
- Modify: `tests/StageDocumentTest.lua`
- Modify: `tests/StageStoreTest.lua`
- Modify: `tests/EditorUiTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`
- Modify: `tests/SampleGameTest.lua`
- Modify: `tests/RhythmDotgeoGameTest.lua`
- Modify: `tests/ProjectLoaderTest.lua`
- Modify: `tests/ProjectCatalogTest.lua`
- Modify: `tests/LauncherTest.lua`
- Delete: `editor/stage/EditorSettings.lua`
- Delete: `tests/EditorSettingsTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Change: `Core.CORE_API_VERSION = 2`
- Change: `Core.ProjectEvents.getEvent(project, categoryId, eventId)`
- Change: Project timeline type from `project:<eventId>` to `project:<categoryId>:<eventId>`
- Change: `StageDocument:addEvent(eventType, startBeat, track, projectCategoryId, projectEventId, params)`
- Keep temporarily: `StageDocument.validate(data)`와 `StageDocument.isSafeId(value)`는 구 StageStore만을 위한 Core 위임 seam. Task 5에서 StageStore와 함께 제거한다.
- Keep GUI-visible Category/Event label, selection order, node rendering and interaction unchanged.

- [ ] **Step 1: composite Event identity RED 테스트 작성**

`tests/ProjectEventsTest.lua`에 서로 다른 Category가 같은 Event ID를 갖는 fixture를 추가하고 다음을 검증한다.

```lua
local first = Core.ProjectEvents.getEvent(project, "first", "spawn")
local second = Core.ProjectEvents.getEvent(project, "second", "spawn")
test.assertEqual(first.label, "First Spawn")
test.assertEqual(second.label, "Second Spawn")
test.assertEqual(Core.ProjectEvents.getEvent(project, "missing", "spawn"), nil)
```

`tests/ProjectCategoriesTest.lua`에는 두 Category 모두 `eventId = "spawn"`인 Runtime을 만들고, `categoryId = "second"` occurrence가 second Runtime에만 전달되는 테스트를 추가한다.

- [ ] **Step 2: Editor 내부 key와 StageDocument v3 RED 테스트 작성**

다음 기대를 먼저 바꾼다.

- `PropertyCatalog.getEvents("sampleGameplay", project)[1].timelineType == "project:sampleGameplay:spawnActors"`
- `PropertyCatalog.getTimelineEvent({ type="projectEvent", categoryId="sampleGameplay", eventId="spawnActors" }, project)`가 올바른 정의를 반환
- `StageDocument.create(projectId, stageId, name, bpm)`의 snapshot `schemaVersion == 3`
- `StageDocument:addEvent("projectEvent", 4, 2, "sampleGameplay", "cueResponse", params)`가 두 ID를 저장
- categoryId 없는 projectEvent는 Core.StageSchema에서 `$.events[1].categoryId` 오류

Run: `love . --test`

Expected: old lookup signature, schemaVersion 2와 timeline key 때문에 새 assertions가 실패한다. 기존 Metronome 실패는 그대로다.

- [ ] **Step 3: Core ProjectEvents와 Category Host 전환**

`Core.ProjectEvents.getEvent`를 중첩 조회로 바꾼다.

```lua
function ProjectEvents.getEvent(project, categoryId, eventId)
    for _, category in ipairs(ProjectEvents.getCategories(project)) do
        if category.id == categoryId then
            for _, event in ipairs(category.events or {}) do
                if event.id == eventId then return event end
            end
            return nil
        end
    end
    return nil
end
```

`ProjectCategories.createHost`의 flat `eventRuntimes[event.id]`를 다음 구조로 바꾼다.

```lua
host.eventRuntimes[category.id] = host.eventRuntimes[category.id] or {}
host.eventRuntimes[category.id][event.id] = runtimeOrError
```

`Host:applyOccurrences`는 `event.categoryId`와 `event.eventId`를 모두 사용한다. Category 또는 Event가 없을 때 오류 메시지에 둘 다 포함한다.

- [ ] **Step 4: StageDocument를 Core StageSchema 소비자로 축소**

`editor/stage/StageDocument.lua`에서 다음 구현을 제거한다.

- safe ID/Windows 예약어
- JSON object/array 판별
- Stage/Event 전체 validate
- EditorSettings require와 직접 compact/validate

`newDocument(data, dirty)`는 다음 형태로 만든다.

```lua
local normalized, errorMessage = Core.StageSchema.normalize(data)
if not normalized then return nil, errorMessage end
return setmetatable({ data = normalized, dirty = dirty }, StageDocument), nil
```

`create`는 `schemaVersion = 3`을 사용한다. `getEditorSettings`는 `Core.StageSchema.resolveEditorSettings(self.data)`를 사용한다.

`setBpm`, `setEditorSetting`, Event add/move/property 변경은 candidate snapshot을 만든 뒤 `Core.StageSchema.normalize(candidate)`로 전체 원자 검증한다. 실패하면 `self.data`와 dirty를 바꾸지 않는다. 성공하면 normalized candidate를 한 번에 교체한다.

Project Event 생성은 다음 필드를 저장한다.

```lua
event.categoryId = projectCategoryId
event.eventId = projectEventId
event.params = params or {}
```

Task 5 전까지 구 StageStore가 한 커밋 동안 동작하도록 두 helper는 검증 규칙을 소유하지 않는 adapter로만 남긴다.

```lua
function StageDocument.validate(data)
    local valid, errorMessage = Core.StageSchema.validate(data)
    return valid and nil or errorMessage
end

function StageDocument.isSafeId(value)
    return Core.StageSchema.isSafeId(value)
end
```

`editor/stage/StageStore.lua`의 JSON key order에는 `categoryId`를 `eventId` 앞에 추가한다. 그 외 저장 소유권은 Task 5에서 Repository로 교체되므로 이 단계에서 StageStore를 재설계하지 않는다.

- [ ] **Step 5: PropertyCatalog와 Editor의 composite key 전환**

`editor/properties/PropertyCatalog.lua`:

- `copyEvent(event, isProjectEvent, categoryId)`가 `projectCategoryId`를 반환한다.
- Project timelineType은 `"project:" .. categoryId .. ":" .. event.id`다.
- `getEvent(categoryId, eventId, project)`로 signature를 바꾼다.
- global/gameManager 조회 호출도 명시적 Category ID를 넘긴다.
- `getTimelineEvent`는 `event.categoryId`와 `event.eventId`로 Core.ProjectEvents를 조회한다.

`editor/EditorApp.lua`:

- 선택 Event 조회는 `PropertyCatalog.getEvent(self.selectedCategoryId, self.selectedEventId, project)`를 사용한다.
- defaults cache key는 composite timelineType을 그대로 사용한다.
- value edit group parse는 `^project:([^:]+):([^:]+)$`로 Category/Event를 얻는다.
- Core Event 조회에 두 ID를 전달한다.

`editor/EditorSession.lua`:

- `getProjectEventDefinition(project, categoryId, eventId)` helper 사용
- open/replace/paste/property validation과 singleton key를 `categoryId .. "\0" .. eventId`로 구분
- timeline type parse는 `^project:([^:]+):([^:]+)$`
- candidate/decorated Event와 `StageDocument:addEvent`에 두 ID 전달
- 오류 메시지에는 `categoryId .. "/" .. eventId`를 포함해 동명 Event를 구분

- [ ] **Step 6: Core API version과 Project manifest 갱신**

`core/init.lua`:

```lua
Core.CORE_API_VERSION = 2
```

`projects/sample/project.lua`와 `projects/rhythm_dotgeo/project.lua`의 `coreApiVersion`도 2로 바꾼다. `tests/CoreTest.lua`, `tests/ProjectLoaderTest.lua`, `tests/SampleGameTest.lua`, `tests/LauncherTest.lua`처럼 실제 manifest/Core version을 사용하는 tests도 2를 기준으로 갱신한다. `tests/ProjectCatalogTest.lua`처럼 독립 fixture가 의도적으로 `coreApiVersion = 1`을 주입해 mismatch를 검사하는 unit test는 그대로 둘 수 있다.

- [ ] **Step 7: 저장소 Stage JSON을 v3로 직접 갱신**

`projects/sample/stages/test.json`:

- `schemaVersion: 3`
- 모든 `type: "projectEvent"`에 `categoryId: "sampleGameplay"`

`projects/rhythm_dotgeo/stages/speaki_song.json`:

- `schemaVersion: 3`
- 모든 `type: "projectEvent"`에 `categoryId: "speakiSong"`

자동 migration code는 작성하지 않는다.

- [ ] **Step 8: 모든 Lua fixture와 내부 기대 key를 v3로 갱신**

다음 규칙으로 관련 tests를 명시적으로 수정한다.

- Stage table `schemaVersion = 2` -> `3`
- Sample Project Event -> `categoryId = "sampleGameplay"`
- Rhythm Dotgeo Project Event -> `categoryId = "speakiSong"`
- synthetic Category fixture -> 해당 fixture의 Category ID
- `project:cueResponse` -> `project:sampleGameplay:cueResponse`
- Project singleton 비교는 같은 Category/Event 조합만 중복으로 본다.
- Stage validation assertion은 `StageDocument.validate` 대신 `Core.StageSchema.validate`의 첫 반환값과 code를 검사한다.

반드시 다음 파일을 모두 검색·갱신한다.

```powershell
rg -n 'schemaVersion = 2|"schemaVersion"\s*:\s*2|type = "projectEvent"|"type"\s*:\s*"projectEvent"|project:[A-Za-z]' tests projects editor
```

- [ ] **Step 9: EditorSettings 제거와 TestRunner 정리**

`tests/EditorSettingsTest.lua`에서 유지할 계약이 모두 `tests/StageSchemaTest.lua`에 있는지 대조한 뒤 `editor/stage/EditorSettings.lua`, `tests/EditorSettingsTest.lua`를 삭제한다. `tests/TestRunner.lua`의 `tests.EditorSettingsTest` entry도 삭제한다.

삭제 후 확인:

```powershell
rg -n 'editor\.stage\.EditorSettings|EditorSettingsTest' . -g '!docs/superpowers/**'
```

Expected: 검색 결과 없음. `StageDocument.validate/isSafeId`는 이 시점에 구 StageStore에서만 참조되어야 한다.

- [ ] **Step 10: JSON 문법과 전체 GREEN 확인**

Run:

```powershell
Get-Content -Raw projects/sample/stages/test.json | ConvertFrom-Json | Out-Null
Get-Content -Raw projects/rhythm_dotgeo/stages/speaki_song.json | ConvertFrom-Json | Out-Null
love . --test
```

Expected: 두 JSON parse 성공. Stage v3/Event namespace 관련 실패가 없고 전체 suite 실패는 기존 Metronome 6건만 남는다.

- [ ] **Step 11: Task 4 커밋**

```powershell
git add core editor projects/sample projects/rhythm_dotgeo tests
git commit -m "refactor: namespace project events by category"
```

커밋 전에 `git diff --cached --stat`로 Metronome 파일이나 `.references/`가 포함되지 않았는지 확인한다.

---

### Task 5: 단일 StageRepository 조립·주입과 Editor 저장 모듈 제거

**Files:**
- Modify: `launcher/Launcher.lua`
- Modify: `launcher/ProjectLoader.lua`
- Modify: `editor/EditorApp.lua`
- Modify: `editor/EditorSession.lua`
- Modify: `editor/stage/StageDocument.lua`
- Modify: `projects/rhythm_dotgeo/game/Game.lua`
- Modify: `projects/rhythm_dotgeo/game/StageSelect.lua`
- Modify: `tools/create_project.py`
- Modify: `tests_python/test_create_project.py`
- Modify: `tests/LauncherTest.lua`
- Modify: `tests/ProjectLoaderTest.lua`
- Modify: `tests/ProjectCatalogTest.lua`
- Modify: `tests/EditorTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`
- Modify: `tests/RhythmDotgeoGameTest.lua`
- Modify: `tests/SampleGameTest.lua`
- Modify: `tests/TestRunner.lua`
- Delete: `editor/stage/StageStore.lua`
- Delete: `editor/stage/NativeFileSystem.lua`
- Delete: `tests/StageStoreTest.lua`

**Interfaces:**
- Change option/field name everywhere: `stageStore` -> `stageRepository`
- Change: `Launcher.new(options)` accepts optional injected `stageRepository` for tests; production builds one Repository exactly once.
- Change: `ProjectLoader.createGame(project, options)` requires `options.stageRepository` and never imports Editor storage. 기존 `standalone`, `transportFactory`, `eventHandlers` options는 그대로 전달한다.
- Change: `EditorApp.new(options)` and `EditorSession.new(options)` require `options.stageRepository` unless a fully built session is injected.

- [ ] **Step 1: 같은 Repository 인스턴스 주입 RED 테스트 작성**

`tests/LauncherTest.lua`에 fake Repository를 주입한다.

```lua
local repository = {
    listStages = function() return {}, nil end,
    stageExists = function() return false, nil end,
    load = function() return nil, "not used", "NOT_FOUND" end,
    save = function() return true, nil end,
}
local launcher = Launcher.new({ stageRepository = repository })
launcher:openEditor()
test.assertEqual(launcher.activeApp:getSession().stageRepository, repository)
```

별도 test에서 같은 Launcher로 Rhythm Dotgeo를 열고 `launcher.activeApp.stageRepository == repository`를 확인한다. Editor preview용 `createGame` factory도 ProjectLoader에 같은 instance를 넘기는지는 game fixture constructor가 받은 options를 기록해 확인한다.

- [ ] **Step 2: 필수 주입 계약 RED 테스트 작성**

`tests/ProjectLoaderTest.lua`의 기존 StageStore test를 다음 기대형으로 바꾼다.

```lua
local stageRepository = {}
local game = assert(ProjectLoader.createGame(project, {
    stageRepository = stageRepository,
    standalone = true,
    transportFactory = transportFactory,
}))
test.assertEqual(receivedOptions.stageRepository, stageRepository)
```

Repository 없이 createGame을 호출하면 `stageRepository is required` programmer-contract error가 발생하는지 `pcall`로 확인한다.

Run: `love . --test`

Expected: Launcher/ProjectLoader가 아직 old StageStore fallback을 사용해 새 assertions가 실패한다.

- [ ] **Step 3: Launcher에서 Repository를 한 번 조립**

`launcher/Launcher.lua` 상단에 다음 dependencies를 둔다.

```lua
local json = require("vendor.dkjson")
local NativeFileSystem = require("launcher.NativeFileSystem")
```

Launcher 소유 Stage path rule은 local table 하나로 둔다. 별도 범용 path abstraction을 만들지 않는다.

```lua
local STAGE_PATHS = {
    stageDirectory = function(projectId)
        return "projects/" .. projectId .. "/stages"
    end,
    stageFile = function(projectId, stageId)
        return "projects/" .. projectId .. "/stages/" .. stageId .. ".json"
    end,
}
```

`Launcher.new(options)`에서 production default를 생성한다.

```lua
local stageRepository = options.stageRepository or Core.StageRepository.new({
    fileSystem = options.fileSystem or NativeFileSystem.new(),
    paths = options.stagePaths or STAGE_PATHS,
    json = options.json or json,
})
```

이 instance를 launcher field로 저장한다. `openEditor`는 Editor에 직접 전달하고, Editor preview factory와 `openProject`는 `ProjectLoader.createGame`에 같은 instance를 전달한다.

- [ ] **Step 4: ProjectLoader의 Editor fallback 제거**

`launcher/ProjectLoader.lua`에서 다음 코드를 완전히 삭제한다.

```lua
local StageStore = require("editor.stage.StageStore")
stageStore = StageStore.new()
```

대신 `options.stageRepository`를 assert하고 game constructor options에 동일 객체를 전달한다. `standalone`, `transportFactory`, `eventHandlers` 전달은 유지한다.

- [ ] **Step 5: EditorApp/EditorSession을 Repository 이름으로 전환**

`editor/EditorApp.lua`:

- `StageStore` require 삭제
- session이 주입되지 않았다면 `options.stageRepository` 필수
- default StageStore 생성 삭제
- EditorSession에 `stageRepository` 전달

`editor/EditorSession.lua`:

- constructor assert/field를 `stageRepository`로 변경
- `listStages`, `stageExists`, `load`, `save` 호출 대상만 rename
- 반환 메시지/code와 save 후 markClean/Undo history 동작은 변경하지 않음

`tests/EditorTest.lua`, `tests/EditorSessionTest.lua`, `tests/EditorWorkflowTest.lua`의 fake 이름과 config key를 전부 `stageRepository`로 바꾼다. fake method의 동작은 바꾸지 않는다.

- [ ] **Step 6: Rhythm Dotgeo와 생성기 template 전환**

`projects/rhythm_dotgeo/game/Game.lua`와 `StageSelect.lua`의 constructor/field/error 문구를 `StageRepository`로 바꾼다. Stage 선택 화면의 목록 정렬, 선택, load-on-open, retry 동작은 그대로 유지한다.

`tools/create_project.py`의 generated `Game.lua`는 다음 field를 생성한다.

```lua
stageRepository = options.stageRepository,
```

`tests_python/test_create_project.py`도 이 문자열을 기대한다. 생성기는 Sample 규칙이나 Stage file을 추가하지 않는다.

- [ ] **Step 7: 구 Editor 저장 파일과 중복 테스트 제거**

Task 3의 StageRepository/NativeFileSystem tests가 기존 StageStoreTest의 다음 cases를 모두 포함하는지 대조한다.

- 목록 filtering/sort
- unsafe/reserved ID
- decode/trailing content
- projectId/stageId mismatch
- normalize/object params
- overwrite conflict
- write/replace/rollback/copy fallback
- packaged source write refusal

누락 case가 있으면 새 Core/Launcher test에 먼저 추가한 뒤 다음을 삭제한다.

```text
editor/stage/StageStore.lua
editor/stage/NativeFileSystem.lua
tests/StageStoreTest.lua
```

`tests/TestRunner.lua`의 `tests.StageStoreTest` entry도 삭제한다.

StageStore가 사라진 직후 `editor/stage/StageDocument.lua`의 임시 `validate`와 `isSafeId` adapter도 삭제한다. 최종 StageDocument 공개 surface에는 편집 명령과 snapshot 접근만 남긴다.

- [ ] **Step 8: old ownership 참조 정적 검사**

Run:

```powershell
rg -n 'stageStore|StageStore|editor\.stage\.NativeFileSystem|editor\.stage\.StageStore|StageDocument\.validate|StageDocument\.isSafeId' . -g '!docs/superpowers/specs/**' -g '!docs/superpowers/plans/**'
```

Expected: 검색 결과 없음.

추가 경계 확인:

```powershell
rg -n 'require\("editor\.' launcher projects
```

Expected: `launcher/Launcher.lua`의 `require("editor")` 공개 조립 진입점만 허용되고 `editor.stage.*` 또는 Project 내부 Editor require는 없음.

- [ ] **Step 9: Lua/Python GREEN 확인**

Run:

```powershell
python -m unittest tests_python.test_create_project
love . --test
```

Expected: Python tests 전부 통과. Repository 주입·Editor workflow·Rhythm StageSelect 관련 새 실패가 없고 LÖVE suite 실패는 기존 Metronome 6건만 남는다.

- [ ] **Step 10: Task 5 커밋**

```powershell
git add launcher editor projects/rhythm_dotgeo tools/create_project.py tests_python/test_create_project.py tests
git commit -m "refactor: inject one stage repository"
```

---

### Task 6: 모듈 경계 자동화, 현재 상태 문서와 최종 검증

**Files:**
- Create: `tests/ModuleBoundaryTest.lua`
- Modify: `tests/TestRunner.lua`
- Modify: `AGENTS.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/STAGE_FORMAT.md`
- Modify: `docs/WORKFLOW.md`
- Modify: `docs/PROJECT_NODES_TUTORIAL.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/HANDOFF.md`

**Interfaces:**
- Test-only: module boundary scanner reads Lua sources and rejects forbidden require targets.
- Documentation: describes only code that exists after Tasks 1–5; future Phase 2/3 work remains ROADMAP/HANDOFF next work, not current architecture.

- [ ] **Step 1: 모듈 경계 RED 테스트 작성**

`tests/ModuleBoundaryTest.lua`에서 `love.filesystem.getDirectoryItems`, `getInfo`, `read`로 `core`, `editor`, `launcher`, `projects` 아래 `.lua`를 재귀 수집한다. source에서 double/single quote require call을 Lua 5.1 pattern 두 개로 찾는다.

```lua
for moduleName in source:gmatch('require%s*%(%s*"([^"]+)"%s*%)') do
    inspectRequire(path, moduleName)
end
for moduleName in source:gmatch("require%s*%(%s*'([^']+)'%s*%)") do
    inspectRequire(path, moduleName)
end
```

검사 규칙:

- `core/`: `editor.`, `launcher.`, `projects.` 금지
- `editor/`: `core.` 금지. `require("core")`만 허용
- `projects/`: `core.` 금지, `editor.`, `launcher.` 금지
- `launcher/`: `editor.stage.` 금지

실패 메시지는 source file과 forbidden module을 함께 포함한다.

처음 RED를 확인하기 위해 테스트 등록 직후 임시 production 위반을 만들지 않는다. 대신 scanner helper에 synthetic source table을 주입할 수 있게 만들고, unit case에서 `projects/demo/game/Game.lua -> editor.stage.StageStore`가 거부되는지 먼저 확인한다. 그 뒤 실제 tree 검사 case를 추가한다.

- [ ] **Step 2: boundary scanner GREEN과 실제 tree 확인**

`tests/TestRunner.lua`에 `tests.ModuleBoundaryTest`를 등록한다.

Run: `love . --test`

Expected: synthetic violation은 올바르게 탐지되고 실제 tree는 통과한다. 전체 실패는 기존 Metronome 6건만 남는다.

- [ ] **Step 3: ARCHITECTURE를 구현된 현재 상태로 갱신**

`docs/ARCHITECTURE.md`에 다음만 현재형으로 기록한다.

- Core.StageSchema/StageRepository/ProjectManifest 책임과 공개 signature
- Launcher가 NativeFileSystem, STAGE_PATHS, dkjson으로 Repository 하나를 조립하는 흐름
- Editor StageDocument의 편집 snapshot/dirty/mutation 책임
- Project가 Repository를 주입받고 Core 공개 API만 소비하는 경계
- Project Event `categoryId + eventId`와 Category Host dispatch
- Core.UI는 style-independent behavior, Editor/Project는 style/layout/render라는 기존 UI 경계
- API version 2의 의미

StageRuntime 이중 소유 제거와 동적 Launcher 메뉴를 “현재 구현”처럼 쓰지 않는다.

- [ ] **Step 4: Stage/제작 문서와 tutorial 갱신**

`docs/STAGE_FORMAT.md`:

- `schemaVersion: 3`
- v2 자동 migration 없음
- projectEvent 예시에 `categoryId`
- Category ID Project 범위 고유, Event ID Category 범위 고유
- sparse `editorSettings`, params object와 error contract

`docs/WORKFLOW.md`:

- Launcher 조립 Repository를 Editor와 Project가 공유
- 새 Project 생성기는 `stageRepository` option을 받는 Game을 생성
- Project는 JSON decode/검증/경로 계산을 직접 하지 않음

`docs/PROJECT_NODES_TUTORIAL.md`:

- Definition의 Category ID와 Event ID 관계
- v3 Event JSON/Editor 내부 timeline type 예시
- 새 Category/Event 추가 시 기존 Game 진입 모듈을 수정하지 않는 흐름 유지

- [ ] **Step 5: AGENTS/ROADMAP/HANDOFF를 운영 규칙에 맞게 갱신**

`AGENTS.md`는 짧고 강제 가능한 규칙만 보강한다.

- Stage 형식은 `Core.StageSchema`
- Stage I/O 절차는 `Core.StageRepository`
- Project manifest는 `Core.ProjectManifest`
- Launcher가 하나의 Repository를 조립·주입
- projectEvent는 `categoryId + eventId`

상세 API 설명은 ARCHITECTURE로 링크하고 AGENTS에 중복 복사하지 않는다.

`docs/ROADMAP.md`는 이 Phase 1을 완료로 표시하고 다음 구조 작업을 다음처럼 분리한다.

1. Phase 2: Editor/Project StageRuntime 단일 실행 권위
2. Phase 3: Launcher 동적 Project 메뉴와 EditorApp/EditorSession 책임 분리
3. Later: Project별 실제 packaging

`docs/HANDOFF.md`는 append-only history를 만들지 말고 다음 네 구역만 남긴다.

- 현재 구현 상태
- 알려진 Metronome 6건 실패와 원인 한 줄
- 이번 작업의 최신 검증 명령/결과
- 다음 작업: Phase 2 runtime ownership

- [ ] **Step 6: stale 용어와 schemaVersion 전수 검사**

Run:

```powershell
rg -n 'stageStore|StageStore|schemaVersion 2|schemaVersion = 2|"schemaVersion"\s*:\s*2|project:<eventId>|ProjectEvents\.validate' README.md AGENTS.md docs core editor launcher projects tests tools tests_python -g '!docs/superpowers/**'
```

Expected: 역사 기록인 `docs/superpowers/specs/**`, `docs/superpowers/plans/**`를 제외한 현재 문서·코드에는 stale 소유권 용어가 없다. 과거 설계 기록은 당시 결정을 보존하므로 기계적으로 수정하지 않는다.

- [ ] **Step 7: 최종 자동 검증**

Run:

```powershell
python -m unittest tests_python.test_create_project
Get-Content -Raw projects/sample/stages/test.json | ConvertFrom-Json | Out-Null
Get-Content -Raw projects/rhythm_dotgeo/stages/speaki_song.json | ConvertFrom-Json | Out-Null
love . --test
git diff --check
git status --short
```

Expected:

- Python generator tests: PASS
- 두 Stage JSON: parse 성공
- LÖVE suite: 구조 변경 관련 실패 0, 기존 Metronome 6건만 실패
- `git diff --check`: 출력 없음
- status: 의도한 문서와 test file만 미커밋 상태

- [ ] **Step 8: Editor GUI 수동 회귀 확인**

Run: `love .`

다음 기존 사용 흐름을 직접 확인한다.

1. `E`로 Editor 열기
2. Sample `test` Stage Open
3. 기존 Category/Event/Property 표시 순서 확인
4. Project Event 하나 배치, drag, property 변경, Undo/Redo, clipboard 수행
5. Save As에서 기존 ID overwrite 확인 Dialog 동작 확인
6. Play/Pause와 preview 확인
7. Launcher로 돌아와 `2`로 Rhythm Dotgeo, Stage 선택과 실행 확인

화면 배치나 조작 흐름이 달라졌다면 문서에 “의도된 변경”으로 적지 말고 이 Task 안에서 회귀를 고친다.

- [ ] **Step 9: 최종 문서 커밋**

`docs/HANDOFF.md`에 실제로 실행한 명령과 정확한 pass/fail 수를 마지막으로 기록한다.

```powershell
git add AGENTS.md docs tests/ModuleBoundaryTest.lua tests/TestRunner.lua
git commit -m "docs: codify core stage boundaries"
```

- [ ] **Step 10: 최종 커밋 범위 확인**

Run:

```powershell
git status --short
git log --oneline -6
```

Expected: worktree clean. 이번 계획의 커밋들만 표시되고 Metronome production/test 변경은 없음.

---

## Completion Criteria

- `Core.StageSchema`, `Core.StageRepository`, `Core.ProjectManifest`가 `require("core")`에서 공개된다.
- StageDocument/Launcher/ProjectCatalog에 Stage schema 또는 manifest 검증 중복이 없다.
- Launcher와 Project가 `editor.stage.*`를 require하지 않는다.
- Editor와 Rhythm Dotgeo Project가 Launcher가 만든 같은 StageRepository 인스턴스를 사용한다.
- 저장소의 두 Stage JSON과 관련 fixture가 schemaVersion 3이다.
- 모든 projectEvent가 `categoryId + eventId`를 가지며 서로 다른 Category에서 같은 Event ID를 사용할 수 있다.
- `Core.CORE_API_VERSION`, Sample/Rhythm manifest가 2다.
- Editor GUI 사용 흐름이 유지된다.
- Python tests와 관련 Lua tests가 통과하고 전체 suite에는 기존 Metronome 6건 외의 실패가 없다.
- ARCHITECTURE/STAGE_FORMAT/WORKFLOW/tutorial/ROADMAP/HANDOFF가 구현된 현재 코드와 일치한다.
- forbidden require를 ModuleBoundaryTest가 자동으로 막는다.
