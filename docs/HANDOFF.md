# 인수인계

## 현재 상태

LÖVE2D 11.5 Launcher에서 Sample Project와 Stage 에디터를 열 수 있다. 에디터는 schemaVersion 2 Stage를 만들고 열고 원자 저장하며, Project 음악을 Core `PlaybackTransport`에 연결해 Project Canvas와 함께 미리 재생한다.

`Editor Properties`는 Snap, Scale, Playback Rate, Metronome, Metronome Period를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, Onset Threshold, BPM을 순서대로 제공한다. 숫자 직접 편집, boolean 전환, Project Music 선택 모달, cursor anchor wheel zoom, 상단 click·adaptive edge-scroll 재생 바 drag, F·Ctrl+S·R 단축키, 재생 오류 정리와 beat rollback이 연결되었다. 기본값은 Stage JSON에서 희소화된다.

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
