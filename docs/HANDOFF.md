# 인수인계

## 현재 상태

LÖVE2D 11.5 Launcher에서 Sample Project와 Stage 에디터를 열 수 있다. 에디터는 schemaVersion 2 Stage를 만들고 열고 원자 저장하며, Project 음악을 Core `PlaybackTransport`에 연결해 Project Canvas와 함께 미리 재생한다.

`Editor Properties`는 Scale, Playback Rate, Metronome, Metronome Period를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, BPM을 순서대로 제공한다. 숫자 직접 편집, boolean 전환, Project Music 선택 모달, cursor anchor wheel zoom, Play/Pause, 재생 오류 정리와 beat rollback이 연결되었다. 기본값은 Stage JSON에서 희소화된다.

Stage Event 실행, 리듬 판정, Timeline Event 배치·편집과 Project 입력 전달은 아직 구현하지 않았다.

## 이번 기능 범위와 커밋

- 기준 커밋: `2d544f1`
- 완료된 기능 커밋 범위: `2d544f1..HEAD`
- 마지막 커밋: `fix: replay latest metronome beat` (이 문서를 포함한 현재 HEAD)
- Task 10 통합 테스트·문서와 `EditorApp` 최소 수정은 이 문서를 포함한 현재 HEAD 커밋이다. 전체 기능 범위는 `2d544f1..HEAD`로 확인한다.

기능 커밋은 Stage 설정·v2 전환, Core Tempo/Music/Transport, Editor 재생 조립, Properties/Music UI와 Scale zoom을 포함한다. 주요 변경 파일은 다음과 같다.

- Core: `core/MixtapeSettings.lua`, `core/TempoMap.lua`, `core/MusicPlayback.lua`, `core/PlaybackTransport.lua`, `core/init.lua`
- Editor: `editor/EditorSession.lua`, `editor/EditorApp.lua`, `editor/stage/*`, `editor/playback/*`, `editor/project/MusicCatalog.lua`, `editor/properties/PropertyCatalog.lua`, `editor/ui/*`
- 입력·Sample: `main.lua`, `launcher/Launcher.lua`, `projects/sample/assets/audio/README.md`, `projects/sample/stages/*.json`
- 테스트: Settings, Tempo, Music, Transport, Metronome, Stage, Editor, Launcher 통합 테스트와 `tests/TestRunner.lua`
- 문서: `README.md`, `docs/ARCHITECTURE.md`, `docs/STAGE_FORMAT.md`, `docs/WORKFLOW.md`, `docs/ROADMAP.md`, 이 문서
- Task 10 추가 변경: `editor/EditorApp.lua`, `tests/CoreTest.lua`, `tests/EditorSessionTest.lua`, `tests/EditorWorkflowTest.lua`

## 공개 API와 데이터 계약

`require("core")`가 다음 API를 공개한다.

- `Core.MixtapeSettings.validate`, `resolve`, `compact`
- `Core.TempoMap.new`; `beatToSeconds`, `secondsToBeat`, `getBpm`
- `Core.MusicPlayback.new`; `prepare`, `play`, `update`, `pause`, `stop`
- `Core.PlaybackTransport.new`; `configureMixtape`, `setBpm`, `play`, `pause`, `seekBeat`, `update`, `getBeat`, `getTimelineSeconds`, `isPlaying`, `getPlaybackRate`

`PlaybackTransport:play()`의 rate 생략값은 실제 게임용 `1.0`이다. EditorSession만 Stage의 Playback Rate를 명시적으로 전달한다. `PlaybackTransport:seekBeat()`는 pause 상태에서만 허용되며 TestPlayer update 실패 뒤 이전 beat rollback에 사용한다.

Editor 쪽 추가 경계는 `EditorSession:getProperty`, `setProperty`, `zoomTimeline`, `MusicCatalog:list`, `PropertyCatalog.getEvents/getEvent`, `EditorDialog.music`과 `wheelmoved` 입력 전달이다. `EditorApp:getViewModel()`은 오류 통합 경로 검증을 위해 현재 `dialog`도 제공한다.

