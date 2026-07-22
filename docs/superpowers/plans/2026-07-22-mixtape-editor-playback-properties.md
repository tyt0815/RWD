# Mixtape and Editor Playback Properties Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stage JSON 버전 2, 공통 Core 음악 Transport, Editor 전용 메트로놈·Playback Rate·Scale과 일반화된 Properties/Values 편집을 구현한다.

**Architecture:** Core의 `TempoMap`, `MusicPlayback`, `PlaybackTransport`가 실제 게임과 Editor가 공유할 시간·음악 규칙을 소유한다. Editor는 Stage의 희소 설정을 해석하고 Core Transport에 전달하며, TestPlayer·MetronomePlayback·속성 UI·타임라인 Scale을 조립한다. BPM Change 노드는 이번 범위에서 만들지 않지만 최상위 `bpm`을 런타임 TempoMap으로 바꾸는 경계를 둔다.

**Tech Stack:** LÖVE2D 11.5, LuaJIT/Lua 5.1, dkjson 2.10, 프로젝트 내장 테스트 러너

## Global Constraints

- 기준 커밋은 `0013d2e`이며 시작 시 `C:\Program Files\LOVE\lovec.exe . --test`가 `PASS: 94 tests`여야 한다.
- LÖVE2D 11.5와 LuaJIT/Lua 5.1 호환 문법만 사용한다.
- 클래스 역할 테이블과 파일명은 PascalCase, 변수와 함수는 camelCase, 상수는 UPPER_SNAKE_CASE를 사용한다.
- 들여쓰기는 공백 4칸이며 한 파일은 한 가지 책임만 가진다.
- `editor/`는 `require("core")` 공개 진입점만 사용하며 Core 내부 모듈 경로를 직접 require하지 않는다.
- Core는 Project 경로와 Editor 설정을 알지 않는다. Editor가 Project 상대 Music 경로를 실제 경로로 해석해 Core에 전달한다.
- Stage는 `schemaVersion: 2`, 최상위 `bpm`, 선택적 `mixtape`, 선택적 `editorSettings`, `events`를 사용한다. 버전 1과 `tempoMap`은 호환하지 않는다.
- Music은 Project의 `assets/audio/` 아래 `.ogg`, `.mp3`, `.wav` 상대 경로만 허용한다.
- 기본값은 Volume `1.0`, Beat 0 Offset `0.0`, Metronome `false`, Metronome Period `4`, Scale `1.0`, Playback Rate `1.0`이다.
- 범위는 Volume `0.0~1.0`, Metronome Period 정수 `1~32`, Scale `0.25~8.0`, Playback Rate `0.25~4.0`이다.
- 기본값과 같은 선택 속성 및 비어 있는 부모 객체는 Stage JSON에 저장하지 않는다.
- schemaVersion 2의 기본값은 버전 계약으로 고정하며 기본값 변경은 새 schemaVersion에서만 한다.
- Playback Rate, Metronome과 Scale은 Editor 전용이다. 실제 게임용 Core Transport의 기본 재생 배율은 항상 `1.0`이다.
- 사용자 소유 `.references/` 파일은 수정하거나 삭제하지 않는다.
- 각 기능은 실패 테스트를 먼저 추가하고 `C:\Program Files\LOVE\lovec.exe . --test`로 전체 회귀를 확인한다.
- 설계 기준 문서는 `docs/superpowers/specs/2026-07-22-mixtape-editor-playback-properties-design.md`다.

---

## File Structure

### 새 파일

- `core/MixtapeSettings.lua`: 공통 Mixtape 기본값, 검증, 해결과 희소화
- `core/TempoMap.lua`: beat와 논리 초 사이의 순수 변환
- `core/MusicPlayback.lua`: 주입 가능한 LÖVE Source 래퍼
- `core/PlaybackTransport.lua`: 논리 시간, beat와 음악 동기화
- `editor/stage/EditorSettings.lua`: Editor 전용 설정 기본값, 검증, 해결과 희소화
- `editor/playback/MetronomePlayback.lua`: 한 beat 루프형 내장 강박·일반박 음원
- `editor/properties/PropertyCatalog.lua`: Events와 속성 표시 순서·종류 정의
- `editor/project/MusicCatalog.lua`: Project 오디오 파일 재귀 검색
- `projects/sample/assets/audio/README.md`: Project 음악 배치 규칙
- `tests/MixtapeSettingsTest.lua`
- `tests/EditorSettingsTest.lua`
- `tests/TempoMapTest.lua`
- `tests/MusicPlaybackTest.lua`
- `tests/PlaybackTransportTest.lua`
- `tests/MetronomePlaybackTest.lua`
- `tests/MusicCatalogTest.lua`

### 주요 수정 파일

- `core/init.lua`: 새 Core 공개 API export
- `editor/stage/StageDocument.lua`: 버전 2, 희소 설정과 일반 속성 변경
- `editor/stage/StageStore.lua`: 버전 2 JSON key 순서
- `editor/EditorSession.lua`: Transport, Metronome, TestPlayer 조립
- `editor/EditorApp.lua`: Event 선택, 일반 인라인 편집, Music 모달, wheel 입력
- `editor/ui/EditorLayout.lua`: 동적 속성 행과 Scale 기반 타임라인
- `editor/ui/EditorDialog.lua`: Music 선택 모달
- `editor/playback/TestPlayer.lua`: 기존 deltaTime 계약 유지
- `main.lua`, `launcher/Launcher.lua`: wheel 입력 전달
- `projects/sample/stages/*.json`: 버전 2 변환
- `tests/TestRunner.lua`와 기존 Stage·Editor·Launcher 테스트
- `README.md`, `docs/ARCHITECTURE.md`, `docs/STAGE_FORMAT.md`, `docs/WORKFLOW.md`, `docs/ROADMAP.md`, `docs/HANDOFF.md`

---

### Task 1: 공통 Mixtape 설정과 Editor 설정 값 객체

**Files:**
- Create: `core/MixtapeSettings.lua`
- Create: `editor/stage/EditorSettings.lua`
- Modify: `core/init.lua`
- Create: `tests/MixtapeSettingsTest.lua`
- Create: `tests/EditorSettingsTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Produces: `Core.MixtapeSettings.validate(value) -> errorMessage|nil`
- Produces: `Core.MixtapeSettings.resolve(value) -> resolvedTable`
- Produces: `Core.MixtapeSettings.compact(value) -> sparseTable|nil`
- Produces: `EditorSettings.validate(value)`, `resolve(value)`, `compact(value)` with the same return rules

- [ ] **Step 1: MixtapeSettings 실패 테스트 작성**

`tests/MixtapeSettingsTest.lua`에 네 테스트를 작성한다.

```lua
return {
    {
        name = "MixtapeSettings는 누락 값을 기본값으로 해석한다",
        run = function(test)
            local settings = require("core").MixtapeSettings.resolve(nil)
            test.assertEqual(settings.music, nil)
            test.assertEqual(settings.volume, 1)
            test.assertEqual(settings.beat0Offset, 0)
        end,
    },
    {
        name = "MixtapeSettings는 기본값을 희소 객체에서 제거한다",
        run = function(test)
            local MixtapeSettings = require("core").MixtapeSettings
            test.assertEqual(MixtapeSettings.compact({ volume = 1, beat0Offset = 0 }), nil)
            local compact = MixtapeSettings.compact({
                music = "assets/audio/song.ogg",
                volume = 0.8,
                beat0Offset = -0.5,
            })
            test.assertEqual(compact.music, "assets/audio/song.ogg")
            test.assertEqual(compact.volume, 0.8)
            test.assertEqual(compact.beat0Offset, -0.5)
        end,
    },
    {
        name = "MixtapeSettings는 안전한 지원 Music 경로만 허용한다",
        run = function(test)
            local validate = require("core").MixtapeSettings.validate
            test.assertEqual(validate({ music = "assets/audio/song.ogg" }), nil)
            test.assertEqual(validate({ music = "assets/audio/sub/song.MP3" }), nil)
            test.assertContains(validate({ music = "../song.wav" }), "music")
            test.assertContains(validate({ music = "assets\\audio\\song.wav" }), "music")
            test.assertContains(validate({ music = "assets/audio/song.flac" }), "music")
        end,
    },
    {
        name = "MixtapeSettings는 Volume과 Offset 종류와 범위를 검증한다",
        run = function(test)
            local validate = require("core").MixtapeSettings.validate
            test.assertContains(validate({ volume = -0.01 }), "volume")
            test.assertContains(validate({ volume = 1.01 }), "volume")
            test.assertContains(validate({ beat0Offset = 0 / 0 }), "beat0Offset")
            test.assertEqual(validate({ volume = 0, beat0Offset = -10 }), nil)
        end,
    },
}
```

`tests/TestRunner.lua`에서 `tests.PlaybackClockTest` 앞에 `tests.MixtapeSettingsTest`를 등록한다.

- [ ] **Step 2: 테스트를 실행해 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `module 'core.MixtapeSettings' not found` 또는 `MixtapeSettings` nil로 실패한다.

- [ ] **Step 3: MixtapeSettings 최소 구현**

`core/MixtapeSettings.lua`를 다음 공개 동작으로 구현한다.

```lua
local MixtapeSettings = {}

