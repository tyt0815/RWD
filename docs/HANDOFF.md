# 인수인계

## 현재 상태

LÖVE2D 11.5 Launcher에서 Sample Project와 Stage 에디터를 열 수 있다. 에디터는 schemaVersion 2 Stage를 만들고 열고 원자 저장하며, Project 음악을 Core `PlaybackTransport`에 연결해 Project Canvas와 함께 미리 재생한다.

`Editor Properties`는 Snap, Scale, Playback Rate, Auto Play, Metronome, Metronome Period, Track, Preview Aspect Width, Preview Aspect Height를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, Onset Threshold, BPM을 순서대로 제공한다. 숫자 직접 편집, boolean 전환, Project Music 선택 모달, cursor anchor wheel zoom, 상단 click·adaptive edge-scroll 재생 바 drag, F·Ctrl+S·R 단축키, 재생 오류 정리와 beat rollback이 연결되었다. 기본값은 Stage JSON에서 희소화된다.

Game Manager의 End와 Set Input Enabled Event를 처리한다. Project Event Category·number Property 등록, 현재 Stage의 Project 전달과 활성 상태의 Space 누름·뗌 전달을 지원한다. Sample Project는 Core beat 기반 Tap 판정 예제를 제공한다. Rhythm Dotgeo에는 배경·액터 소환, Tap/Long 큐 응답과 턴을 제공하는 스피키송 Category가 있으며 Core beat 기반 Long Note 판정도 구현되었다. 일반 Pattern 실행은 아직 구현하지 않았다.

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

- `Core.TapJudgment.new`; `addNote`, `input`, `update`
- `Core.BeatTween.new`; `start`, `moveTo`, `getValue`, `isActive`
- `Core.ProjectEvents.validate`, `getCategories`, `getEvent`, `getDefaultParams`, `validateParams`
- `Core.ProjectCategories.discover`, `createHost`; Host `getRuntime`, `setAutoPlay`, `startStage`, `applyOccurrences`, `update`, `keypressed`, `draw`
- `Core.StageRuntime.new`; `start`, `update`, `getCurrentBeat`, `isInputEnabled`, `hasEndEvent`, `isEnded`, `getEndBeat`
- `Core.MixtapeSettings.validate`, `resolve`, `compact`
- `Core.TempoMap.new`; `beatToSeconds`, `secondsToBeat`, `getBpm`
- `Core.MusicPlayback.new`; `prepare`, `play`, `update`, `pause`, `stop`
- `Core.PlaybackTransport.new`; `configureMixtape`, `setBpm`, `play`, `pause`, `seekBeat`, `update`, `getBeat`, `getTimelineSeconds`, `isPlaying`, `isMusicFinished`, `getPlaybackRate`

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

다음 개발 단위는 일반 Pattern Event 등록·전개다. 현재 Tap과 Long Note의 임시 beat 판정창을 프로젝트 요구에 따라 ms 기반으로 확장할지도 함께 결정한다.

## 현재 범위 밖인 기능

- Pattern 등록 및 참조 전개
- Project Pattern Event 실행
- 모든 Project에 공통 적용되는 독립 실행용 Stage 선택 흐름(Rhythm Dotgeo 전용 흐름은 구현됨)
- 독립 게임 패키징

## Sample 게임플레이 노드 (2026-07-27)

- Core 공개 API에 `TapJudgment`와 `ProjectEvents`를 추가했다. Sample은 manifest에 `Spawn Actors` singleton과 `Cue & Response`의 `Response Delay (Beats)`를 등록한다.
- Editor Play는 현재 Stage와 기준 beat를 Project `startStage`에 전달하고, update에 현재 beat를 제공하며 입력이 활성화된 동안 Space를 `keypressed(key, beat)`로 전달한다.
- Cue & Response Timeline 노드는 파란 cue 끝점, 반투명 초록 연결 영역과 주황 response 끝점을 사용한다. 연결 가운데는 충돌에서 제외하고 양 끝만 충돌시켜 다른 노드가 겹쳐도 선택·가시성을 유지한다.
- Sample Stage 화면은 기본 검정이며 Spawn Actors 이후 좌우 Sprite 액터를 표시한다. cue는 왼쪽 액터를 기본 `웃피키`에서 `스피키`로 잠시 바꾸고 beep를 낸다. Space의 GOOD·EMPTY_INPUT은 오른쪽을 `스피키`, BAD·MISS는 `스피키_네르기`로 바꾼 뒤 기본으로 복원하며 오른쪽은 항상 좌우 반전한다. 임시 판정창은 GOOD `±0.1 beat`, BAD `±0.25 beat`다.
- 새 Project 제작 문서는 `docs/PROJECT_NODES_TUTORIAL.md`, Sample 참고 주석은 `projects/sample/project.lua`와 `projects/sample/game/SampleGame.lua`에 있다. 같은 책임 분리를 `AGENTS.md`에 추가했다.
- RED: Core 테스트 추가 후 `TapJudgment`와 `ProjectEvents` 공개 API 부재로 3건 실패했다.
- GREEN: Core 판정, 등록, Project Event Stage 왕복, 연결형 충돌, Stage·beat·Space 전달과 Sample 판정을 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 250 tests`.
- 최종 검증: `git diff --check`와 Editor/Project의 Core 내부 require 검색은 출력 없음, Project JSON은 PowerShell `ConvertFrom-Json` 통과, 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 화면 색과 생성 tone 청취는 사람이 수동 확인하지 못했다.

## Cue 배치·Sprite·Turn 후속 수정 (2026-07-27)

- Response Delay 8을 UI 기본값으로 설정해도 우클릭 생성 충돌 검사는 등록 기본값 4를 사용하고 생성 뒤 8로 바꾸던 순서 오류를 수정했다. 이제 현재 Properties params를 `addTimelineEvent`에 전달해 생성과 이동이 같은 geometry로 충돌 판정한다.
- Core 공개 API에 선형 `BeatTween`을 추가했다. Sample Guide Turn은 왼쪽을 생성 위치에 두고 오른쪽을 오른쪽 밖으로, Player Turn은 반대로 0.5박 동안 이동한다.
- Sample 네모 렌더링을 `웃피키.png`, `스피키.png`, `스피키_네르기.png` Sprite 상태로 교체하고 오른쪽 액터를 음수 x scale로 좌우 반전했다.
- RED: Response Delay 8에서 0~4 beat 우클릭 배치 기대가 `expected: 5, actual: 4`로 실패했고 BeatTween API 부재 2건이 실패했다.
- GREEN: 배치 회귀, BeatTween 재시작, Turn 중간값, Sprite 판정 상태와 오른쪽 반전을 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 255 tests`.
- 최종 검증: `git diff --check`와 Core 내부 경로 require 검색은 출력 없음, Project JSON은 `ConvertFrom-Json` 통과, 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 Sprite 전환과 이동은 자동 상태 테스트로 검증했으며 사람이 화면에서 수동 확인하지는 못했다.