Stage 계약은 schemaVersion 2, 최상위 `bpm`, 선택적 `mixtape`, 선택적 `editorSettings`, `events`다. 기본값과 빈 선택 객체는 저장하지 않으며 버전 1은 자동 변환하지 않는다.

## Task 10 RED/GREEN

- 기준: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 177 tests`
- RED: 통합 테스트 7개를 추가한 뒤 Music decode 오류의 view model dialog가 `expected: error`, `actual: nil`로 실패함을 확인
- 최소 수정: `EditorApp:getViewModel()`에 기존 `self.dialog`를 추가. 정리 코드는 `EditorSession:pause()`에 그대로 유지
- GREEN: `PASS: 184 tests`

통합 테스트는 Music 없음 Play/Pause, decode 실패 정리와 오류 dialog, Offset `-0.5`·Rate `2`의 0.25초 지연 시작, Music duration 뒤 beat 진행, Metronome false의 Source 미생성, wheel zoom 뒤 Scale-only JSON 저장, Core Transport 기본 rate `1`을 검증한다.

## 최근 자동 검증

- `C:\Program Files\LOVE\lovec.exe --version` → `LOVE 11.5 (Mysterious Mysteries)`
- `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 184 tests`
- `git diff --check` → 출력 없음
- `projects` 아래 JSON 2개를 PowerShell `ConvertFrom-Json`으로 검사 → 오류 없음
- `rg -n 'tempoMap|schemaVersion.: 1' projects editor tests docs/STAGE_FORMAT.md` → Stage 파일과 형식 문서에는 잔존 없음. 출력 4건은 v2 로더의 명시적 legacy 필드 거부 2줄과 대응 거부 테스트 2줄
- `rg -n 'require\("core\.' editor projects` → 출력 없음
- 임시 실제 WAV smoke → `PASS: actual WAV decode, volume, seek, pitch, pause/resume`
- 임시 `projects/sample/assets/audio/editor-transport-smoke.wav` 절대 경로 확인 후 삭제 → `Test-Path=False`
- 숨김 창 `love .`를 2초 실행 → `Responding=True`, `HasExited=False`; 확인 뒤 해당 프로세스 종료

이 문서를 포함한 커밋 뒤 전체 suite를 다시 실행해 `PASS: 184 tests`, `git diff --check` 출력 없음과 `git status --short` 0건을 확인했다.

## 실제 확인과 미확인 사항

임시 생성한 WAV를 실제 LÖVE에서 decode하고 stream Source에 Volume `0.25`, seek `0.1`, pitch `0.5/2.0`, play/pause/resume/stop을 적용하는 smoke는 통과했다. 실제 앱 프로세스도 응답 상태를 유지했다.

숨김 GUI 환경에서는 SDL 입력과 청취를 의미 있게 자동화할 수 없었다. 따라서 다음 항목은 자동 통합 테스트로 동작을 검증했지만 사람이 화면과 소리로 확인하지는 못했다.

- Editor 진입부터 New Stage 생성까지의 실제 클릭 화면
- Properties 표시 순서와 Music 모달의 실제 시각 상태
- Period 4의 1760Hz 강박과 880Hz 일반박 음색 차이 청취
- UI에서 Playback Rate `0.5/2.0`, 양수·음수 Offset과 Pause/재개 조작
- Play 중 wheel zoom의 cursor anchor를 실제 화면에서 확인

실제 오디오 asset은 커밋하지 않았다.

## 다음 작업

다음 개발 단위는 Project Event 등록 계약을 정의하고 Stage Event를 TestPlayer 실행에 연결하는 작업이다. 등록되지 않은 `patternId`의 오류 보고 기준과 Project 입력 전달 범위를 함께 결정한다.

## 현재 범위 밖인 기능

- 실제 리듬 판정
- Pattern 등록 및 참조 전개
- Stage Event 실행과 Editor Event 배치·편집
- TestPlayer의 Project 입력 전달
- 독립 게임 패키징

## 세션 재개 순서

1. `README.md`와 이 문서를 읽는다.
2. `docs/ARCHITECTURE.md`, `docs/STAGE_FORMAT.md`, `docs/ROADMAP.md`를 확인한다.
3. `love . --test`를 실행한다.
4. Project Event 등록 계약과 Stage Event 실행 연결 범위를 확인한다.


## 메트로놈 Period 의미 수정 (2026-07-26)

- 기준 범위: `80504bf..HEAD`; 최종 수정 커밋은 `fix: replay latest metronome beat`다.
- 메트로놈은 BPM 한 박마다 클릭하며, `editorSettings.metronomePeriod`는 강박 반복 박자 수다. JSON 키는 그대로이고 기본값은 `4`, 허용 범위는 정수 `1~32`다. Period 4는 `강 약 약 약`, Period 5는 `강 약 약 약 약`을 반복한다.
- 최종 리뷰에서 Period 전체 길이의 정적 SoundData가 낮은 BPM에서 메모리를 과도하게 사용하는 문제를 수정했다. 이제 529 samples인 0.012초 강박·일반박 SoundData와 non-looping static Source를 각각 하나만 만들고, `EditorSession:update`가 Transport beat를 전달해 새 정수 beat crossing을 동적으로 재생한다. 여러 beat를 건너뛰면 두 Source를 정지·rewind한 뒤 마지막 crossed beat 하나만 constant-time으로 재생한다.
- 최종 자동 검증: Fix Round 2 focused suite는 `PASS: 11 tests`, 전체 suite는 `PASS: 190 tests`와 종료 코드 `0`을 반환했다. `git diff --check`는 출력 없이 통과했고, Project JSON은 PowerShell `ConvertFrom-Json`으로 모두 통과했으며 `rg -n 'require\("core\.' editor projects`는 출력이 없었다.
- LÖVE 기동 smoke: `love .`를 숨김 창으로 2초 실행해 `LOVE_SMOKE_RUNNING=True`를 확인한 뒤 종료했다. 이 환경에서는 사람이 Period 1/4의 소리와 pause 뒤 강박 위치를 직접 청취하지 못했으므로 수동 청취는 미확인이다.
- 다음 작업은 Project Event 등록 계약을 정의하고 Stage Event를 TestPlayer 실행에 연결하는 일이다.

## Values 커서 편집 (2026-07-26)

- 숫자 Values 인라인 편집에 좌우 방향키 커서 이동, 커서 위치 삽입, Backspace/Delete 삭제와 커서 표시를 추가했다. 셀을 처음 클릭한 순간부터 값 끝에 커서를 표시하며 Enter 확정과 Escape 취소 동작을 유지한다.
- RED: 중간 삽입·삭제 워크플로우 테스트에서 `expected: 1325`, `actual: 1352` 실패를 확인했다. 최초 포커스 커서 렌더링 테스트에서도 커서 사각형을 찾지 못하는 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 191 tests`; `git diff --check` → 출력 없음.
- LÖVE 기동 smoke: 숨김 창으로 2초 실행해 `LOVE_SMOKE_RUNNING=True`를 확인했다. 실제 키보드 입력의 수동 화면 확인은 이 환경에서 수행하지 못했다.