local DEFAULTS = {
    volume = 1,
    beat0Offset = 0,
}

local ALLOWED_KEYS = {
    music = true,
    volume = true,
    beat0Offset = true,
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

local function isMusicPath(value)
    if type(value) ~= "string" or value == "" or value:find("\\", 1, true) then
        return false
    end
    if not value:match("^assets/audio/") or value:match("^/") or value:match("^%a:/") then
        return false
    end
    for segment in value:gmatch("[^/]+") do
        if segment == ".." or segment == "." then return false end
    end
    local extension = value:match("%.([^./]+)$")
    extension = extension and extension:lower() or nil
    return extension == "ogg" or extension == "mp3" or extension == "wav"
end

function MixtapeSettings.validate(value)
    if value == nil then return nil end
    if type(value) ~= "table" then return "$.mixtape must be an object." end
    for key in pairs(value) do
        if not ALLOWED_KEYS[key] then return "$.mixtape contains an unknown field: " .. tostring(key) end
    end
    if value.music ~= nil and not isMusicPath(value.music) then
        return "$.mixtape.music must be a supported assets/audio relative path."
    end
    if value.volume ~= nil
        and (not isFiniteNumber(value.volume) or value.volume < 0 or value.volume > 1) then
        return "$.mixtape.volume must be between 0 and 1."
    end
    if value.beat0Offset ~= nil and not isFiniteNumber(value.beat0Offset) then
        return "$.mixtape.beat0Offset must be a finite number."
    end
    return nil
end

function MixtapeSettings.resolve(value)
    value = value or {}
    return {
        music = value.music,
        volume = value.volume == nil and DEFAULTS.volume or value.volume,
        beat0Offset = value.beat0Offset == nil and DEFAULTS.beat0Offset or value.beat0Offset,
    }
end

function MixtapeSettings.compact(value)
    local resolved = MixtapeSettings.resolve(value)
    local compact = {}
    if resolved.music ~= nil then compact.music = resolved.music end
    if resolved.volume ~= DEFAULTS.volume then compact.volume = resolved.volume end
    if resolved.beat0Offset ~= DEFAULTS.beat0Offset then
        compact.beat0Offset = resolved.beat0Offset
    end
    return next(compact) and compact or nil
end

return MixtapeSettings
```

`core/init.lua`에 다음 export를 추가한다.

```lua
Core.MixtapeSettings = require("core.MixtapeSettings")
```

- [ ] **Step 4: EditorSettings 실패 테스트 작성**

`tests/EditorSettingsTest.lua`에 기본값, 희소화, 범위 검증 세 테스트를 작성한다. 검증 입력에는 `metronome = "true"`, Period `0`, `33`, `1.5`, Scale `0.24`, `8.01`, Playback Rate `0.24`, `4.01`을 포함하고 모두 오류 문자열의 필드명을 확인한다. 유효 입력 `{ metronome = true, metronomePeriod = 5, scale = 2, playbackRate = 0.5 }`는 오류가 없어야 한다.

```lua
return {
    {
        name = "EditorSettings는 누락 값을 기본값으로 해석한다",
        run = function(test)
            local settings = require("editor.stage.EditorSettings").resolve(nil)
            test.assertEqual(settings.metronome, false)
            test.assertEqual(settings.metronomePeriod, 4)
            test.assertEqual(settings.scale, 1)
            test.assertEqual(settings.playbackRate, 1)
        end,
    },
    {
        name = "EditorSettings는 기본값을 희소 객체에서 제거한다",
        run = function(test)
            local compact = require("editor.stage.EditorSettings").compact({
                metronome = true,
                metronomePeriod = 4,
                scale = 2,
                playbackRate = 1,
            })
            test.assertEqual(compact.metronome, true)
            test.assertEqual(compact.metronomePeriod, nil)
            test.assertEqual(compact.scale, 2)
            test.assertEqual(compact.playbackRate, nil)
        end,
    },
    {
        name = "EditorSettings는 종류와 범위를 검증한다",
        run = function(test)
            local validate = require("editor.stage.EditorSettings").validate
            test.assertContains(validate({ metronome = "true" }), "metronome")
            test.assertContains(validate({ metronomePeriod = 0 }), "metronomePeriod")
            test.assertContains(validate({ metronomePeriod = 33 }), "metronomePeriod")
            test.assertContains(validate({ metronomePeriod = 1.5 }), "metronomePeriod")
            test.assertContains(validate({ scale = 0.24 }), "scale")
            test.assertContains(validate({ scale = 8.01 }), "scale")
            test.assertContains(validate({ playbackRate = 0.24 }), "playbackRate")
            test.assertContains(validate({ playbackRate = 4.01 }), "playbackRate")
            test.assertEqual(validate({
                metronome = true,
                metronomePeriod = 5,
                scale = 2,
                playbackRate = 0.5,
            }), nil)
        end,
    },
}
```

- [ ] **Step 5: EditorSettings 구현**

`editor/stage/EditorSettings.lua`는 다음과 같이 구현한다.

```lua
local EditorSettings = {}

local DEFAULTS = {
    metronome = false,
    metronomePeriod = 4,
    scale = 1,
    playbackRate = 1,
}

local ALLOWED_KEYS = {
    metronome = true,
    metronomePeriod = true,
    scale = true,
    playbackRate = true,
}

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value < math.huge
        and value > -math.huge
end

function EditorSettings.validate(value)
    if value == nil then return nil end
    if type(value) ~= "table" then return "$.editorSettings must be an object." end
    for key in pairs(value) do
        if not ALLOWED_KEYS[key] then
            return "$.editorSettings contains an unknown field: " .. tostring(key)
        end
    end
    if value.metronome ~= nil and type(value.metronome) ~= "boolean" then
        return "$.editorSettings.metronome must be a boolean."
    end
    if value.metronomePeriod ~= nil
        and (not isFiniteNumber(value.metronomePeriod)
            or value.metronomePeriod % 1 ~= 0
            or value.metronomePeriod < 1
            or value.metronomePeriod > 32) then
        return "$.editorSettings.metronomePeriod must be an integer between 1 and 32."
    end
    if value.scale ~= nil
        and (not isFiniteNumber(value.scale) or value.scale < 0.25 or value.scale > 8) then
        return "$.editorSettings.scale must be between 0.25 and 8."
    end
    if value.playbackRate ~= nil
        and (not isFiniteNumber(value.playbackRate)
            or value.playbackRate < 0.25
            or value.playbackRate > 4) then
        return "$.editorSettings.playbackRate must be between 0.25 and 4."
    end
    return nil
end

function EditorSettings.resolve(value)
    value = value or {}
    return {
        metronome = value.metronome == nil and DEFAULTS.metronome or value.metronome,
        metronomePeriod = value.metronomePeriod or DEFAULTS.metronomePeriod,
        scale = value.scale or DEFAULTS.scale,
        playbackRate = value.playbackRate or DEFAULTS.playbackRate,
    }
end

function EditorSettings.compact(value)
    local resolved = EditorSettings.resolve(value)
    local compact = {}
    for key, defaultValue in pairs(DEFAULTS) do
        if resolved[key] ~= defaultValue then compact[key] = resolved[key] end
    end
    return next(compact) and compact or nil
end

return EditorSettings
```

- [ ] **Step 6: 전체 테스트 통과 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:` 출력. 기존 94개와 새 설정 테스트가 모두 통과한다.

- [ ] **Step 7: 커밋**

```powershell
git add core/MixtapeSettings.lua core/init.lua editor/stage/EditorSettings.lua tests/MixtapeSettingsTest.lua tests/EditorSettingsTest.lua tests/TestRunner.lua
git commit -m "feat: add stage playback settings"
```

---

### Task 2: Stage JSON schemaVersion 2와 희소 저장

**Files:**
- Modify: `editor/stage/StageDocument.lua`
- Modify: `editor/stage/StageStore.lua`
- Modify: `projects/sample/stages/tutorial.json`
- Modify: `projects/sample/stages/test_stage.json`
- Modify: `tests/StageDocumentTest.lua`
- Modify: `tests/StageStoreTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`

**Interfaces:**
- Consumes: `Core.MixtapeSettings` and `EditorSettings`
- Produces: `StageDocument:getMixtape() -> resolvedTable`
- Produces: `StageDocument:getEditorSettings() -> resolvedTable`
- Produces: `StageDocument:setMixtapeValue(key, value) -> true|nil, errorMessage`
- Produces: `StageDocument:setEditorSetting(key, value) -> true|nil, errorMessage`
- Keeps: `getBpm()` and `setBpm(bpm)` with top-level `bpm`

- [ ] **Step 1: 기존 Stage fixture를 버전 2 기대값으로 바꾸고 실패 테스트 추가**

모든 테스트 Stage table의 다음 구조를 교체한다.

```lua
schemaVersion = 2,
bpm = 120,
events = {},
```

`tempoMap`은 제거한다. `tests/StageDocumentTest.lua`에 다음 동작을 각각 독립 테스트로 추가한다.

```lua
local minimum = {
    schemaVersion = 2,
    projectId = "sample",
    stageId = "stage-one",
    name = "Stage One",
    bpm = 120,
    events = {},
}
```

- 최소 Stage의 해결된 Mixtape와 Editor 기본값
- 버전 1 거부
- schemaVersion 2에 남은 `tempoMap` 거부
- 선택 객체가 배열 또는 문자열일 때 거부
- `setMixtapeValue`와 `setEditorSetting`이 non-default 값을 저장하고 dirty 처리
- 기본값으로 복귀하면 필드와 빈 부모 객체 제거
- 같은 해결 값 설정은 새 dirty를 만들지 않음

핵심 accessor와 희소 저장 테스트는 다음 assertion을 그대로 포함한다.

```lua
local document = assert(StageDocument.fromTable(minimum))
test.assertEqual(document:getMixtape().volume, 1)
test.assertEqual(document:getMixtape().beat0Offset, 0)
test.assertEqual(document:getEditorSettings().metronomePeriod, 4)
assert(document:setMixtapeValue("volume", 0.8))
assert(document:setEditorSetting("scale", 2))
local changed = document:toTable()
test.assertEqual(changed.mixtape.volume, 0.8)
test.assertEqual(changed.editorSettings.scale, 2)
test.assertEqual(document:isDirty(), true)
assert(document:setMixtapeValue("volume", 1))
assert(document:setEditorSetting("scale", 1))
local reverted = document:toTable()
test.assertEqual(reverted.mixtape, nil)
test.assertEqual(reverted.editorSettings, nil)
```

버전 거부 테스트는 `schemaVersion = 1`에서 `$.schemaVersion must be 2.`를, 버전 2 table에 `tempoMap = {}`를 추가했을 때 `$.tempoMap is not supported`를 확인한다.

- [ ] **Step 2: 테스트 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `$.schemaVersion must be 1.`, 누락된 `getMixtape` 또는 `tempoMap` 기대 불일치로 실패한다.

- [ ] **Step 3: StageDocument 검증과 생성 형식 교체**

`StageDocument.lua`는 `local Core = require("core")`와 `local EditorSettings = require("editor.stage.EditorSettings")`를 사용한다. `validate`의 tempoMap 블록을 다음 규칙으로 교체한다.

```lua
if data.schemaVersion ~= 2 then
    return "$.schemaVersion must be 2."
end
if data.tempoMap ~= nil then
    return "$.tempoMap is not supported in schemaVersion 2."
end
if not isFiniteNumber(data.bpm) or data.bpm <= 0 then
    return "$.bpm must be a positive finite number."
end
if data.mixtape ~= nil and not isObject(data.mixtape) then
    return "$.mixtape must be an object."
end
local mixtapeError = Core.MixtapeSettings.validate(data.mixtape)
if mixtapeError then return mixtapeError end
if data.editorSettings ~= nil and not isObject(data.editorSettings) then
    return "$.editorSettings must be an object."
end
local editorError = EditorSettings.validate(data.editorSettings)
if editorError then return editorError end
```

`StageDocument.create`는 다음 필수 필드만 만든다.

```lua
{
    schemaVersion = 2,
    projectId = projectId,
    stageId = stageId,
    name = name,
    bpm = bpm,
    events = {},
}
```

- [ ] **Step 4: 해결 accessor와 희소 setter 구현**

다음 메서드를 추가한다.

```lua
function StageDocument:getBpm()
    return self.data.bpm
end

function StageDocument:getMixtape()
    return Core.MixtapeSettings.resolve(self.data.mixtape)
end

function StageDocument:getEditorSettings()
    return EditorSettings.resolve(self.data.editorSettings)
end
```

내부 helper는 기존 해결 값과 새 해결 값을 비교한 뒤 module의 `validate`와 `compact`를 사용한다. `value == nil`은 Music 제거에 사용하므로 setter가 nil을 정상 입력으로 받아야 한다.

```lua
local function setSparseValue(document, sectionName, key, value, settingsModule)
    local current = settingsModule.resolve(document.data[sectionName])
    local candidate = {}
    for name, item in pairs(current) do candidate[name] = item end
    candidate[key] = value
    local validationError = settingsModule.validate(candidate)
    if validationError then return nil, validationError end
    local resolved = settingsModule.resolve(candidate)
    if current[key] ~= resolved[key] then
        document.data[sectionName] = settingsModule.compact(resolved)
        document.dirty = true
    end
    return true, nil
end
```

`setMixtapeValue`와 `setEditorSetting`은 각각 Core.MixtapeSettings와 EditorSettings를 전달한다. `setBpm`은 `self.data.bpm`을 직접 검증·갱신한다.

`newDocument`가 deep copy를 만든 직후 두 선택 객체를 compact해, 입력 JSON에 기본값이 명시되어 있어도 `toTable()`은 항상 희소 형식을 반환하게 한다.

```lua
local documentData = deepCopy(data)
documentData.mixtape = Core.MixtapeSettings.compact(documentData.mixtape)
documentData.editorSettings = EditorSettings.compact(documentData.editorSettings)
normalizeEmptyPatternParams(documentData)
```

- [ ] **Step 5: StageStore key 순서와 Sample JSON 변경**

`JSON_KEY_ORDER`를 다음 순서로 바꾼다.

```lua
local JSON_KEY_ORDER = {
    "schemaVersion", "projectId", "stageId", "name", "bpm",
    "mixtape", "editorSettings", "events",
    "music", "volume", "beat0Offset",
    "metronome", "metronomePeriod", "scale", "playbackRate",
    "id", "startBeat", "type", "patternId", "params", "durationBeats",
}
```

두 Sample Stage JSON을 schemaVersion 2, 최상위 bpm과 빈 events 형식으로 변환한다.

- [ ] **Step 6: 전체 테스트와 JSON 문법 확인**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
Get-ChildItem projects -Recurse -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
}
```

Expected: 테스트 exit code 0, `PASS:` 출력, ConvertFrom-Json 오류 없음.

- [ ] **Step 7: 커밋**

```powershell
git add editor/stage/StageDocument.lua editor/stage/StageStore.lua projects/sample/stages tests/StageDocumentTest.lua tests/StageStoreTest.lua tests/EditorSessionTest.lua tests/EditorWorkflowTest.lua
git commit -m "feat: migrate stages to schema version 2"
```

---

### Task 3: Core TempoMap

**Files:**
- Create: `core/TempoMap.lua`
- Modify: `core/init.lua`
- Create: `tests/TempoMapTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Produces: `Core.TempoMap.new(bpm) -> tempoMap|nil, errorMessage`
- Produces: `TempoMap:beatToSeconds(beat) -> seconds|nil, errorMessage`
- Produces: `TempoMap:secondsToBeat(seconds) -> beat|nil, errorMessage`
- Produces: `TempoMap:getBpm() -> number`

