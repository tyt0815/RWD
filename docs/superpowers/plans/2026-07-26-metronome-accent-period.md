# 메트로놈 강박 주기 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메트로놈을 BPM 한 박마다 한 번 울리고, beat 0부터 `metronomePeriod` 박자마다 강박이 반복되도록 수정한다.

**Architecture:** Editor 전용 `MetronomePlayback`의 정적 looping Source 구조는 유지한다. SoundData를 한 BPM beat가 아니라 Period 전체 길이로 만들고, 각 beat 시작점에 클릭을 하나씩 배치하며 첫 beat만 강박으로 만든다. EditorSession과 Stage JSON API는 변경하지 않는다.

**Tech Stack:** LÖVE2D 11.5, LuaJIT/Lua 5.1, 프로젝트 내장 Lua 테스트 러너

## Global Constraints

- LÖVE2D 11.5와 LuaJIT/Lua 5.1 호환 문법만 사용한다.
- 클래스 역할 테이블과 파일 이름은 PascalCase, 변수와 함수는 camelCase, 상수는 UPPER_SNAKE_CASE, 들여쓰기는 공백 4칸을 사용한다.
- `editor/`는 `require("core")` 공개 진입점만 사용하며 Core 내부 경로를 직접 require하지 않는다.
- 클릭 간격은 항상 `60 / bpm`초다.
- beat 0은 강박이며 이후 `metronomePeriod` beat마다 강박을 반복한다.
- Period 1은 모든 BPM beat가 강박이고, Period 4는 `강-일-일-일`, Period 5는 `강-일-일-일-일`을 반복한다.
- 강박은 기존 1760Hz, 일반박은 기존 880Hz, 클릭 길이는 0.012초, 진폭은 0.35를 유지한다.
- `metronomePeriod` 기본값 4와 정수 범위 1~32를 유지한다.
- JSON 키 `editorSettings.metronomePeriod`와 schemaVersion 2를 유지한다.
- Playback Rate는 기존처럼 Metronome Source pitch에 적용한다.
- Stage 저장 구조, Core Transport, Project 코드와 Editor UI 배치는 변경하지 않는다.
- 설계 기준은 `docs/superpowers/specs/2026-07-26-metronome-accent-period-design.md`다.
- 각 production 변경은 먼저 예상 원인으로 실패하는 테스트를 확인한 뒤 구현한다.

---

## File Structure

### 수정 파일

- `editor/playback/MetronomePlayback.lua`: Period-beat SoundData 생성과 modulo seek
- `tests/MetronomePlaybackTest.lua`: 클릭 간격, 강박 패턴, loop 길이와 재개 위치 회귀 테스트
- `README.md`: Metronome Period 사용자 설명
- `docs/ARCHITECTURE.md`: Period 전체 정적 루프와 Editor 의존 경계
- `docs/STAGE_FORMAT.md`: 저장 필드 의미
- `docs/WORKFLOW.md`: Editor 설정 절차
- `docs/ROADMAP.md`: 메트로놈 강박 그룹 완료 상태
- `docs/HANDOFF.md`: 변경 내용, 검증 결과와 수동 청취 항목

### 변경하지 않는 파일

- `editor/EditorSession.lua`: 이미 BPM, Period, beat와 Playback Rate를 그대로 전달한다.
- `editor/stage/EditorSettings.lua`: 기본값 4와 범위 1~32가 새 의미에도 맞다.
- Project Stage JSON: 저장 값과 형식이 바뀌지 않는다.
- `docs/superpowers/specs/2026-07-22-mixtape-editor-playback-properties-design.md`와 기존 대형 계획: 당시 결정 기록으로 유지한다.

---

### Task 1: Period-beat 메트로놈 루프

**Files:**
- Modify: `tests/MetronomePlaybackTest.lua`
- Modify: `editor/playback/MetronomePlayback.lua`

**Interfaces:**
- Keeps: `MetronomePlayback.new(options) -> metronome`
- Keeps: `metronome:play(bpm, period, beat, playbackRate) -> true,nil | nil,errorMessage`
- Keeps: `metronome:pause()`, `metronome:stop()`
- Changes internally: `createSoundData(self, bpm, period) -> soundData, loopDuration, beatDuration`
- Consumes unchanged EditorSession call: `metronome:play(documentBpm, editorSettings.metronomePeriod, transportBeat, editorSettings.playbackRate)`

- [ ] **Step 1: 테스트의 기대 waveform 계산 helper 추가**

`tests/MetronomePlaybackTest.lua` 상단에서 production 클릭 공식과 같은 한 sample의 기대값을 계산한다. 이 helper는 강박 1760Hz와 일반박 880Hz를 숫자로 직접 검증한다.