## Cue·Response 끝점 1박 폭 (2026-07-27)

- Sample `Cue & Response`의 `geometry.endpointWidthBeats`를 `0.25`에서 `1`로 변경해 파란 Cue와 주황 Response 블록이 각각 Timeline 한 박 너비를 사용한다.
- 끝점 크기는 Project 노드 의미이므로 `projects/sample/project.lua`가 소유한다. Editor는 `EditorSession`이 전달한 값을 사용하며 `EditorLayout`의 기존 `0.25` 하드코딩을 제거했다.
- RED: Sample 등록 geometry 테스트에서 `expected: 1, actual: 0.25` 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 255 tests`.
- 최종 검증: `git diff --check`와 Core 내부 경로 require 검색은 출력 없음, Project JSON은 `ConvertFrom-Json` 통과, 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다.

## Editor Auto Play (2026-07-27)

- Editor Properties에 기존 `Core.UI.ComboBox`를 조합한 Auto Play를 추가했다. 선택지는 `None`, `Good`, `Bad`, `Miss`이고 기본값 `none`은 Stage JSON에서 희소화된다.
- EditorSession은 Play 시 선택값을 TestPlayer에 전달하고, TestPlayer는 Project의 선택적 `setAutoPlay(value)`를 `startStage` 전에 호출한다. 구체적인 판정 시점은 Project가 소유한다.
- Sample은 Good을 목표 beat, Bad를 목표보다 0.2 beat 늦은 BAD 창 안에서 입력하며 Miss는 수동 입력을 막고 기존 TapJudgment의 시간 경과 MISS를 사용한다.
- RED: EditorSettings, Property 순서·ComboBox 선택, TestPlayer 전달과 Sample 판정 테스트에서 9건 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 260 tests`.
- 최종 검증: `git diff --check`와 Editor/Project의 Core 내부 require 검색은 출력 없음, Project JSON은 PowerShell `ConvertFrom-Json` 통과, 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 ComboBox 클릭 화면과 소리·Sprite 판정 연출은 사람이 수동 확인하지 못했다.

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

## Timeline 재생 바 drag와 pan (2026-07-26)

- 재생 바 상단에 14×12 역삼각형 핸들을 추가했다. 일시정지 상태에서 핸들을 좌클릭 드래그하면 `EditorSession:seekTimeline`이 화면 x를 beat로 변환해 Core Transport를 이동한다.
- Timeline 안을 마우스 중간 버튼으로 드래그하면 `EditorSession:panTimeline`이 시작 beat를 이동하며 0 아래로 제한한다. pan과 seek는 Stage 저장 데이터와 dirty 상태를 바꾸지 않는다. `mousereleased`는 Main → Launcher → EditorApp 경로로 전달해 drag 상태를 종료한다.
- RED: 세션 API, 역삼각형 렌더링, 앱 drag와 release 전달 테스트 4곳의 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 198 tests`; `git diff --check` → 출력 없음; 숨김 창 기동 → `LOVE_SMOKE_RUNNING=True`.
- 자동 테스트와 기동 smoke는 완료했지만 실제 마우스로 핸들과 중간 버튼을 드래그하는 화면 확인은 이 환경에서 수행하지 못했다.

## Music 첫 소리 자동 Offset과 Core.UI Button (2026-07-26)

- `editor/project/MusicOnsetDetector.lua`가 LÖVE Decoder로 Music을 4096-byte 청크 단위 분석한다. 채널 평균 10ms RMS가 `0.01` 이상인 창 두 개가 연속되는 첫 위치를 반환하며 Decoder를 즉시 release한다.
- Music Apply 시 기존 Beat 0 Offset이 기본값 `0`인 경우에만 검출값을 자동 적용한다. Mixtape Properties의 Beat 0 Offset Values 오른쪽 `Auto` 버튼은 현재 Offset과 관계없이 다시 분석한다. Music 없음에는 비활성화되고 분석 실패 시 Music은 유지하며 Offset은 보존한 채 오류 모달을 표시한다.
- `Core.UI.Button`이 enabled 상태, 영역 포함과 활성 좌클릭 hit-test를 소유한다. Editor Menu, Dialog 확인·취소 버튼과 새 Auto 버튼이 이를 조합하며 색상·문구·배치는 계속 Editor가 소유한다.
- RED: Core Button 공개·통합, onset 검출, 기본값 보호, Auto 재분석, 실패 모달과 비활성 영역 테스트에서 7건, 편집 중·비활성 Auto 경계 보강에서 3건의 실패를 확인했다.
- GREEN: 정식 전체 suite `PASS: 205 tests`; 실제 `projects/sample/assets/audio/HifumiDaisuki.mp3` smoke는 첫 소리 `0.36`초와 임시 포함 suite `PASS: 206 tests`를 확인한 뒤 임시 검증 코드를 제거했다.
- 최종 검증: `git diff --check` 출력 없음, Project JSON 1개 문법 통과, Editor/Project의 Core 내부 require와 Core Button의 화면 의존 검색 출력 없음, 숨김 창 LÖVE 기동 `LOVE_SMOKE_RUNNING=True`.

## 작은 양수 Offset의 시작부 재탐색 방지 (2026-07-26)

- 재현 조건은 Offset `0 < value < 0.75`, playhead beat 0, Metronome off이며 시작 직후 5번째 박 전까지 되감김에 가까운 소리가 나는 경우다. Offset 0과 0.76 이상은 정상이다.
- 최초 수정에서 첫 drift 검사를 1초 늦추자 증상이 1~4박에서 5~8박으로 그대로 이동했다. 이 결과로 streamed MP3의 작은 양수 seek 뒤 `tell()` 원점을 절대 음악 위치로 비교해 추가 seek하는 경로를 원인으로 확정했다.
- 시간 유예는 제거했다. 첫 drift 검사에서 Transport expected 위치와 Source reported 위치를 각각 기준점으로 기록하고, 이후에는 두 위치 자체가 아니라 각각의 진행 시간 차이만 1초마다 비교한다. 실제 차이가 0.05초를 넘을 때만 seek하며 seek 뒤에는 기준점을 다시 측정한다.
- RED: `seek(0.36)` 뒤 Source가 0 기준으로 진행하는 회귀 테스트에서 정상 진행인데도 `seekCount expected: 1, actual: 2`를 확인했다.
- GREEN: 서로 다른 tell 원점, 실제 drift 보정과 큰 update의 interval remainder 테스트를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 206 tests`; `git diff --check` 출력 없음. 실제 스피커에서 해당 MP3의 되감김 제거 여부는 수동 재확인이 필요하다.
- 최종 검증: Project JSON 1개 문법 통과, Editor/Project의 Core 내부 require 검색 출력 없음, 숨김 창 LÖVE 기동 `LOVE_SMOKE_RUNNING=True`.