## Values 커서 깜빡임 (2026-07-26)

- 숫자 Values 커서는 포커스 직후 표시되며 0.5초마다 표시/숨김을 반복한다. 문자 입력, Backspace/Delete와 좌우 방향키 입력 시에는 타이머를 초기화해 커서가 즉시 다시 보인다.
- RED: 시간 경과에 따른 `cursorVisible` 테스트에서 최초 값이 `nil`이라 실패하는 것을 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 192 tests`; 숨김 창 LÖVE 기동과 `git diff --check`는 최종 검증한다.

## 공통 TextInput 통합 (2026-07-26)

- `editor/ui/TextInput.lua`가 UTF-8 커서 이동, 중간 삽입, Backspace/Delete, 0.5초 커서 깜빡임과 입력 후 타이머 초기화를 공통으로 소유한다.
- Properties/Values는 숫자 필터를 적용하고, New/Save As Dialog 필드는 일반 UTF-8 입력으로 같은 모듈을 사용한다. 각 화면은 기존 배경·테두리 렌더링과 확정/검증 책임을 유지한다.
- RED: Dialog에서 `left` 뒤 `X` 입력 시 `expected: 가X나`, `actual: 가나X`로 실패함을 확인했다.
- GREEN: UTF-8 중간 삽입·삭제, Dialog 커서 렌더링·깜빡임과 기존 Values 동작을 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 193 tests`; `git diff --check`와 Core 내부 require 경계 검색은 출력 없음; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`.

## Values 최초 입력 삽입 수정 (2026-07-26)

- Values에만 남아 있던 최초 입력 전체 대체 옵션을 제거했다. 이제 처음 포커스한 직후에도 Dialog와 동일하게 현재 커서 위치에서 입력을 이어간다.
- RED: 값 `1`에 최초로 `2`를 입력했을 때 `expected: 12`, `actual: 2`로 실패함을 확인했다.
- GREEN: 기존 값 변경 테스트를 Backspace 삭제 후 입력 흐름으로 갱신했으며 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 194 tests`; `git diff --check`와 잔존 대체 옵션 검색은 출력 없음; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`.

## 검색 ComboBox 통합 (2026-07-26)

- `editor/ui/ComboBox.lua`가 선택값, 열림 상태, TextInput 기반 검색어, 부분 문자열 필터, 강조·스크롤 위치와 키보드 선택을 공통으로 소유한다.
- New/Open의 Project·Stage와 Music 선택은 닫힌 상태에서 한 줄만 표시하고, 클릭하면 검색 입력과 최대 6개 결과를 드롭다운으로 표시한다. 마우스와 위·아래 방향키·Enter로 선택하고 Escape로 목록만 닫는다.
- `AGENTS.md`에 Editor 입력 UI는 TextInput/ComboBox를 직접 재구현하지 않고 공통 모듈로 조합하며, 향후 Project 공유 시 중립 UI 경계를 먼저 설계한다는 지침을 추가했다. RadioButton 등은 구현하지 않았다.
- RED: ComboBox 테스트 2개가 `module 'editor.ui.ComboBox' not found`로 실패함을 확인했다.
- GREEN: 필터·키보드 단위 테스트와 Dialog Project/Stage/Music 렌더링·통합 테스트를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 196 tests`; `git diff --check`와 Core 내부 require 경계 검색은 출력 없음; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`.

## ComboBox 인라인 검색 행 (2026-07-26)

- ComboBox를 열었을 때 선택값 행 아래에 별도 검색 행을 추가하던 구조를 제거했다. 이제 선택값 행 자체가 빈 검색 입력으로 전환되고 필터 결과가 바로 아래에 표시된다.
- RED: Music ComboBox를 연 직후 입력 행의 `expected: ""`, `actual: "assets/audio/b.wav"` 실패를 확인했다.
- GREEN: 인라인 검색 행과 커서 렌더링을 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 196 tests`; `git diff --check` 출력 없음; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`.

## Core.UI 공통 경계 이동 (2026-07-26)

- 스타일 독립적인 `TextInput`과 `ComboBox`를 `editor/ui/`에서 `core/ui/`로 이동하고 `require("core").UI.TextInput/ComboBox`로 공개했다. Editor는 Core 공개 API만 사용하며 색상, 좌표, Dialog·Values 렌더링은 계속 `editor/`가 소유한다.
- Project도 향후 Editor 의존 없이 같은 Core.UI를 기반으로 Project 전용 UI를 조합할 수 있다. `AGENTS.md`에 Core UI와 화면별 스타일의 책임, 공개 API 사용, 직접 재구현 금지 지침을 반영했다.
- RED: ComboBox 테스트를 Core 공개 API로 전환한 뒤 `attempt to index field 'UI' (a nil value)` 2건을 확인했다.
- GREEN: Core.UI 공개와 Editor 연결 후 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 196 tests`; `git diff --check`, Editor/Project의 Core 내부 경로 require 검색, Core UI의 Editor·Project·graphics 의존 검색은 출력 없음; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`.