```lua
local SAMPLE_RATE = 44100
local CLICK_SECONDS = 0.012
local AMPLITUDE = 0.35

local function expectedClickSample(frequency, offset)
    local time = offset / SAMPLE_RATE
    local envelope = 1 - time / CLICK_SECONDS
    return AMPLITUDE
        * envelope
        * math.sin(2 * math.pi * frequency * time)
end
```

- [ ] **Step 2: Period 1·4·5 실패 테스트 작성**

기존 `Metronome Period 4는 한 beat에 강박 하나와 일반박 셋을 만든다` 테스트를 다음 세 동작으로 교체한다.

```lua
{
    name = "Metronome Period 1은 BPM beat마다 강박을 반복한다",
    run = function(test)
        local metronome, state = newMetronome()
        assert(metronome:play(120, 1, 0, 1))

        test.assertEqual(state.sampleCount, SAMPLE_RATE / 2)
        test.assertNear(state.samples[1], expectedClickSample(1760, 1), 0.000001)
    end,
},
{
    name = "Metronome Period 4는 네 BPM beat에 강박 하나와 일반박 셋을 만든다",
    run = function(test)
        local metronome, state = newMetronome()
        assert(metronome:play(120, 4, 0, 1))

        local beatSamples = SAMPLE_RATE / 2
        test.assertEqual(state.sampleCount, beatSamples * 4)
        test.assertNear(state.samples[1], expectedClickSample(1760, 1), 0.000001)
        for beatIndex = 1, 3 do
            local sampleIndex = beatIndex * beatSamples + 1
            test.assertNear(
                state.samples[sampleIndex],
                expectedClickSample(880, 1),
                0.000001
            )
        end
        for sampleIndex in pairs(state.samples) do
            test.assertTrue(sampleIndex >= 0)
            test.assertTrue(sampleIndex < state.sampleCount)
        end
    end,
},
{
    name = "Metronome Period 5는 다섯 BPM beat 길이로 반복한다",
    run = function(test)
        local metronome, state = newMetronome()
        assert(metronome:play(120, 5, 0, 1))

        local beatSamples = SAMPLE_RATE / 2
        test.assertEqual(state.sampleCount, beatSamples * 5)
        test.assertNear(state.samples[1], expectedClickSample(1760, 1), 0.000001)
        test.assertNear(
            state.samples[4 * beatSamples + 1],
            expectedClickSample(880, 1),
            0.000001
        )
    end,
},
```

- [ ] **Step 3: Period 패턴 테스트의 RED 확인**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
```

Expected: Period 4와 Period 5의 `sampleCount`가 각각 기대값의 1/4, 1/5이므로 실패한다. Period 4 일반박 sample 위치도 nil 또는 잘못된 값으로 실패한다.

- [ ] **Step 4: Period 전체 SoundData 최소 구현**

`editor/playback/MetronomePlayback.lua`의 `createSoundData`를 다음 계산으로 교체한다.

```lua
local function createSoundData(self, bpm, period)
    local beatDuration = 60 / bpm
    local loopDuration = beatDuration * period
    local sampleCount = math.floor(loopDuration * SAMPLE_RATE + 0.5)
    local clickSampleCount = math.floor(CLICK_SECONDS * SAMPLE_RATE)
    local soundData = self.soundDataFactory(sampleCount, SAMPLE_RATE)

    for beatIndex = 0, period - 1 do
        local frequency = beatIndex == 0 and ACCENT_FREQUENCY or NORMAL_FREQUENCY
        local startSample = math.floor(beatIndex * beatDuration * SAMPLE_RATE)
        for offset = 0, clickSampleCount - 1 do
            local sampleIndex = startSample + offset
            if sampleIndex >= sampleCount then break end
            local time = offset / SAMPLE_RATE
            local envelope = 1 - time / CLICK_SECONDS
            local sample = AMPLITUDE
                * envelope
                * math.sin(2 * math.pi * frequency * time)
            soundData:setSample(sampleIndex, sample)
        end
    end

    return soundData, loopDuration, beatDuration