## Timeline 빈 첫 칸·재생 바 정렬·Period 눈금 (2026-07-26)

- Timeline은 패딩 없이 다시 전체 너비를 사용한다. 대신 Scale에 따른 한 beat 너비의 첫 칸을 비우고, 그 오른쪽 경계선을 현재 시작 beat 원점으로 사용한다. fractional 시작 beat stripe도 이 원점 왼쪽의 빈 칸을 침범하지 않는다.
- 역삼각형 핸들의 중심을 기준으로 2px 재생 바를 좌우 1px씩 배치해 중심축을 맞췄다. seek와 cursor anchor zoom도 새 beat 원점을 공유한다.
- Timeline 번호는 고정 4박 대신 현재 `Metronome Period`의 배수 beat에 표시되며, 박스 내부가 아니라 해당 경계선 중앙에 정렬된다. `EditorApp` view model이 Stage의 현재 Period를 렌더러에 전달한다.
- 최초 RED에서 좌우 inset, playhead 중심, Period 3 눈금을 기대한 UI 테스트 등 4건이 실패했다. 디자인 피드백 후 전체 너비·빈 첫 칸·경계선 중앙 번호 계약으로 바꾼 RED에서는 5건의 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 207 tests`; `git diff --check` 출력 없음; Project JSON PowerShell 문법 검사 통과; Editor/Project의 Core 내부 require 검색 출력 없음; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`.

## Timeline Snap·edge scroll·단축키 (2026-07-26)

- `editorSettings.snap`을 기본값 `1`, 허용 범위 정수 `1~32`로 추가했다. 기본값은 희소 저장되며 값 4는 가장 가까운 4박 위치에 맞춘다. 순수 `editor/timeline/TimelineSnap` 모듈을 재생 바와 향후 Event 노드 배치가 공유할 반올림 규칙으로 분리했다.
- 일시정지 상태에서 Timeline 상단 32px 전체를 클릭·drag해 재생 바를 이동한다. 역삼각형만 hit-test하던 입력은 제거했으며 본문 좌클릭은 seek하지 않는다.
- drag 중 좌우 끝 32px에 머물면 mouse move 없이도 `update`에서 초당 4박으로 Timeline을 pan한 뒤 현재 Snap 위치로 seek한다.
- `Space`는 Play/Pause를 전환하고 `Home`은 재생 중 Pause 후 beat와 Timeline 시작 위치를 0으로 되돌린다. Dialog·Value 편집 중에는 실행하지 않고 key repeat를 무시한다.
- RED: Settings, 공통 Snap 모듈, snapped seek, 상단 click·drag, 양방향 edge scroll과 단축키 테스트에서 9건 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 210 tests`; `git diff --check` 출력 없음; Project JSON PowerShell 문법 검사 통과; Editor/Project의 Core 내부 require 검색 출력 없음; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`.

## 중간 beat Offset 확인·adaptive scroll·Onset Threshold (2026-07-26)

- Core Transport 회귀 테스트에서 BPM 120, beat 8, Beat 0 Offset `0.5`로 Play할 때 Music seek가 `4.5`초임을 확인했다. 중간 beat 시작에도 `timelineSeconds + beat0Offset`이 정상 적용되어 해당 Core 경로는 수정하지 않고 테스트만 고정했다.
- edge scroll은 기본 초당 8박에 마우스와 재생 바 거리 1박당 초당 8박을 더하며 최대 초당 64박으로 제한한다. 좌우 이동과 먼 마우스가 더 빠른 동작을 테스트한다.
- Play/Pause 단축키를 `Space`에서 `P`로 바꾸고 `Ctrl+S` Save를 추가했다. `Home`은 유지하며 Dialog·Value 편집과 key repeat 차단도 유지한다.
- Snap을 Editor Properties 첫 행으로 옮겼다. 최종 순서는 Snap, Scale, Playback Rate, Metronome, Metronome Period, Onset Threshold다.
- 기존 Auto onset은 고정 RMS `0.01` 이상을 사용했다. 이를 `editorSettings.onsetThreshold` 기본값 `0`, 범위 `0~1`로 바꾸고, 연속된 두 10ms 창의 RMS가 threshold보다 큰 첫 위치를 사용한다. 기본값 0은 완전한 무음을 건너뛴다.
- RED: Offset 중간 시작 테스트는 즉시 통과해 버그를 재현하지 못했다. Settings, Property 순서, threshold 전달·검출, adaptive scroll과 단축키 변경은 10건 실패로 재현했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 212 tests`; `git diff --check` 출력 없음; Project JSON PowerShell 문법 검사 통과; Editor/Project의 Core 내부 require 검색 출력 없음; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`.

## Onset Threshold UI 위치 조정 (2026-07-26)