- [ ] **Step 1: 실패 테스트 작성**

`tests/TempoMapTest.lua`에 다음 네 경우를 작성하고 TestRunner에 등록한다.

```lua
return {
    {
        name = "TempoMap은 beat와 seconds를 왕복 변환한다",
        run = function(test)
            local map = assert(require("core").TempoMap.new(120))
            test.assertNear(map:beatToSeconds(4), 2, 0.000001)
            test.assertNear(map:secondsToBeat(2), 4, 0.000001)
            test.assertEqual(map:getBpm(), 120)
        end,
    },
    {
        name = "TempoMap은 소수 beat와 seconds를 변환한다",
        run = function(test)
            local map = assert(require("core").TempoMap.new(90))
            test.assertNear(map:beatToSeconds(1.5), 1, 0.000001)
            test.assertNear(map:secondsToBeat(1), 1.5, 0.000001)
        end,
    },
    {
        name = "TempoMap은 잘못된 BPM을 거부한다",
        run = function(test)
            local map, errorMessage = require("core").TempoMap.new(0)
            test.assertEqual(map, nil)
            test.assertContains(errorMessage, "BPM")
        end,
    },
    {
        name = "TempoMap은 음수와 비유한 위치를 거부한다",
        run = function(test)
            local map = assert(require("core").TempoMap.new(120))
            test.assertEqual(map:beatToSeconds(-1), nil)
            test.assertEqual(map:secondsToBeat(0 / 0), nil)
        end,
    },
}
```

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `module 'core.TempoMap' not found` 또는 TempoMap nil로 실패한다.