end
```

- [ ] **Step 5: Period 패턴 테스트 GREEN 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: 새 Period 1·4·5 테스트는 통과한다. 기존 fractional seek 테스트는 아직 `0.25`를 기대하므로 실패한다.

- [ ] **Step 6: modulo 재개 위치 실패 테스트 작성**

기존 중간 beat 테스트를 다음 테스트로 교체하고 beat 4의 강박 loop 위치도 추가한다.

```lua
{
    name = "Metronome Period 4는 beat 4에서 강박 위치로 돌아간다",
    run = function(test)
        local metronome, state = newMetronome()
        assert(metronome:play(120, 4, 4, 1))

        test.assertNear(state.seekPosition, 0, 0.000001)
    end,
},
{
    name = "Metronome은 Period 안의 fractional beat 위치에서 재개한다",
    run = function(test)
        local metronome, state = newMetronome()
        assert(metronome:play(120, 4, 6.5, 1))

        test.assertNear(state.seekPosition, 1.25, 0.000001)
    end,
},
```

- [ ] **Step 7: modulo 재개 RED 확인**

Run: `& 'C:\Program Files\LOVE\lovec.exe' . --test`

Expected: beat 4는 기존 fractional 계산 결과 0이라 통과할 수 있지만, beat 6.5는 기존 구현이 `1.25`가 아닌 `1.0` 또는 변경 중간값을 반환해 실패한다. 하나 이상의 새 seek 계약이 production 변경 전 실패함을 확인한다.

- [ ] **Step 8: Period modulo seek 최소 구현**

`MetronomePlayback:play`의 SoundData 반환값과 seek 계산을 다음으로 바꾼다.

```lua
local soundCreated, soundData, loopDuration, beatDuration = pcall(
    createSoundData,
    self,
    bpm,
    period
)
if not soundCreated then return failureMessage(soundData) end

-- Source 생성과 setLooping은 기존 순서를 유지한다.
local loopBeat = beat % period
local sought, seekError = callSource(
    source,
    "seek",
    loopBeat * beatDuration
)
```

`loopDuration`은 SoundData 생성 결과의 명시적 의미를 유지하기 위해 반환받되 Source API에 별도로 전달하지 않는다. LÖVE Source duration은 SoundData 길이에서 결정된다.

- [ ] **Step 9: Task 1 전체 검증**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
git diff --check
```

Expected: exit code 0, `PASS:` 출력, whitespace 오류 없음. 기존 Playback Rate, Pause, Stop, Source 실패와 userdata Source 테스트도 모두 통과한다.

- [ ] **Step 10: Task 1 커밋**

```powershell
git add editor/playback/MetronomePlayback.lua tests/MetronomePlaybackTest.lua
git commit -m "fix: use metronome period as accent cycle"
```

---