- Onset Threshold를 Editor Properties에서 제거하고 Mixtape Properties의 Beat 0 Offset 바로 아래에 배치했다. 최종 Mixtape 순서는 Music, Volume, Beat 0 Offset, Onset Threshold, BPM이다.
- 데이터 소유권은 계속 `editorSettings.onsetThreshold`에 둔다. `PropertyCatalog`의 선택적 `groupId`가 화면상 그룹과 실제 설정 그룹을 분리하며 Values 조회·편집·커서 렌더링이 이 메타데이터를 공통 사용한다.
- RED: Property 순서·소유 그룹·인라인 편집 테스트 3건 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 213 tests`; `git diff --check` 출력 없음; Project JSON 문법 검사와 숨김 창 기동을 통과했다.

## 1초 미만 Music stream seek 중복 적용 수정 (2026-07-26)

- `HifumiDaisuki.mp3`의 44.1kHz decoded PCM은 `0.357324`초까지 실제로 0이며 Threshold 0의 10ms 창 검출 결과 `0.35`초는 정상이다. 사용자가 수동으로 맞춘 `0.20~0.22`초와의 차이는 Auto 분석 해상도가 원인이 아니었다.
- LÖVE 11.5 실제 Source smoke에서 정지된 stream에 `seek(0.2)` 후 `play()`하면 즉시 위치가 `0.4`로, `seek(0.35)`는 `0.699955`로 중복 적용됐다. 같은 현상은 MP3뿐 아니라 임시 WAV stream에서도 재현됐고 static Source에서는 재현되지 않았다.
- `MusicPlayback:play`는 pitch를 설정하고 Source를 먼저 재생한 뒤 활성 Source를 요청 위치로 seek한다. 실제 MP3 smoke에서 요청 `0.2`는 `0.2`, 요청 `0.35`는 `0.349977`로 유지됐다.
- RED: stream 호출 순서를 고정한 회귀 테스트에서 `expected: pitch`, `actual: seek` 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 214 tests`; `git diff --check` 출력 없음; Project JSON 1개 문법 검사와 Core 내부 require 경계 검색 통과; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`.

## Onset Threshold 권장 기본값 복원 (2026-07-26)

- `editorSettings.onsetThreshold` 기본값을 일반 음악의 작은 압축 노이즈를 제외하는 권장값 `0.01`로 변경했다. `0`은 계속 유효한 명시값이며 기본값과 다르므로 Stage compact 시 보존된다.
- 아직 커밋되지 않은 Onset Threshold 기능 범위 안에서 기본값을 확정했으므로 schemaVersion은 계속 2를 사용한다. Stage 형식 예시는 기본값 희소화가 드러나도록 명시값을 `0.02`로 바꿨다.
- RED: 기본 resolve와 compact 기대값 변경 후 `expected: 0.01, actual: 0` 및 기본값 compact 실패 2건을 확인했다. 구현 변경 뒤 Mixtape Properties 기본 표시의 `expected: 0, actual: 0.01` 테스트를 새 계약에 맞게 갱신했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 214 tests`; `git diff --check` 출력 없음; Project JSON 1개 문법 검사와 Core 내부 require 경계 검색 통과; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`.

## 에디터 재생 단축키 변경 (2026-07-26)

- Play/Pause 단축키를 `P`에서 `F`로, beat 0과 Timeline 시작 위치 초기화 단축키를 `Home`에서 `R`로 변경했다. `Ctrl+S`, Dialog·Value 편집 중 차단과 key repeat 차단 동작은 유지한다.
- RED: 단축키 통합 테스트를 `F`·`R` 기대값으로 먼저 변경한 뒤 Play가 시작되지 않아 `expected: true`, `actual: false`로 실패함을 확인했다.
- GREEN: `love . --test` → `PASS: 214 tests`; `git diff --check`, 이전 단축키 구현·현재 문서 잔존 검색과 Editor/Project의 Core 내부 require 검색은 출력 없음; Project JSON 문법 검사 통과.

## Editor 상단 고정 높이와 Core.UI ScrollArea (2026-07-26)

- 상단 패널 높이는 `EditorMenu.getRequiredHeight()`에 세 행의 여유를 더한 헤더 32px + 10행 × 24px = 272px로 고정했다. Timeline은 y=272부터 창 아래의 남은 영역을 사용한다. Categories에는 스크롤 확인용 `Debug Category 1~11`을 추가해 Global 포함 12행이 표시된다.
- `Core.UI.ScrollArea`가 content/viewport 크기, wheel offset, 범위 제한과 조건부 scrollbar thumb geometry를 소유한다. Categories와 Events는 독립 인스턴스를, Properties와 Values는 같은 인스턴스를 사용한다. Editor는 scissor, 색상과 scrollbar 렌더링만 담당하며 내용이 넘칠 때만 Values 오른쪽 등에 얇은 scrollbar를 표시한다.
- `AGENTS.md`에 UI 구현 전 Core 공개 API 검색, 중복 동작 금지, 공통 Base를 Core 테스트와 먼저 추가한 뒤 Editor·Project가 조합한다는 지침을 명시했다. LOVELi와 LikeliHUD 도입도 검토했으나 현재 예상 UI 규모와 기존 테스트·Timeline 커스텀 범위를 고려해 외부 UI 의존성은 추가하지 않았다.
- RED: 고정 높이 기대값과 ScrollArea 공개·동작 테스트에서 `expected: 200, actual: 368`, `Core.UI.ScrollArea` nil 등 4건 실패를 확인했다. 세 행 확장과 Categories 더미 후속 RED에서는 `expected: 272, actual: 200`, categories nil 등 3건 실패를 확인했다.
- GREEN: Core ScrollArea 단위 테스트, 조건부 scrollbar 렌더링, 패널 wheel 라우팅, Categories 더미 행 실제 스크롤과 Properties/Values 공유 테스트를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 219 tests`.
- 최종 검증: `git diff --check`, Editor/Project의 Core 내부 require와 Core UI의 Editor·Project·graphics 의존 검색은 출력 없음; Project JSON 1개가 PowerShell `ConvertFrom-Json`을 통과; 숨김 창 LÖVE 기동은 `LOVE_SMOKE_RUNNING=True`. 실제 휠 조작과 scrollbar 시각 상태의 사람 수동 확인은 수행하지 못했다.

## Categories 디버그 정리와 FHD 기본 해상도 (2026-07-26)

- 스크롤 확인용 `Debug Category 1~11`과 생성 상수를 제거해 Categories는 다시 실제 `Global` 한 행만 제공한다. 공통 ScrollArea와 overflow 테스트는 유지한다.
- `conf.lua`의 기본 창 크기와 `EditorApp`의 최초 입력용 layout을 1920×1080 FHD로 맞췄다. 창은 계속 resizable이며 최소 크기는 800×600이다.
- RED: Categories 정리와 FHD 계약 테스트에서 `expected: 1, actual: 12`, `expected: 1920, actual: 1200` 두 건의 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 220 tests`. `git diff --check`와 숨김 창 FHD 기동은 최종 검증한다.

## 상단 15행과 최소 720p 창 크기 (2026-07-26)

- 상단 패널을 헤더 32px + 콘텐츠 15행 × 24px = 392px로 확장했다. Timeline은 y=392부터 남은 높이를 사용한다.
- 기본 창 크기 1920×1080과 resizable 설정은 유지하고 최소 크기를 1280×720으로 변경했다. 종횡비는 제한하지 않는다.
- RED: 높이와 최소 창 크기 테스트에서 `expected: 392, actual: 272`, `expected: 1280, actual: 800` 등 3건 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 220 tests`. 최종 정적 검사와 기동 smoke를 수행한다.

## Game Manager Timeline Event (2026-07-27)