- [ ] **Step 3: TempoMap 구현**

`core/TempoMap.lua`는 유한한 양수 BPM과 음수가 아닌 위치를 검증하고 단일 BPM 수식을 사용한다.

```lua
function TempoMap:beatToSeconds(beat)
    if not isNonNegativeFinite(beat) then
        return nil, "Beat must be a non-negative finite number."
    end
    return beat * 60 / self.bpm, nil
end

function TempoMap:secondsToBeat(seconds)
    if not isNonNegativeFinite(seconds) then
        return nil, "Seconds must be a non-negative finite number."
    end
    return seconds * self.bpm / 60, nil
end
```

`core/init.lua`에 `Core.TempoMap = require("core.TempoMap")`를 추가한다.

- [ ] **Step 4: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add core/TempoMap.lua core/init.lua tests/TempoMapTest.lua tests/TestRunner.lua
git commit -m "feat: add core tempo map"
```

---

### Task 4: Core MusicPlayback Source 래퍼

**Files:**
- Create: `core/MusicPlayback.lua`
- Modify: `core/init.lua`
- Create: `tests/MusicPlaybackTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Produces: `Core.MusicPlayback.new(options) -> musicPlayback`
- Produces: `prepare(path, volume)`, `play(positionSeconds, playbackRate)`, `update(expectedSeconds, playbackRate, deltaTime)`, `pause()`, `stop()`
- `options.sourceFactory(path, sourceType) -> LÖVE Source`; production default uses `love.audio.newSource`
- `prepare(nil, volume)` is a successful no-music state

- [ ] **Step 1: 가짜 Source와 실패 테스트 작성**

`tests/MusicPlaybackTest.lua`의 fixture Source는 `seek`, `play`, `pause`, `stop`, `tell`, `getDuration`, `setVolume`, `setPitch` 호출을 상태 테이블에 기록한다. 다음 여섯 테스트를 만든다.

- nil Music은 Source를 만들지 않고 모든 동작이 성공
- prepare는 `sourceFactory(path, "stream")`, Volume과 duration을 사용
- play는 seek 후 pitch를 설정하고 재생
- 기대 위치가 duration 이상이면 음악만 stop
- 1초 누적 검사에서 drift가 0.05초를 초과할 때만 seek
- Source factory 또는 Source 메서드 예외를 오류 문자열로 반환하고 stop 상태 유지

fixture는 다음 최소 Source 계약을 사용한다.

```lua
local function newSource(state)
    return {
        getDuration = function() return state.duration or 10 end,
        setVolume = function(_, value) state.volume = value end,
        setPitch = function(_, value) state.pitch = value end,
        seek = function(_, value) state.position = value; state.seekCount = state.seekCount + 1 end,
        tell = function() return state.position or 0 end,
        play = function() state.playing = true end,
        pause = function() state.playing = false end,
        stop = function() state.playing = false; state.stopped = true end,
    }
end
```

seek·pitch·volume 순서 테스트는 `prepare("projects/sample/assets/audio/a.wav", 0.8)`, `play(2.5, 0.5)` 뒤 position `2.5`, pitch `0.5`, volume `0.8`, playing true를 확인한다. Drift 테스트는 tell 위치를 기대값보다 `0.051` 작게 만든 뒤 update 누적 delta가 `1.0`이 되었을 때 seekCount가 정확히 1 증가하는지 확인한다.

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `module 'core.MusicPlayback' not found`로 실패한다.

- [ ] **Step 3: MusicPlayback 구현**

상수와 생성자 상태는 다음을 사용한다.

```lua
local DRIFT_CHECK_INTERVAL_SECONDS = 1
local MAX_DRIFT_SECONDS = 0.05

function MusicPlayback.new(options)
    options = options or {}
    return setmetatable({
        sourceFactory = options.sourceFactory or function(path, sourceType)
            return love.audio.newSource(path, sourceType)
        end,
        source = nil,
        duration = nil,
        driftElapsed = 0,
        started = false,
    }, MusicPlayback)
end
```

모든 Source 호출은 `pcall`로 감싸고 `Music playback failed: <message>` 형식으로 반환한다. `prepare`는 기존 Source를 stop한 뒤 새 stream Source와 duration을 준비한다. `play`는 `0 <= position < duration`일 때 seek, Volume, pitch, play 순서로 호출한다. `update`는 음악 끝을 처리하고 1초마다 drift를 검사한다. `pause`는 위치를 보존하고, `stop`은 Source 참조와 상태를 모두 해제한다.

- [ ] **Step 4: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add core/MusicPlayback.lua core/init.lua tests/MusicPlaybackTest.lua tests/TestRunner.lua
git commit -m "feat: add core music playback"
```

---

### Task 5: Core PlaybackTransport

**Files:**
- Create: `core/PlaybackTransport.lua`
- Modify: `core/init.lua`
- Create: `tests/PlaybackTransportTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Consumes: `Core.TempoMap`, injected `MusicPlayback`
- Produces: `Core.PlaybackTransport.new(options) -> transport|nil, errorMessage`
- Produces: `configureMixtape(settings, resolvedMusicPath)`, `setBpm(bpm)`, `play(playbackRate)`, `pause()`, `update(deltaTime)`
- Produces: `getBeat()`, `getTimelineSeconds()`, `isPlaying()`, `getPlaybackRate()`

- [ ] **Step 1: Transport 실패 테스트 작성**

`tests/PlaybackTransportTest.lua`에 가짜 MusicPlayback을 주입해 다음 일곱 테스트를 만든다.

- 120 BPM에서 rate 1로 0.5초 update하면 beat 1
- rate 2로 0.5초 update하면 논리 1초와 beat 2
- Offset 0.5는 beat 0 Play에서 music position 0.5로 시작
- Offset -0.5는 처음 무음이고 논리 0.5초를 통과할 때 초과분 위치로 시작
- Pause 후 beat를 보존하고 다음 Play가 대응 음악 위치로 재개
- BPM 변경은 현재 beat를 보존하고 논리 초를 다시 계산
- prepare/play/update 실패는 paused 상태와 오류를 반환

rate와 음수 Offset 테스트는 다음 호출 순서를 사용한다.