### Task 2: 사용자 문서와 최종 검증

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/STAGE_FORMAT.md`
- Modify: `docs/WORKFLOW.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/HANDOFF.md`

**Interfaces:**
- Documents unchanged JSON key: `editorSettings.metronomePeriod`
- Documents unchanged default/range: `4`, integer `1~32`
- Documents new runtime rule: BPM beat마다 한 tick, beat 0부터 Period마다 강박

- [ ] **Step 1: README 설명 추가**

`Editor Properties` 목록 다음에 아래 의미를 한글로 기록한다.

```markdown
Metronome은 BPM 한 박마다 한 번 울린다. Metronome Period는 클릭 속도가 아니라 강박 반복 길이다. Period 4는 `강-일-일-일`, Period 5는 `강-일-일-일-일`을 반복한다.
```

- [ ] **Step 2: 아키텍처와 Stage 형식 갱신**

`docs/ARCHITECTURE.md`의 기존 subdivision 문단을 다음 계약으로 교체한다.

```markdown
`MetronomePlayback`은 Period 전체 길이의 Editor 전용 정적 Source를 만든다. BPM 한 박마다 클릭 하나를 배치하고 beat 0에 해당하는 첫 클릭만 1760Hz 강박, 나머지는 880Hz 일반박을 사용한다. 재개할 때는 `beat % period` 위치로 seek하며 Core와 Project는 이 Editor 디버깅 음원을 알지 못한다.
```

`docs/STAGE_FORMAT.md`의 `metronomePeriod` 표 설명과 바로 아래 본문에 다음을 명시한다.

```markdown
`metronomePeriod`는 강박이 반복되는 BPM 박자 수다. 값 4는 beat 0, 4, 8, 12에서 강박이 나며 BPM 클릭 간격 자체는 바꾸지 않는다.
```

- [ ] **Step 3: 제작 흐름과 로드맵 갱신**

`docs/WORKFLOW.md`의 "한 beat 안의 subdivision 수" 설명을 다음으로 교체한다.

```markdown
4. Metronome Period: BPM 한 박마다 나는 클릭을 몇 박 단위로 강박 그룹화할지 지정한다. 값 4는 `강-일-일-일`을 반복한다.
```

`docs/ROADMAP.md`의 TestPlayer와 Editor 재생 완료 항목 아래에 다음 완료 항목을 추가한다.

```markdown
- [x] BPM beat 고정 클릭과 Metronome Period 강박 그룹
```

- [ ] **Step 4: HANDOFF 갱신**

`docs/HANDOFF.md`에 다음 사실을 반영한다.

- 최근 커밋과 기능 범위에 메트로놈 강박 주기 수정 커밋을 추가한다.
- Metronome Period는 강박 반복 박자 수이며 기본값 4는 `강-일-일-일`이라고 기록한다.
- 최종 전체 테스트의 실제 `PASS:` 숫자와 명령을 기록한다.
- LÖVE 기동 smoke 결과를 기록한다.
- Period 4 패턴의 실제 청취 여부를 사실대로 기록한다.
- 기존 "실제 LÖVE가 생성한 WAV" 문구는 "임시 생성한 WAV를 실제 LÖVE에서 decode"로 바로잡는다.
- 다음 작업인 Project Event 등록 계약은 유지한다.

- [ ] **Step 5: 잘못된 subdivision 설명 제거 확인**

Run:

```powershell
rg -n "한 beat 안|subdivision|한 BPM beat 길이" README.md docs/ARCHITECTURE.md docs/STAGE_FORMAT.md docs/WORKFLOW.md docs/ROADMAP.md docs/HANDOFF.md
```

Expected: 현재 동작을 설명하는 사용자 문서에서 이전 의미가 검색되지 않는다. 역사 기록인 `docs/superpowers/specs/2026-07-22-mixtape-editor-playback-properties-design.md`와 기존 계획은 이 검색 범위에 넣지 않는다.

- [ ] **Step 6: 전체 자동 검증**

Run:

```powershell
& 'C:\Program Files\LOVE\lovec.exe' --version
& 'C:\Program Files\LOVE\lovec.exe' . --test
git diff --check
Get-ChildItem projects -Recurse -Filter *.json | ForEach-Object {
    Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json | Out-Null
}
rg -n 'require\("core\.' editor projects
```

Expected:

- `LOVE 11.5 (Mysterious Mysteries)`
- test exit code 0과 `PASS:`
- `git diff --check` 출력 없음
- Project JSON parse 오류 없음
- Editor와 Project의 Core 내부 직접 require 없음

- [ ] **Step 7: LÖVE 기동과 수동 청취 검증**

Run: `love .`

확인 순서:

1. Sample Stage에서 Metronome을 true로 바꾼다.
2. Period 1에서 BPM 한 박마다 강박이 나는지 확인한다.
3. Period 4에서 클릭 속도는 그대로이고 `강-일-일-일`이 반복되는지 확인한다.
4. Pause 후 중간 beat에서 재개해도 다음 강박이 4의 배수 beat에 맞는지 확인한다.

사람이 청취하지 못한 환경이면 통과로 기록하지 않고 `docs/HANDOFF.md`의 수동 미확인 항목에 그대로 남긴다.

- [ ] **Step 8: 검증 결과 기록 후 최종 재검증**

`docs/HANDOFF.md`에 Step 6과 Step 7의 실제 결과를 기록한 뒤 다시 실행한다.

```powershell
& 'C:\Program Files\LOVE\lovec.exe' . --test
git diff --check
git status --short
```

Expected: exit code 0과 `PASS:`, whitespace 오류 없음. status에는 Task 2의 여섯 문서 변경만 남는다.

- [ ] **Step 9: Task 2 커밋**

```powershell
git add README.md docs/ARCHITECTURE.md docs/STAGE_FORMAT.md docs/WORKFLOW.md docs/ROADMAP.md docs/HANDOFF.md
git commit -m "docs: correct metronome period semantics"
```

---

## Plan Self-Review Results

- 설계의 클릭 간격, 강박 위치, Period 1·4·5, modulo 재개와 Playback Rate 유지 요구는 Task 1의 테스트와 구현 단계에 각각 대응한다.
- JSON 키·기본값·범위·schemaVersion 유지와 사용자 문서 수정 요구는 Task 2에 대응한다.
- `MetronomePlayback.new`, `play`, `pause`, `stop` 공개 signature는 전 Task에서 변경하지 않는다.
- 새 production abstraction, Stage 필드, Core·Project 의존성은 추가하지 않는다.
- 미완성 표식, 구현자에게 결정을 미루는 단계와 균형이 맞지 않는 code fence가 없음을 확인했다.

---

## Execution Completion Checklist

- [ ] BPM 120에서 Period 1과 Period 4 모두 클릭 간격이 0.5초다.
- [ ] Period 4가 `강-일-일-일`, Period 5가 `강-일-일-일-일`을 만든다.
- [ ] beat 0, 4, 8은 Period 4의 같은 강박 loop 위치다.
- [ ] fractional beat 재개가 `(beat % period) * 60 / bpm` 위치를 사용한다.
- [ ] Playback Rate, Pause, Stop과 Source 오류 정리가 회귀하지 않는다.
- [ ] JSON 키, 기본값, 범위와 schemaVersion 2가 바뀌지 않는다.
- [ ] 사용자 문서에 subdivision 의미가 남지 않는다.
- [ ] 전체 테스트, JSON 검사, 의존성 검사와 LÖVE 기동 smoke 결과가 HANDOFF에 기록된다.
- [ ] 실제 청취 여부가 과장 없이 HANDOFF에 기록된다.