- `Game Manager` Category에 보라색 `End`와 청록색 `Set Input Enabled`를 추가했다. 충돌 preview 전용 빨간색과 기본색을 구분했다. 입력 상태를 지정하는 Event이므로 요청안의 `Toggle Input`/`Toggle` 대신 `Set Input Enabled`/`Enabled`로 명명했다.
- Event 행 선택 후 Timeline 본문 우클릭으로 현재 Snap beat와 Track에 노드를 배치한다. 배치 후보 영역이 기존 노드와 겹치면 생성하지 않고 우상단에 3초 error toast를 표시한다. toast는 최신순 최대 5개 stack이며 각각 독립적으로 만료된다. 일반 클릭은 단일 선택, Ctrl+클릭은 다중 선택 추가·해제, 빈 배경 drag는 교차 marquee 선택, Ctrl+drag는 기존 선택 추가를 수행한다. 선택 노드 drag는 전체 선택의 상대 beat·Track 간격을 유지한다. 이동 중에는 반투명 흰색이고 가변 beat 폭 영역 충돌 시 이동·고정 양쪽이 빨간색이 되며, 충돌 상태로 놓으면 Stage를 바꾸지 않고 원위치로 돌아가며 이동 실패 error toast를 stack에 추가한다. Delete는 선택 노드를 모두 삭제한다. `Set Input Enabled`를 Events에서 선택하면 Properties/Values에서 새 노드의 Enabled 값을 먼저 설정하며, 더블클릭 모달은 배치된 노드별 값을 수정한다. 배치 전 선택값 변경은 Stage dirty 상태를 바꾸지 않는다.
- Editor Properties의 Track 기본값은 10, 허용 범위는 정수 `1~32`이며 기본값은 Stage JSON에서 희소화된다. 관리 노드는 왼쪽을 startBeat 선에 맞춘 `0.25 beat` 폭, 게임플레이 노드는 명시된 폭·길이 또는 기본 `1 beat`를 사용한다. `TimelineEventGeometry`가 렌더링과 충돌 판정 폭을 함께 소유한다. 기존 Pattern·Note Event의 생략 Track은 1로 해석한다.
- EditorSession 입력 상태는 Play마다 기본 true에서 기준 beat 이전의 마지막 `Set Input Enabled` 값으로 복원되고 재생 중 노드 도달 시 갱신된다. `End`는 Stage에 하나만 허용하고 두 번째 배치는 error toast로 거부한다. End 도달 시 preview 구성 요소를 정리하고 정확한 End beat로 이동한다. End가 없고 Music이 있으면 Transport의 정확한 duration 위치에서 자동 종료하고 정보 toast를 추가한다. 실제 Project 입력 전달은 아직 연결하지 않았다.
- Stage schemaVersion은 2를 유지했다. 새 필드와 Event type은 기존 필드 의미를 바꾸지 않고 미구현 Timeline Event 계약을 확장한 것으로 `docs/STAGE_FORMAT.md`의 버전 정책에 기록했다.
- RED: Track 설정, Stage Event CRUD·검증, Session 실행, Category·배치·drag·속성 모달과 렌더링 테스트에서 9건 실패를 확인했다. 입력 상태 실행 테스트는 `isInputEnabled` 부재 1건으로 실패했다.
- 후속 RED: Events에서 `Set Input Enabled` 선택 직후 Properties가 비어 있어 `viewModel.properties[1]` 접근이 실패함을 확인했다. 선택·삭제 후속 테스트에서는 `deleteEvents` API와 `selectedTimelineEventIds`가 없어 3건 실패했다. Geometry·marquee·그룹 drag RED에서는 Geometry 모듈 부재 2건과 marquee 선택 실패 1건을 확인했다. 우클릭 충돌 배치·toast RED에서는 겹친 노드가 생성되고 toast 렌더링이 없어 3건 실패했다. stack·이동 실패 toast 후속 RED에서는 단일 `toast` 계약 때문에 3건 실패했다. 단일 End·Music fallback RED에서는 중복 End 승인, Music 종료 상태 API 부재와 자동 종료 미동작 등 6건 실패했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 242 tests`; `git diff --check`와 Core 내부 require 경계 검색은 출력 없음; Project JSON은 PowerShell `ConvertFrom-Json`을 통과했다. 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다.
- 실제 마우스 우클릭·drag·더블클릭과 색상은 자동 테스트와 기동 smoke로 검증했으며 사람이 화면에서 수동 확인하지는 못했다.

## Timeline 기준 바와 재생 위치 바 분리 (2026-07-26)

- Timeline 클릭으로 정한 주황색 기준 바의 beat를 Transport의 현재 beat와 분리했다. Play 중에는 하늘색 재생 위치 바가 시간에 따라 이동하고 Pause하면 재생 위치 바만 숨긴다.
- Pause 뒤 다시 Play하면 직전 재생 위치를 이어가지 않고 보존된 기준 beat로 Transport를 seek한 뒤 Project preview, Music과 Metronome을 새로 시작한다. Core `PlaybackTransport`의 일반 pause/resume 계약은 변경하지 않았다.
- RED: 기준 beat API, 두 바 렌더링과 Pause 후 재시작 통합 기대에서 3개 테스트 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 220 tests`.
- 최종 검증: `git diff --check`와 Editor/Project의 Core 내부 require 검색은 출력 없음; Project JSON 문법 검사 `JSON_OK`; 숨김 창 기동 `LOVE_SMOKE_RUNNING=True`. 두 바의 실제 색상과 클릭·Pause·재시작 동작은 사람이 화면에서 수동 확인하지 못했다.

## Timeline 노드 이름 기본 표시 (2026-07-26)

- Timeline Event 이름을 노드 박스 안쪽에서 항상 렌더링한다. 이름이 박스 폭보다 길면 scissor로 넘는 부분을 자르고, hover한 노드는 같은 시작 위치에서 scissor 없이 전체 이름을 최상단에 표시한다.
- RED: 기존 hover 이름이 박스 오른쪽에서 시작해 내부 시작 위치 기대가 `expected: 228`, `actual: 236`으로 실패함을 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 255 tests`; `git diff --check` → 출력 없음; 숨김 창 기동 → `LOVE_SMOKE_RUNNING=True`. 실제 hover 화면은 사람이 수동 확인하지 못했다.

## Editor Play Preview 종횡비 (2026-07-27)

- Global > Editor Properties에 `Preview Aspect Width`, `Preview Aspect Height`를 추가했다. 기본값은 각각 `16`, `9`이며 0보다 큰 유한 수만 허용한다. 기본값은 Stage JSON에서 희소화되고 변경값은 `editorSettings.previewAspectWidth`, `previewAspectHeight`에 저장된다.
- Play 중 Project Canvas는 설정 비율을 유지하면서 기존 Properties·Values preview 영역 안에 들어가는 최대 정수 픽셀 크기로 계산되고 가로·세로 여백의 중앙에 표시된다.
- schemaVersion은 2를 유지했다. 두 필드는 실제 게임 규칙을 바꾸지 않는 선택적 Editor 전용 설정 확장이다.
- RED: 설정 기본값·검증, Property 목록·view model, preview 맞춤 테스트를 추가한 뒤 필드 부재와 기존 전체 영역 전달로 5건 실패했다.
- GREEN 및 최종 검증: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 256 tests`; `git diff --check`와 Editor/Project Core 내부 require 검색은 출력 없음; Project JSON은 PowerShell `ConvertFrom-Json` 통과; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다.
- 종횡비에 따른 Canvas 좌우·상하 중앙 맞춤은 자동 테스트로 검증했다. 실제 화면의 여백과 크기는 사람이 수동 확인하지 못했다.