```lua
local musicState = { playPositions = {} }
local musicPlayback = {
    prepare = function() return true, nil end,
    play = function(_, position, rate)
        table.insert(musicState.playPositions, { position = position, rate = rate })
        return true, nil
    end,
    update = function() return true, nil end,
    pause = function() musicState.paused = true end,
    stop = function() musicState.stopped = true end,
}
local transport = assert(Core.PlaybackTransport.new({ bpm = 120, musicPlayback = musicPlayback }))
transport:configureMixtape({ volume = 1, beat0Offset = -0.5 }, "song.wav")
assert(transport:play(2))
test.assertEqual(#musicState.playPositions, 0)
assert(transport:update(0.25))
test.assertEqual(#musicState.playPositions, 1)
test.assertNear(musicState.playPositions[1].position, 0, 0.000001)
test.assertEqual(musicState.playPositions[1].rate, 2)
test.assertNear(transport:getBeat(), 1, 0.000001)
```

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `module 'core.PlaybackTransport' not found`로 실패한다.

- [ ] **Step 3: PlaybackTransport 구현**

생성자 입력과 상태를 다음으로 고정한다.

```lua
local transport = Core.PlaybackTransport.new({
    bpm = 120,
    musicPlayback = musicPlayback,
})
```

`configureMixtape(settings, resolvedMusicPath)`는 resolved Music 설정과 Project가 해석한 실제 path를 보존한다. `play(playbackRate)`는 `playbackRate = playbackRate or 1`을 먼저 적용하고 범위를 검증한 뒤 MusicPlayback을 prepare하고 다음 위치를 계산한다.

```lua
local musicSeconds = self.timelineSeconds + self.mixtape.beat0Offset
if musicSeconds >= 0 then
    local started, startError = self.musicPlayback:play(musicSeconds, playbackRate)
    if not started then return nil, startError end
    self.musicStarted = true
end
```

`update`는 `deltaTime * playbackRate`만큼 논리 시간을 증가시킨다. 음수 Offset이 0을 통과하면 현재 초과분으로 music play를 호출한다. 이미 시작한 음악은 `MusicPlayback:update(musicSeconds, rate, deltaTime)`으로 보정한다. 오류 시 `pause()`하고 오류를 반환한다.

`setBpm`은 변경 전 `getBeat()`를 저장하고 새 TempoMap의 `beatToSeconds(savedBeat)`로 논리 시간을 재계산한다. `pause`는 MusicPlayback을 pause하지만 logical seconds와 beat는 유지한다.

`core/init.lua`에 `Core.PlaybackTransport`를 export한다. 기존 PlaybackClock export는 제거하지 않는다.

- [ ] **Step 4: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add core/PlaybackTransport.lua core/init.lua tests/PlaybackTransportTest.lua tests/TestRunner.lua
git commit -m "feat: add core playback transport"
```

---

### Task 6: Editor Metronome과 EditorSession Transport 통합

**Files:**
- Create: `editor/playback/MetronomePlayback.lua`
- Modify: `editor/EditorSession.lua`
- Modify: `editor/playback/TestPlayer.lua`
- Create: `tests/MetronomePlaybackTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/TestPlayerTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Produces: `MetronomePlayback.new(options)` with `play(bpm, period, beat, playbackRate)`, `pause()`, `stop()`
- EditorSession consumes injected `transportFactory`, `metronome`, and existing `testPlayer`
- Produces: `EditorSession:getProperty(groupId, propertyId)` and `setProperty(groupId, propertyId, value)`
- Keeps: TestPlayer `update(deltaTime)`; EditorSession passes scaled delta

- [ ] **Step 1: Metronome 실패 테스트 작성**

가짜 SoundData와 Source factory를 사용해 다음 네 테스트를 작성한다.

- Period 4가 한 beat buffer에 강박 1개와 일반박 3개를 요청
- beat 0 Play가 phase 0을 seek하고 즉시 play
- beat 2.5 재개가 한 beat 루프의 절반 위치를 seek
- Playback Rate가 Source pitch에 적용되고 Pause가 Source를 정지

중간 beat 재개 테스트는 가짜 Source의 seek 값을 직접 검사한다.

```lua
local metronome = MetronomePlayback.new({
    soundDataFactory = soundDataFactory,
    sourceFactory = sourceFactory,
})
assert(metronome:play(120, 4, 2.5, 0.5))
test.assertNear(sourceState.seekPosition, 0.25, 0.000001)
test.assertEqual(sourceState.pitch, 0.5)
test.assertEqual(sourceState.looping, true)
test.assertEqual(sourceState.playing, true)
metronome:pause()
test.assertEqual(sourceState.playing, false)
```

테스트 가능성을 위해 `MetronomePlayback.new` options에 `soundDataFactory(sampleCount, sampleRate)`와 `sourceFactory(soundData, "static")`를 받는다. 테스트용 SoundData는 `setSample` 호출을 기록한다.

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `module 'editor.playback.MetronomePlayback' not found`로 실패한다.

- [ ] **Step 3: MetronomePlayback 구현**

다음 상수를 사용해 한 beat 길이 mono 16-bit SoundData를 생성한다.

```lua
local SAMPLE_RATE = 44100
local CLICK_SECONDS = 0.012
local ACCENT_FREQUENCY = 1760
local NORMAL_FREQUENCY = 880
local AMPLITUDE = 0.35
```

beat duration은 `60 / bpm`, subdivision 시작은 `subdivision * duration / period`다. 첫 subdivision은 ACCENT_FREQUENCY, 나머지는 NORMAL_FREQUENCY를 사용한다. 클릭 sample마다 선형 감쇠 envelope와 `math.sin(2 * math.pi * frequency * time)`을 곱한다. Source는 looping true이며 현재 beat의 소수 부분에 해당하는 초로 seek한 뒤 pitch와 play를 적용한다.

- [ ] **Step 4: EditorSession 실패 테스트 작성**

기존 clock fixture를 가짜 PlaybackTransport로 교체하고 다음 동작을 추가한다.

- replaceStage가 resolved Mixtape와 Project 실제 경로를 Transport에 전달
- Editor Properties와 Mixtape Properties getter/setter가 StageDocument를 호출
- Play가 현재 Playback Rate로 Transport, TestPlayer, 선택적 Metronome을 시작
- update가 Transport에는 원 deltaTime, TestPlayer에는 `deltaTime * playbackRate` 전달
- Transport, TestPlayer 또는 Metronome 시작 실패 시 모두 Pause/stop
- 실제 게임용 기본 Core Transport는 rate 인자를 생략하면 1.0

scaled update 테스트는 다음 값을 고정한다.

```lua
assert(document:setEditorSetting("playbackRate", 0.5))
assert(session:play())
assert(session:update(0.2, 16))
test.assertNear(transportState.lastDeltaTime, 0.2, 0.000001)
test.assertNear(testPlayerState.lastDeltaTime, 0.1, 0.000001)
test.assertEqual(transportState.playbackRate, 0.5)
```

- [ ] **Step 5: EditorSession 통합 구현**

`EditorSession.new`의 `clockFactory`를 `transportFactory`로 교체한다. 기본 factory는 `Core.PlaybackTransport.new`와 production MusicPlayback을 조립한다. Project Music 실제 경로는 다음 helper만 Editor에 둔다.

```lua
local function resolveProjectMusicPath(project, music)
    if not music then return nil end
    return "projects/" .. project.id .. "/" .. music
end
```

`replaceStage`는 새 Transport를 만들고 beat 0 paused 상태로 교체한다. `play`는 Document의 resolved 설정을 읽고 다음 순서로 실행한다.

```lua
self.transport:configureMixtape(mixtape, resolveProjectMusicPath(self.project, mixtape.music))
local gameStarted, gameError = self.testPlayer:start(self.project)
if not gameStarted then return nil, gameError end

local transportStarted, transportError = self.transport:play(editorSettings.playbackRate)
if not transportStarted then
    self:pause()
    return nil, transportError
end

if editorSettings.metronome then
    local metronomeStarted, metronomeError = self.metronome:play(
        self.document:getBpm(),
        editorSettings.metronomePeriod,
        self.transport:getBeat(),
        editorSettings.playbackRate
    )
    if not metronomeStarted then
        self:pause()
        return nil, metronomeError
    end
end

return true, nil
```

`update`는 Transport 성공 후 scaled delta로 TestPlayer를 호출한다. `getBeat`, `isPlaying`, `setBpm`은 Transport로 위임한다.

`getProperty`와 `setProperty` group ID는 정확히 `editorProperties`, `mixtapeProperties`를 사용한다. BPM은 Document의 명시적 메서드, 나머지는 희소 setter로 전달한다.

- [ ] **Step 6: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add editor/playback/MetronomePlayback.lua editor/EditorSession.lua editor/playback/TestPlayer.lua tests/MetronomePlaybackTest.lua tests/EditorSessionTest.lua tests/TestPlayerTest.lua tests/TestRunner.lua
git commit -m "feat: integrate editor playback transport"
```

---

### Task 7: 일반화된 Events와 Properties/Values 인라인 편집

**Files:**
- Create: `editor/properties/PropertyCatalog.lua`
- Modify: `editor/EditorApp.lua`
- Modify: `editor/ui/EditorLayout.lua`
- Modify: `tests/EditorUiTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`

**Interfaces:**
- Produces: `PropertyCatalog.getEvents() -> ordered event definitions`
- Produces: `PropertyCatalog.getEvent(eventId) -> eventDefinition|nil`
- Event IDs: `editorProperties`, `mixtapeProperties`
- Property kinds: `number`, `boolean`, `music`
- EditorApp view model exposes `propertyEvents`, `selectedEventId`, `properties`, `valueEdit`

- [ ] **Step 1: PropertyCatalog과 UI 실패 테스트 작성**

`tests/EditorUiTest.lua`와 `tests/EditorWorkflowTest.lua`에 다음 동작을 고정한다.

- Events 순서가 Editor Properties, Mixtape Properties
- 기본 선택이 Editor Properties
- Editor 속성 순서가 Scale, Playback Rate, Metronome, Metronome Period
- Mixtape 속성 순서가 Music, Volume, Beat 0 Offset, BPM
- Event 행 클릭이 선택만 바꾸고 dirty를 만들지 않음
- boolean 셀 클릭이 즉시 전환
- 음수를 포함한 숫자 인라인 입력과 잘못된 값의 빨간 테두리
- BPM 전용 기존 테스트가 일반 property row hit test로 유지됨

Workflow 테스트는 실제 row rect를 사용해 다음 입력 흐름을 검증한다.

```lua
local eventRect = EditorLayout.getEventRowRect(app.layout, 2)
app:mousepressed(eventRect.x + 8, eventRect.y + 8, 1)
test.assertEqual(app:getViewModel().selectedEventId, "mixtapeProperties")

local offsetRect = EditorLayout.getPropertyValueRect(app.layout, 3)
app:mousepressed(offsetRect.x + 8, offsetRect.y + 8, 1)
app:textinput("-0.5")
app:keypressed("return")
test.assertEqual(app:getSession():getProperty("mixtapeProperties", "beat0Offset"), -0.5)
test.assertEqual(app:getDialog(), nil)
```

boolean 테스트는 Editor Properties의 세 번째 row를 클릭하기 전 false, 클릭 후 true와 dirty를 확인한다. invalid 테스트는 Volume에 `2`를 입력해 편집 상태와 invalid true가 유지되고 Document 값은 1인지 확인한다.

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: `PropertyCatalog` 없음, Events 순서 또는 일반 value edit 필드 없음으로 실패한다.

- [ ] **Step 3: PropertyCatalog 구현**

`editor/properties/PropertyCatalog.lua`의 정의는 다음 순서를 그대로 사용한다.

```lua
local EVENTS = {
    {
        id = "editorProperties",
        label = "Editor Properties",
        properties = {
            { id = "scale", label = "Scale", kind = "number" },
            { id = "playbackRate", label = "Playback Rate", kind = "number" },
            { id = "metronome", label = "Metronome", kind = "boolean" },
            { id = "metronomePeriod", label = "Metronome Period", kind = "number" },
        },
    },
    {
        id = "mixtapeProperties",
        label = "Mixtape Properties",
        properties = {
            { id = "music", label = "Music", kind = "music" },
            { id = "volume", label = "Volume", kind = "number" },
            { id = "beat0Offset", label = "Beat 0 Offset", kind = "number" },
            { id = "bpm", label = "BPM", kind = "number" },
        },
    },
}
```

반환 시 호출자가 정의를 수정하지 않도록 새 배열과 property table을 복사한다.

- [ ] **Step 4: EditorApp의 BPM 전용 edit 상태를 일반화**

`bpmEdit`을 다음 구조의 `valueEdit`으로 교체한다.

```lua
{
    groupId = "mixtapeProperties",
    propertyId = "beat0Offset",
    text = "-0.5",
    replaceOnInput = false,
    invalid = false,
}
```

생성자는 `selectedEventId = "editorProperties"`를 가진다. 숫자 입력은 `0-9`, `.`, `-`만 받아들이되 최종 유효성은 `EditorSession:setProperty`에 맡긴다. Enter와 셀 밖 클릭은 확정, Escape는 취소한다. boolean은 text edit 없이 현재 값의 not을 즉시 설정한다. music kind는 Task 8에서 연결하므로 이 Task에서는 클릭을 소비하고 모달을 열지 않는다.

- [ ] **Step 5: EditorLayout을 동적 행으로 변경**

다음 공개 rect helper를 제공한다.

```lua
EditorLayout.getEventRowRect(layout, rowIndex)
EditorLayout.hitTestEvent(layout, eventCount, x, y)
EditorLayout.getPropertyValueRect(layout, rowIndex)
EditorLayout.hitTestPropertyValue(layout, propertyCount, x, y)
```

Properties와 Values는 선택 Event의 property 배열을 같은 row index로 그린다. 편집 중인 숫자 셀만 기존 어두운 fill, 주황 또는 빨간 outline을 표시한다. Music nil은 `None`, boolean은 `true` 또는 `false`, 숫자는 `tostring`으로 표시한다.

- [ ] **Step 6: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add editor/properties/PropertyCatalog.lua editor/EditorApp.lua editor/ui/EditorLayout.lua tests/EditorUiTest.lua tests/EditorWorkflowTest.lua
git commit -m "feat: add editor property panels"
```

---

### Task 8: Project Music 검색과 선택 모달

**Files:**
- Create: `editor/project/MusicCatalog.lua`
- Create: `projects/sample/assets/audio/README.md`
- Modify: `editor/ui/EditorDialog.lua`
- Modify: `editor/EditorApp.lua`
- Create: `tests/MusicCatalogTest.lua`
- Modify: `tests/EditorDialogTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`
- Modify: `tests/TestRunner.lua`

**Interfaces:**
- Produces: `MusicCatalog.new(options)` and `list(projectId) -> relativePaths, errorMessage`
- Produces: `EditorDialog.music(files, currentMusic) -> dialog`
- Music dialog result: `result.selections.music == ""` means None; otherwise Project-relative path

- [ ] **Step 1: MusicCatalog 실패 테스트 작성**

주입한 `getInfo(path)`와 `listDirectory(path)`로 다음 세 테스트를 만든다.

- audio directory 없음은 빈 목록과 nil 오류
- nested directory의 ogg, mp3, wav만 재귀 수집하고 `assets/audio/...` 경로로 정렬
- directory list 예외는 `Failed to list Project music:` 오류

재귀 검색 테스트의 가짜 tree와 기대값은 다음을 사용한다.

```lua
local MusicCatalog = require("editor.project.MusicCatalog")

local entries = {
    ["projects/sample/assets/audio"] = { "z.wav", "sub", "ignore.txt" },
    ["projects/sample/assets/audio/sub"] = { "a.ogg", "b.MP3" },
}
local directories = { ["projects/sample/assets/audio"] = true, ["projects/sample/assets/audio/sub"] = true }
local catalog = MusicCatalog.new({
    getInfo = function(path)
        if directories[path] then return { type = "directory" } end
        if path:match("%.%w+$") then return { type = "file" } end
        return nil
    end,
    listDirectory = function(path) return entries[path] end,
    validateProjectId = function(id) return id == "sample" end,
})
local files = assert(catalog:list("sample"))
test.assertEqual(table.concat(files, "|"),
    "assets/audio/sub/a.ogg|assets/audio/sub/b.MP3|assets/audio/z.wav")
```

- [ ] **Step 2: MusicCatalog 구현**