## Cue & Response 연결 영역 중립색 (2026-07-27)

- Sample `Cue & Response`의 기본색을 녹색 `{ 0.3, 0.85, 0.45, 1 }`에서 중립적인 밝은 회색 `{ 0.92, 0.94, 0.97, 1 }`로 변경했다. 기존 Editor connector 렌더링을 그대로 사용하므로 내부 채움은 최종 18% alpha, 1px 외곽선은 90% alpha다.
- 파란 Cue와 주황 Response 끝점, 선택 흰색과 충돌 빨간색은 변경하지 않았다. 연결부만 무채색 계열이 되어 아래 Timeline 색의 색조를 덜 왜곡한다.
- RED: Sample 등록 색상 기대를 먼저 바꾼 뒤 `expected: 0.92`, `actual: 0.3` 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 256 tests`; `git diff --check` → 출력 없음; 숨김 창 기동 → `LOVE_SMOKE_RUNNING=True`. 실제 화면 색은 사람이 수동 확인하지 못했다.

## Timeline Event 이름 윤곽선 (2026-07-27)

- 일반 노드 내부 이름과 hover 전체 이름 모두에 8방향 1px 윤곽선을 추가했다. 윤곽선은 거의 검정 `{ 0.05, 0.05, 0.06, 0.9 }`, 본문은 기존 `{ 0.95, 0.95, 0.97, 1 }`을 사용한다.
- 일반 이름의 기존 노드 영역 scissor는 윤곽선에도 적용해 좁은 노드 밖으로 새지 않으며, hover 이름은 기존처럼 전체를 표시한다.
- RED: 일반·hover 이름별 윤곽선 8회와 본문 색을 기대한 UI 테스트에서 `expected: 8`, `actual: 0` 실패를 확인했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 256 tests`; `git diff --check` → 출력 없음; 숨김 창 기동 → `LOVE_SMOKE_RUNNING=True`. 실제 글자 가독성은 사람이 수동 확인하지 못했다.

## Timeline Event 셀 기반 Snap (2026-07-27)

- 재생 바는 기존처럼 가장 가까운 Snap 간격선에 맞춘다. Timeline Event 생성과 drag는 커서 beat가 포함된 Snap 크기 셀의 시작점에 맞춘다. Snap 1은 한 박 셀, Snap 4는 네 박 셀을 사용한다.
- `TimelineSnap.snapEventBeat`를 생성·drag preview·단일 이동 API가 공유해 노드 스냅 규칙을 한 곳에서 관리한다.
- RED: 셀 스냅 API 부재와 Snap 4의 11.9 beat drag가 12로 반올림되는 통합 테스트 실패 2건을 확인했다.
- GREEN 및 최종 검증: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 261 tests`; `git diff --check`와 Editor/Project의 Core 내부 require 검색은 출력 없음; Project JSON은 PowerShell `ConvertFrom-Json` 통과; 숨김 창 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 마우스 조작 화면은 사람이 수동 확인하지 못했다.

## Project Music·SFX 폴더 분리 (2026-07-27)

- Project 오디오를 `assets/audio/music/`과 `assets/audio/sfx/`로 구분했다. 에디터 `MusicCatalog`는 `music/`만 재귀 검색하므로 SFX는 Music 선택 목록에 포함되지 않는다.
- Sample 음악과 Stage 참조를 `assets/audio/music/HifumiDaisuki.mp3`로 이동하고, SFX 폴더 안내와 README·아키텍처·워크플로우·Stage 형식·로드맵을 갱신했다.
- 기존 schemaVersion 2 Stage 호환성을 위해 `MixtapeSettings`의 `assets/audio/` 경로 검증은 유지하고, 새 에디터 검색·문서·Sample 경로만 `assets/audio/music/`을 사용한다.
- RED: MusicCatalog 테스트의 검색 루트와 기대 경로를 먼저 `assets/audio/music/`으로 변경해 전체 suite에서 2건 실패를 확인했다.
- GREEN 및 최종 검증: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 261 tests`; Project JSON은 PowerShell `ConvertFrom-Json` 통과; `git diff --check` 출력 없음. 기존 사용자 변경인 `projects/sample/assets/audio/HifumiDaisuki copy.mp3` 삭제는 건드리지 않았다.

## 빈 Project 생성기 (2026-07-27)