production 기본 함수는 `love.filesystem.getInfo`와 `love.filesystem.getDirectoryItems`를 사용한다. root는 `projects/<projectId>/assets/audio`다. 재귀 walk는 directory만 내려가고 file extension을 소문자로 비교한다. 결과에서는 `projects/<projectId>/` 접두사를 제거한다.

생성자 option은 다음 exact signature를 사용한다. EditorApp은 ProjectCatalog가 이미 검증한 현재 Project ID만 전달하며, 테스트는 validateProjectId를 주입한다.

```lua
local catalog = MusicCatalog.new({
    getInfo = love.filesystem.getInfo,
    listDirectory = love.filesystem.getDirectoryItems,
    validateProjectId = function(projectId)
        return projectId:match("^[a-z0-9][a-z0-9_-]*$") ~= nil
    end,
})
```

`list`는 validateProjectId가 false면 `Invalid Project id.` 오류를 반환한다.

- [ ] **Step 3: Music 선택 모달 실패 테스트 작성**

`EditorDialog.music({ "assets/audio/a.ogg", "assets/audio/b.wav" }, current)`가 다음 option을 순서대로 제공하는지 검사한다.

```lua
{
    { value = "", label = "None" },
    { value = "assets/audio/a.ogg", label = "assets/audio/a.ogg" },
    { value = "assets/audio/b.wav", label = "assets/audio/b.wav" },
}
```

Enter/Apply는 selection 결과를 만들고 Escape/Cancel은 취소 결과를 만든다.

```lua
local dialog = EditorDialog.music({ "assets/audio/a.ogg" }, nil)
test.assertEqual(dialog:getSelection("music"), "")
assert(dialog:select("music", "assets/audio/a.ogg"))
dialog:submit("confirm")
local result = dialog:consumeResult()
test.assertEqual(result.selections.music, "assets/audio/a.ogg")
```

- [ ] **Step 4: EditorDialog.music과 EditorApp 연결**

`EditorDialog.music`은 kind `music`, title `Select Music`, selector id `music`, Apply와 Cancel 버튼을 사용한다. currentMusic과 같은 option을 초기 선택하고 없으면 None을 선택한다.

EditorApp 생성자는 `musicCatalog` 주입을 받는다. Music 셀 클릭 시 현재 Project로 목록을 읽고 모달을 연다. list 실패는 error 모달로 바꾼다. Apply 결과의 빈 문자열은 nil로 바꿔 `session:setProperty("mixtapeProperties", "music", value)`에 전달한다. Cancel은 Stage를 바꾸지 않는다.

- [ ] **Step 5: Sample audio README 작성**

`projects/sample/assets/audio/README.md`에 `.ogg`, `.mp3`, `.wav` 파일을 이 폴더 또는 하위 폴더에 두면 Music 선택 모달에 표시된다고 한글로 기록한다. 저작권 있는 오디오 파일은 저장소에 추가하지 않는다.

- [ ] **Step 6: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add editor/project/MusicCatalog.lua editor/ui/EditorDialog.lua editor/EditorApp.lua projects/sample/assets/audio/README.md tests/MusicCatalogTest.lua tests/EditorDialogTest.lua tests/EditorWorkflowTest.lua tests/TestRunner.lua
git commit -m "feat: add project music selector"
```

---

### Task 9: Scale 기반 타임라인과 wheel zoom

**Files:**
- Modify: `main.lua`
- Modify: `launcher/Launcher.lua`
- Modify: `editor/EditorApp.lua`
- Modify: `editor/EditorSession.lua`
- Modify: `editor/ui/EditorLayout.lua`
- Modify: `tests/LauncherTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/EditorUiTest.lua`
- Modify: `tests/EditorWorkflowTest.lua`

**Interfaces:**
- Produces: `love.wheelmoved(deltaX, deltaY)` forwarding
- Produces: `EditorSession:zoomTimeline(cursorOffsetX, wheelY) -> true|nil, errorMessage`
- `EditorLayout.getPixelsPerBeat(scale) -> 32 * scale`
- `EditorLayout.getVisibleBeatCount(layout, scale)`

- [ ] **Step 1: wheel 전달과 zoom 실패 테스트 작성**

다음 동작을 각각 테스트한다.

- Launcher가 wheel delta를 active EditorApp에 전달
- EditorApp은 마지막 mouse position이 timeline 안일 때만 zoom 호출
- Scale 1에서 wheel 1은 1.25, wheel -1은 0.8
- Scale은 0.25와 8 경계에서 clamp
- cursor beat가 zoom 전후 같은 화면 x에 유지
- timelineStartBeat는 0 아래로 내려가지 않음
- Play 중에도 wheel zoom 허용
- Values 직접 Scale 편집은 timelineStartBeat를 바꾸지 않음

cursor anchor 테스트는 다음 수치를 사용한다.

```lua
session.timelineStartBeat = 4
local cursorOffsetX = 320
local oldCursorBeat = 4 + cursorOffsetX / 32
assert(session:zoomTimeline(cursorOffsetX, 1))
local newScale = session:getProperty("editorProperties", "scale")
local newCursorBeat = session:getTimelineStartBeat() + cursorOffsetX / (32 * newScale)
test.assertNear(newScale, 1.25, 0.000001)
test.assertNear(newCursorBeat, oldCursorBeat, 0.000001)
```

- [ ] **Step 2: 실패 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: wheel callback 또는 `zoomTimeline` 없음, 고정 32px 기대 불일치로 실패한다.

- [ ] **Step 3: Scale 계산과 Session zoom 구현**

`EditorLayout` 상수를 다음으로 바꾼다.

```lua
local BASE_BEAT_WIDTH = 32

function EditorLayout.getPixelsPerBeat(scale)
    return BASE_BEAT_WIDTH * scale
end
```

타임라인 label, stripe, playhead와 visible count는 모두 pixelsPerBeat를 사용한다. fractional timelineStartBeat에서도 4박 label이 사라지지 않도록 화면에 걸친 정수 beat를 직접 순회한다.

```lua
local pixelsPerBeat = EditorLayout.getPixelsPerBeat(viewModel.scale)
local firstBeat = math.floor(viewModel.timelineStartBeat)
local lastBeat = math.ceil(viewModel.timelineStartBeat + timeline.width / pixelsPerBeat)
for beat = firstBeat, lastBeat do
    local x = timeline.x + (beat - viewModel.timelineStartBeat) * pixelsPerBeat
    if beat % 4 == 0 then
        love.graphics.print(tostring(beat), x + 4, timeline.y + 8)
    end
end
```

`EditorSession:zoomTimeline`은 다음 수식을 사용한다.

```lua
local oldScale = self.document:getEditorSettings().scale
local newScale = math.max(0.25, math.min(8, oldScale * (1.25 ^ wheelY)))
local cursorBeat = self.timelineStartBeat + cursorOffsetX / (32 * oldScale)
local newStart = cursorBeat - cursorOffsetX / (32 * newScale)
local changed, errorMessage = self.document:setEditorSetting("scale", newScale)
if not changed then return nil, errorMessage end
self.timelineStartBeat = math.max(0, newStart)
return true, nil
```

auto-follow는 새 visible count를 받고 fractional timelineStartBeat를 허용한다.

- [ ] **Step 4: 입력 전달 구현**

`main.lua`에 `love.wheelmoved`, Launcher에 `wheelmoved`, EditorApp에 `wheelmoved`를 추가한다. EditorApp은 `mousemoved`에서 `mouseX`, `mouseY`를 저장하고 dialog가 없으며 timeline hover일 때만 Session zoom을 호출한다. 오류는 기존 error modal로 표시한다.

- [ ] **Step 5: 테스트 통과 확인과 커밋**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: exit code 0과 `PASS:`.

```powershell
git add main.lua launcher/Launcher.lua editor/EditorApp.lua editor/EditorSession.lua editor/ui/EditorLayout.lua tests/LauncherTest.lua tests/EditorSessionTest.lua tests/EditorUiTest.lua tests/EditorWorkflowTest.lua
git commit -m "feat: add timeline scale zoom"
```

---

### Task 10: 통합 오류 경로, 문서와 최종 검증

**Files:**
- Modify: `tests/EditorWorkflowTest.lua`
- Modify: `tests/EditorSessionTest.lua`
- Modify: `tests/CoreTest.lua`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/STAGE_FORMAT.md`
- Modify: `docs/WORKFLOW.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/HANDOFF.md`