- `python tools/create_project.py <projectId> "<title>"` 명령을 추가했다. 생성기는 현재 `core/init.lua`의 API 버전을 읽고 `project.lua`, `game/Game.lua`, `stages/`, `assets/audio/music/`, `assets/audio/sfx/`, `assets/image/`의 실행 가능한 최소 구조를 만든다.
- 안전한 소문자 ID와 Windows 예약 이름을 검사하고 기존 Project를 덮어쓰지 않는다. 임시 폴더에 전체 템플릿을 쓴 뒤 최종 Project 경로로 이동하며 실패 시 임시 파일을 정리한다.
- `AGENTS.md`에 빈 Project 필수 구조나 진입 계약 변경 시 생성기, Python 테스트와 워크플로우 문서를 같은 작업에서 갱신하는 지침을 추가했다. 생성기는 Sample 게임 규칙을 복사하지 않는다.
- RED: `tests_python/test_create_project.py`를 먼저 추가한 뒤 `ModuleNotFoundError: No module named 'tools'` 실패를 확인했다.
- GREEN: `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`; 생성 결과를 별도 LÖVE 앱에서 `ProjectLoader.loadProject/createGame`으로 불러와 `PASS: generated Project load and create`를 확인했다.
- 전체 회귀 검증: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 261 tests`; `python -m py_compile tools/create_project.py tests_python/test_create_project.py` 통과. 최종 `git diff --check`와 작업 트리 상태는 완료 보고 전에 다시 확인한다.

## Rhythm Dotgeo Stage 선택 화면 (2026-07-27)

- Launcher에 `2: Rhythm Dotgeo` 진입을 추가했다. Project를 열면 `StageStore`가 검증한 `projects/rhythm_dotgeo/stages/*.json`을 이름 목록으로 표시하고, `Core.UI.Button` 기반 항목을 클릭하면 JSON을 다시 읽어 `startStage(stage, 0)`로 시작한다.
- `ProjectLoader.createGame(project, options?)`가 게임 생성자의 두 번째 인자로 StageStore를 주입한다. Project는 `require("core")`만 사용하고 Editor 내부 모듈이나 JSON 라이브러리를 직접 불러오지 않는다. Sample은 추가 인자를 무시해 기존 직접 실행 동작을 유지한다.
- 게임 진입 계약 변경에 맞춰 빈 Project 생성기의 `Game.new(project, options)`도 `options.stageStore`를 보관하도록 갱신했다. Python 기대값을 먼저 바꿔 기존 `Game.new(project)` 때문에 1건 실패한 뒤 템플릿을 수정했다.
- RED: StageStore 주입, 목록 view model·렌더링, 클릭 시작과 Launcher `2` 진입 테스트를 먼저 추가해 `4 test(s)` 실패를 확인했다.
- GREEN: fake StageStore 단위 경로와 실제 `speaki_song.json` 통합 경로를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 266 tests`; 생성기 회귀는 `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`.
- 검증: `speaki_song.json`은 PowerShell `ConvertFrom-Json` 통과, Rhythm Dotgeo의 Core 내부·Editor·Launcher·vendor 직접 require 검색 출력 없음, 숨김 LÖVE 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 마우스 클릭 화면은 자동 상태·렌더링 테스트로 검증했으며 사람이 수동 확인하지는 못했다.

## Rhythm 독립 재생·Core StageRuntime·Sample Event 분리 (2026-07-27)

- 이전 Rhythm Stage 선택 구현은 `startStage`와 화면 전환만 수행해 Music을 재생하지 않는 불완전한 상태였다. 독립 실행 클릭 시 Stage BPM과 resolved Mixtape(Music, Volume, Beat 0 Offset)를 Core `MusicPlayback`·`PlaybackTransport`에 연결하고 rate `1.0`으로 재생하며 update에서 Transport beat를 StageRuntime에 전달하도록 수정했다.
- Core 공개 API에 `StageRuntime`을 추가했다. Stage Event를 beat와 원래 배열 순서로 한 번씩 occurrence로 전개하고, 중간 beat 시작의 `catchUp`, `Set Input Enabled`, 최초 `End` beat와 종료 상태를 공통 처리한다. EditorSession, Sample과 Rhythm Dotgeo가 이 API를 사용해 Event crossing과 Game Manager 처리를 중복 구현하지 않는다.
- Rhythm Dotgeo도 `game/StageSelect.lua`가 목록 UI를, `game/StagePlayback.lua`가 Music·Transport·StageRuntime 조합을, `game/Game.lua`가 화면 전환을 맡도록 분리했다.
- Sample Project 전용 Event 로직을 `game/events/SampleGameplay/SpawnActors.lua`, `GuideTurn.lua`, `PlayerTurn.lua`, `CueResponse.lua`로 분리했다. `SampleGame.lua`는 handler map, Core 런타임·판정 조합과 화면 상태 연결을 맡고 각 Event 파일은 Sprite/SFX/이동 관련 Project 상태만 바꾼다.
- Launcher가 Project 게임을 만들 때 `standalone = true`를 전달하고 Project 이탈 시 선택적 `stop()`을 호출해 Music을 정리한다. Editor TestPlayer 생성 경로는 standalone이 아니므로 Editor Transport와 Project Music이 중복 재생되지 않는다. TestPlayer는 `startStage`의 `nil, error` 반환도 실패로 전달해 정의되지 않은 Project Event 오류를 숨기지 않는다.
- 빈 Project 생성기는 `Core.StageRuntime`을 기본 조합하고 `game/events/README.md`에 `<CategoryName>/<EventName>.lua` 규칙을 안내한다. Python 기대값을 먼저 변경해 Event README와 StageRuntime 조합 부재 실패를 확인한 뒤 템플릿을 갱신했다.
- RED: Core StageRuntime 4건과 Rhythm Music/beat 1건을 먼저 추가해 `5 test(s)` 실패를 확인했다. 생성기에는 Event 폴더 및 StageRuntime 기대를 각각 먼저 추가해 실패를 확인했다.
- GREEN: Core occurrence/catch-up/End/input, Editor 회귀, Sample 연출 모듈, Rhythm Music·관리 노드와 Launcher 정리를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 274 tests`; `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`.
- 생성기 smoke: 새 템플릿으로 임시 Project를 만든 뒤 LÖVE에서 로드하고 Set Input Enabled와 beat 갱신을 실행해 `PASS: generated Project StageRuntime`을 확인한 후 삭제했다.
- 실제 MP3 smoke: 별도 임시 LÖVE 앱에서 실제 `speaki_song.json`을 클릭하고 `Moai_Doo-Wop.mp3` stream Source의 `isPlaying()`과 beat 진행을 확인해 `PASS: Rhythm audio playing, beat=1.267`을 얻은 뒤 임시 앱을 삭제했다. 사람이 곡을 끝까지 청취하거나 실제 창에서 클릭하지는 못했다.

## Project Category·Actor 소유권 지침 (2026-07-27)

- Project 기능 경계를 `game/events/<CategoryName>/`이 아니라 `game/<CategoryName>/`으로 정했다. Category의 `Definition.lua`는 Editor용 순수 등록 데이터, `Runtime.lua`는 Core occurrence와 Actor·리소스 조립, Event 파일은 Project 객체 조율을 소유한다.
- `Actors.lua`를 강제하지 않는다. 같은 행동·상태·리소스면 Actor 모듈 하나의 여러 인스턴스를 사용하고, 독립적으로 변경되면 `GuideActor.lua`, `PlayerActor.lua`처럼 역할별로 분리한다. 위치가 정체성이 아닌 한 Left/Right보다 역할 이름을 우선한다.
- Actor 전용 Sprite/SFX는 Actor가 직접 소유하거나 전용 리소스 객체를 주입받고, 여러 Actor가 실제 파일과 수명을 공유할 때만 Category 범위의 Sprite·Sound 캐시를 사용한다. Event 파일은 저수준 asset 로딩을 중복하지 않는다.
- Project는 Stage JSON decode·검증과 Event crossing을 구현하지 않고 Core 공개 Stage API를 조합한다. Launcher·Editor는 Project 경로와 파일 접근만 조립한다는 목표 경계를 `AGENTS.md`, 아키텍처, 워크플로우와 노드 튜토리얼에 기록했다.
- 빈 Project 생성기의 `game/events/README.md`를 `game/README.md` Category 안내로 바꿨다. Python 기대값을 먼저 변경해 `game/README.md` 부재 실패를 확인한 뒤 템플릿을 갱신했다.
- 현재 Sample 구현은 아직 `game/events/SampleGameplay/`, `SampleSounds.lua`, `SampleSprites.lua`에 있으므로 이번 지침 작성에서 이동하지 않았다. 실제 `game/SampleGameplay/` 개편과 Actor 책임 분리는 Roadmap의 후속 작업으로 남겼다.
- 검증: `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`; `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 274 tests`; `python -m py_compile tools/create_project.py tests_python/test_create_project.py`와 `git diff --check` 통과.

## 폴더 단위 Project Category 자동 등록 (2026-07-27)

- Core 공개 API에 `ProjectCategories.discover/createHost`를 추가했다. `discover`는 `game/` 바로 아래에서 `Definition.lua`와 `Runtime.lua`가 모두 있는 폴더만 찾아 Definition을 manifest Category로 등록하며 Runtime·Actor·asset은 Editor 탐색 시 로드하지 않는다. `createHost`는 게임 생성 시 Runtime을 만들고 lifecycle과 Event occurrence를 Event ID의 소유 Category로 전달한다.
- Sample manifest는 Category 목록을 하드코딩하지 않고 `projects/sample/game`을 자동 탐색한다. `SampleGame.lua`도 Category 이름과 Event handler를 알지 않으며 Core StageRuntime occurrence와 Category Host의 start/update/input/draw만 조립한다. 따라서 `game/NewGameSample/Definition.lua`와 `Runtime.lua`를 추가할 때 기존 manifest와 Game을 수정하지 않는다.
- SampleGameplay를 `game/SampleGameplay/`로 이동했다. 순수 등록은 `Definition.lua`, Category 상태·판정·Actor 조립은 `Runtime.lua`, 노드별 의도는 `SpawnActors.lua`, `GuideTurn.lua`, `PlayerTurn.lua`, `CueResponse.lua`가 소유한다. 기존 `game/events/`, `SampleSounds.lua`, `SampleSprites.lua`는 제거했다.
- Guide와 Player는 현재 행동·Sprite 규칙이 같으므로 주석이 있는 `SampleActor.lua` 두 인스턴스로 구성했다. 각 Actor의 movement·spawn·flash·render 상태는 Actor가 소유하고, 실제 공유 리소스인 `Sprites.lua`와 상호작용 공용 `Sounds.lua`는 Category에서 한 번 만들어 주입한다. 역할별 변경 이유가 생기면 GuideActor·PlayerActor로 분리한다.
- 생성기 manifest와 Game도 같은 자동 discovery·Host 위임 구조를 사용하고 `game/README.md`에서 폴더만으로 Category를 추가하는 방법을 안내한다. 생성기 기대값을 먼저 변경해 자동 discovery와 Host·Auto Play 위임 부재 실패를 확인한 뒤 템플릿을 갱신했다.
- RED: Core discovery와 Runtime routing 테스트를 먼저 추가해 `Core.ProjectCategories` 부재 2건을 확인했다. Sample 이동 직후 기존 테스트가 Game 내부 상태를 직접 보던 4건 실패를 Category Runtime·Actor 경계 기대값으로 전환했다.
- GREEN: `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 276 tests`; `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`; Python compile과 `git diff --check` 통과. Project JSON 전체는 PowerShell `ConvertFrom-Json` 통과, 숨김 LÖVE 기동은 `LOVE_SMOKE_RUNNING=True`였다.
- 폴더-only smoke: 생성기로 만든 임시 Project에 `game/NewGameSample/Definition.lua`와 `Runtime.lua`만 추가하고 기존 manifest·Game을 수정하지 않은 채 LÖVE에서 Editor 등록 데이터와 Runtime Event 처리를 확인해 `PASS: folder-only Category auto registration and runtime`을 얻은 뒤 임시 Project를 삭제했다.

## Rhythm Dotgeo 스피키송 Category (2026-07-29)

- `projects/rhythm_dotgeo/game/SpeakiSong/`을 추가했다. Editor에는 `스피키송 > 스피키송`, `흐에`, `네르지마세요`, `좌피키`, `우피키`가 자동 등록된다. Spawn은 `ghost_basic.png` 배경과 좌피키·좌우 반전 우피키를 만들고, Turn은 0.5박 동안 한 Actor를 원위치로, 반대 Actor를 화면 밖으로 이동한다.
- `흐에`는 `Response Delay (Beats)`와 `Long Note Length (Beats)`를 사용한다. 좌피키가 `speaki_uu.png`에서 `speaki_ner.png`로 좌하단 압박되는 가이드를 보인 뒤 우피키가 Space 누름·뗌으로 응답한다. `네르지마세요`는 같은 Response Delay 뒤 `speaki_uu.png`로 우하단 왕복·진동한다.
- Core 공개 API에 `LongNoteJudgment`를 추가했다. 시작과 종료를 각각 GOOD/BAD로 판정하고 시작 누락, 종료 누락과 판정창 밖 release를 MISS로 처리한다. Main·Launcher·Editor TestPlayer·Category Host에 `keyreleased` 전달을 연결했다.
- Rhythm Dotgeo manifest와 Game은 Category 자동 발견·Host를 조합한다. 이미지 캐시는 Category에서 한 번 만들며 향후 SFX는 `SpeakiSong/Sounds.lua`가 `assets/audio/sfx` Source를 소유하도록 경계를 남겼다.
- 위치·크기·이동 조절 상수는 `SpeakiActor.lua` 상단에 설명 주석과 함께 모았다.
- RED: LongNoteJudgment 부재 3건, 스피키송 등록 부재와 미등록 Event 실행 2건으로 `FAIL: 5 test(s)`를 확인했다.
- GREEN: Core Long Note, 스피키송 등록·판정·연출·턴, Space release 전달과 우피키 반전을 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 282 tests`; Python 생성기 회귀는 `Ran 5 tests`, `OK`였다.
- 최종 검증: `git diff --check`는 CRLF 안내 외 오류 없음, Project JSON 전체는 PowerShell `ConvertFrom-Json` 통과, Project의 Core 내부·Editor·Launcher 직접 require 검색 출력 없음, 숨김 LÖVE 기동은 `LOVE_SMOKE_RUNNING=True`였다. 실제 애니메이션 속도와 배치는 사람이 화면에서 조절 확인해야 한다.

## D2Coding 한글 기본 폰트 (2026-07-29)

- `launcher/AppFont.lua`가 앱 시작 시 `assets/fonts/D2Coding-Ver1.3.3-20260725-all.ttc`를 14px로 한 번 로드해 LÖVE 기본 폰트로 설정한다. Launcher, Editor와 Project가 같은 기본 Font를 사용하므로 스피키송 등 한글 이름이 깨지지 않는다.
- RED: 폰트 경로·크기·적용 계약 테스트가 `module 'launcher.AppFont' not found`로 1건 실패함을 확인했다.
- GREEN: fake graphics 적용 계약과 실제 TTC의 `스피키송`, `흐에`, `네르지마세요` glyph 보유 검사를 포함해 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 283 tests`.
- 실제 앱의 TTC 로드를 포함한 숨김 LÖVE 기동은 `LOVE_FONT_SMOKE_RUNNING=True`였다. 실제 글자 크기와 가독성은 사람이 화면에서 최종 확인해야 한다.