**Interfaces:**
- Verifies all public APIs and the full Editor Play/Pause path
- No new production abstraction unless a failing integration test exposes a missing rollback boundary

- [ ] **Step 1: 통합 실패 테스트 작성**

`tests/EditorWorkflowTest.lua`와 `tests/EditorSessionTest.lua`에 다음 시나리오를 추가한다.

- Music 파일 decode 실패 시 Project preview, Transport와 Metronome이 모두 stopped이고 error dialog 표시
- Music 없음에서 Play/Pause가 정상 동작
- Offset -0.5, Playback Rate 2에서 0.25 real seconds 후 음악이 position 0에서 시작
- 음악 duration 이후에도 view model의 beat가 계속 증가
- Metronome false에서는 Source를 만들지 않음
- Scale wheel 후 Save한 Stage JSON에 non-default scale만 있고 다른 Editor 기본값은 없음
- 실제 게임용 Core PlaybackTransport를 rate 인자 없이 Play하면 rate 1

Transport 시작 실패 rollback 테스트는 기존 fixture의 호출 상태를 다음과 같이 단정한다.

```lua
transportState.playError = "Failed to decode Project music."
local played, playError = session:play()
test.assertEqual(played, nil)
test.assertContains(playError, "decode")
test.assertEqual(transportState.pauseCount, 1)
test.assertEqual(metronomeState.pauseCount, 1)
test.assertEqual(testPlayerState.stopCount, 1)
test.assertEqual(session:isPlaying(), false)
```

EditorApp workflow 테스트에서는 같은 오류를 받은 뒤 view model의 dialog kind와 메시지를 확인한다.

```lua
app:activateMenuItem("play")
local viewModel = app:getViewModel()
test.assertEqual(viewModel.dialog.kind, "error")
test.assertContains(viewModel.dialog.message, "decode")
```

희소 저장 통합 테스트는 Scale만 바꾼 뒤 `StageStore:encode(document)` 결과를 decode하여 정확한 필드를 검사한다.

```lua
assert(session:setProperty("editorProperties", "scale", 2))
local encoded = assert(stageStore:encode(document))
local decoded = assert(json.decode(encoded))
test.assertEqual(decoded.editorSettings.scale, 2)
test.assertEqual(decoded.editorSettings.metronome, nil)
test.assertEqual(decoded.editorSettings.metronomePeriod, nil)
test.assertEqual(decoded.editorSettings.playbackRate, nil)
```

- [ ] **Step 2: 실패 확인과 최소 통합 수정**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: rollback, sparse serialization 또는 rate 기본 경로 중 누락된 동작의 테스트 이름으로 실패한다.

실패한 경계만 수정한다. rollback은 `EditorSession:pause()` 한 곳에서 Transport pause, Metronome pause와 TestPlayer stop을 호출하게 유지한다. 같은 정리 코드를 EditorApp에 복제하지 않는다.

- [ ] **Step 3: 사용자 문서 갱신**

모든 문서는 한글로 다음 내용을 정확히 반영한다.

- README: Music 배치 폴더, Properties 순서, Values 편집, wheel zoom과 Play/Pause
- ARCHITECTURE: Core TempoMap/MusicPlayback/PlaybackTransport, Editor Metronome과 의존 방향
- STAGE_FORMAT: schemaVersion 2 최소·확장 JSON, 희소 기본값, 검증 범위, 버전 1 비호환
- WORKFLOW: Project 오디오 배치 → Music 선택 → Offset/Volume/BPM → Editor 디버깅 설정 → Test Play
- ROADMAP: 공통 Transport와 Editor 재생 속성 완료 상태
- HANDOFF: 변경 파일, 공개 API, 테스트 결과, 실제 확인 결과와 다음 작업

- [ ] **Step 4: 전체 자동 검증**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' --version
& 'C:\Program Files\LOVE\lovec.exe' . --test
git diff --check
Get-ChildItem projects -Recurse -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
}
rg -n 'tempoMap|schemaVersion.: 1' projects editor tests docs/STAGE_FORMAT.md
rg -n 'require\("core\.' editor projects
```

Expected:

- `LOVE 11.5 (Mysterious Mysteries)`
- 테스트 exit code 0과 `PASS:`
- `git diff --check` 출력 없음
- ConvertFrom-Json 오류 없음
- production Stage와 STAGE_FORMAT에 tempoMap 또는 schemaVersion 1 잔존 없음. 거부 테스트 fixture의 문자열만 예외
- Editor와 Project의 Core 내부 직접 require 없음

- [ ] **Step 5: 실제 LÖVE UI·오디오 확인**

Run: `love .`

확인 순서:

1. Editor 진입 후 New Stage 생성
2. Editor Properties가 기본 선택되고 네 속성이 정해진 순서로 표시되는지 확인
3. Metronome true, Period 4로 Play해 강박과 일반박 음 차이 확인
4. Playback Rate 0.5와 2.0에서 시계, Project 화면과 메트로놈 속도가 함께 변하는지 확인
5. Mixtape Properties에서 Music 모달의 None과 Project 파일 목록 확인
6. 로컬에서 합법적으로 사용할 수 있는 `.wav` 파일을 정확히 `projects/sample/assets/audio/editor-transport-smoke.wav` 이름으로 임시 배치해 양수·음수 Offset, Volume과 Pause/재개 확인
7. 타임라인 wheel zoom이 커서 beat를 유지하고 Play 중에도 동작하는지 확인
8. 검증 후 임시 파일 `projects/sample/assets/audio/editor-transport-smoke.wav`만 제거

- [ ] **Step 6: HANDOFF에 검증 결과 기록 후 최종 테스트 재실행**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
git diff --check
git status --short
```

Expected: exit code 0, `PASS:`, whitespace 오류 없음. status에는 이번 Task의 의도한 문서와 테스트 변경만 남는다.

- [ ] **Step 7: 커밋**

```powershell
git add tests/EditorWorkflowTest.lua tests/EditorSessionTest.lua tests/CoreTest.lua README.md docs/ARCHITECTURE.md docs/STAGE_FORMAT.md docs/WORKFLOW.md docs/ROADMAP.md docs/HANDOFF.md
git commit -m "docs: complete playback properties workflow"
```

---

## Plan Self-Review Results

- 설계의 Stage v2·희소 저장은 Task 1~2, 공통 Transport는 Task 3~6, UI와 Music 선택은 Task 7~8, Scale은 Task 9, 통합과 문서는 Task 10에 각각 대응한다.
- 공개 식별자는 `editorProperties`, `mixtapeProperties`, `music`, `volume`, `beat0Offset`, `bpm`, `scale`, `playbackRate`, `metronome`, `metronomePeriod`로 전 Task에서 일치한다.
- `PlaybackTransport:play`의 rate 생략값은 1이며 EditorSession만 Stage의 Playback Rate를 명시적으로 전달한다.
- 계획 안에 미완성 표식이나 구현자에게 결정을 미루는 항목이 없음을 확인한다.
- 각 구현 Task는 실패 테스트, 실패 확인, 최소 구현, 전체 테스트와 커밋 순서를 가진다.

---

## Execution Completion Checklist

- [ ] 모든 Task 커밋이 순서대로 존재한다.
- [ ] Stage JSON은 schemaVersion 2, 최상위 bpm과 희소 설정만 사용한다.
- [ ] Editor Properties가 기본 선택이며 정해진 네 속성을 표시한다.
- [ ] Mixtape Properties가 Music, Volume, Beat 0 Offset, BPM 순서로 표시된다.
- [ ] Music 선택 모달, 양수·음수 Offset, Volume과 Pause/재개가 동작한다.
- [ ] Core Transport는 실제 게임용 rate 1 경로와 Editor override 경로를 함께 제공한다.
- [ ] Period 4 메트로놈은 한 BPM beat 안에서 강박 1회와 일반박 3회를 재생한다.
- [ ] Scale 직접 편집과 timeline wheel zoom이 Stage dirty·희소 저장·커서 anchor 규칙을 지킨다.
- [ ] 전체 자동 테스트, JSON 검사, 의존성 검사와 실제 LÖVE 확인이 통과한다.
- [ ] `docs/HANDOFF.md`에 최종 테스트 수와 다음 작업이 기록되어 있다.
