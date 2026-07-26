# 아키텍처

## 의존 방향

```text
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
        ↘ ProjectLoader.createGame → Editor TestPlayer
Editor → Project Manifest·assets/audio
```

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못하며, `editor/`와 `projects/`는 `require("core")` 공개 진입점만 사용한다. 스타일 독립적인 공통 UI 동작은 Core가 제공하고 Editor와 Project가 각자 스타일·배치와 도메인 동작을 조합한다. Project 상대 Music 경로를 실제 경로로 바꾸고 Editor 전용 설정을 적용하는 책임은 Editor에 있다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. `CORE_API_VERSION`, `JudgmentResult`, `PlaybackClock`과 함께 `TapJudgment`, `BeatTween`, `ProjectEvents`, `MixtapeSettings`, `TempoMap`, `MusicPlayback`, `PlaybackTransport`, `UI`를 공개한다.

- `MixtapeSettings`는 Music, Volume과 Beat 0 Offset을 검증하고 기본값을 해석하거나 희소 객체로 줄인다.
- `TempoMap`은 양수 유한 BPM 하나를 소유하고 beat와 논리 seconds를 상호 변환한다. Stage 형식과 독립적이므로 이후 BPM 변화 구조를 이 경계 뒤에서 확장할 수 있다.
- `MusicPlayback`은 LÖVE stream Source의 생성, Volume, seek, pitch, play/pause/stop, duration 종료 상태와 1초 간격 drift 보정을 감싼다. LÖVE 11.5가 정지된 stream의 1초 미만 seek를 play 시작 때 다시 더하는 동작을 피하도록 Source를 먼저 재생한 뒤 요청 위치로 seek한다. 첫 위치 검사에서 Transport와 Source의 기준점을 각각 기록하고 이후 진행 시간의 차이만 비교하므로, streamed MP3가 초기 seek 위치와 다른 원점으로 `tell()`해도 drift로 오인하지 않는다. Source 오류를 문자열로 바꾸고 내부 Source를 정리한다.
- `PlaybackTransport`는 논리 seconds, beat, Mixtape Offset과 Music 시작 상태를 함께 소유한다. `play(rate)`의 rate 생략값은 실제 게임 경로의 `1.0`이며, Editor만 Stage의 Playback Rate를 명시적으로 전달한다. 음악 duration 도달 시 Transport는 정확한 Music 종료 timeline 위치와 `isMusicFinished()` 상태를 제공한다. Core Transport 자체는 계속 재생 가능하며, End가 없는 EditorSession만 이 상태를 Stage 자동 종료로 해석한다.
- `UI.Button`은 enabled 상태와 좌클릭 hit-test를, `UI.TextInput`은 UTF-8 텍스트·커서, 삽입·삭제와 깜빡임 상태를, `UI.ComboBox`는 TextInput 기반 검색·필터·선택과 키보드 탐색 상태를 제공한다. `UI.ScrollArea`는 content와 viewport 크기, wheel 이동, offset 제한과 조건부 scrollbar thumb 비율을 소유한다. 네 모듈은 색상과 LÖVE graphics 호출을 포함하지 않는다.

`Core.PlaybackTransport:seekBeat(beat)`는 재생 중 호출을 거부하는 paused-only 경계다. `EditorSession:update`에서 TestPlayer update가 실패하면 먼저 `pause()`로 Transport, Metronome과 TestPlayer를 모두 정지한 뒤 이전 beat로 rollback할 때만 이 API를 사용한다. rollback도 실패하면 원래 preview 오류와 rollback 오류를 함께 반환한다. 이 순서는 재생 중 Source와 논리 시간을 동시에 이동시키지 않도록 보장한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. `TapJudgment`는 등록한 목표 beat에 대해 GOOD/BAD 입력 판정과 시간 경과 MISS, 대상 없는 EMPTY_INPUT을 만든다. 판정창은 생성 옵션으로 받아 Project가 beat 또는 다른 시간 정책을 명시할 수 있다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

`ProjectEvents`는 Project manifest의 Category, Event와 number 프로퍼티 등록 계약을 검증하고 기본 params와 값 범위를 제공한다. `BeatTween`은 시작·목표 값과 beat 구간을 받아 BPM에 따라 실제 이동 시간이 달라지는 선형 보간 값을 제공한다. 구체적인 Event 정의와 좌표·Sprite·연출은 Project가 소유한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values`의 392px 고정 상단 영역과 Scale 기반 하단 Timeline을 가진다. 이 높이는 32px 헤더와 24px짜리 콘텐츠 15행을 합친 크기다. Categories와 Events는 각각 독립적으로 스크롤하며 Properties와 Values는 같은 `Core.UI.ScrollArea`를 공유해 행 정렬을 유지한다. 각 패널은 내용이 viewport를 넘을 때만 얇은 scrollbar를 표시한다. 기본 선택인 `Editor Properties`는 Snap, Scale, Playback Rate, Auto Play, Metronome, Metronome Period, Track, Preview Aspect Width, Preview Aspect Height를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, Onset Threshold, BPM을 순서대로 제공한다. Onset Threshold는 화면상 Auto 기능 옆 그룹에 있지만 실제 저장 소유권은 `editorSettings`에 유지한다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

`StageDocument`는 Stage 버전 2의 최상위 BPM, 선택적 Mixtape·Editor 설정과 Event 구조를 검증하고 dirty 상태를 소유한다. 하나로 제한되는 Game Manager `end`와 `setInputEnabled` Event 생성, 다중 위치의 원자 이동·삭제, 노드별 Enabled 수정과 고유 Event ID 생성도 담당한다. 기본값과 같은 선택 속성은 저장 데이터에서 제거한다. JSON에서 decode된 table은 객체·배열 메타정보와 key shape를 문맥에 맞게 검사하며, `pattern.params` 내부 JSON null sentinel은 복제와 저장 왕복에서도 보존한다.

`StageStore`는 검증된 식별자로 `projects/<projectId>/stages/<stageId>.json`만 읽고 쓴다. 개발용 네이티브 source에서는 실제 `sourceRoot` 파일을 기준으로 목록·읽기·존재 확인·원자 저장을 수행해 LÖVE save directory의 shadow 파일을 원본으로 취급하지 않는다. 패키징된 `.love`는 읽기만 허용한다.

`EditorSession`은 Project, `StageDocument`, `StageStore`, Core `PlaybackTransport`, Editor 전용 `MetronomePlayback`과 `TestPlayer`를 조립한다. Timeline Event 배치·이동에 공통 Snap을 적용하고, 재생 입력 상태를 기본 true에서 `setInputEnabled` 값으로 변경하며 `end` 도달 시 정확한 Event beat에서 preview를 정지한다. End가 없으면 Transport의 Music 종료 상태에서 preview를 정지하고 App에 정보 toast 상태를 반환한다. 클릭으로 정한 `anchorBeat`를 Transport의 이동 beat와 분리해 유지하며, Play할 때마다 Transport를 기준 beat로 되돌린 뒤 resolved Mixtape와 `projects/<projectId>/...` Music 경로를 전달한다. Stage의 Playback Rate는 Transport·TestPlayer·Metronome 속도에 함께 적용된다. Preview Canvas는 기본 `16:9`인 Stage의 Preview Aspect Width·Height 비율을 유지하며 Properties·Values 영역 중앙에 맞춘다. `seekTimeline`은 `TimelineSnap`을 적용한 paused-only Transport seek와 기준 beat 갱신을, `resetTimeline`은 기준 beat와 보이는 시작 위치를 0으로 되돌리는 동작을, `panTimeline`은 저장 데이터와 분리된 Timeline 시작 beat 이동을 제공한다. `editor/timeline/TimelineSnap`은 화면과 무관한 공통 반올림 규칙을 소유해 재생 바와 Event 노드 배치가 같은 Snap을 사용하게 한다. `TimelineEventGeometry`는 관리 노드의 `0.25 beat`, 게임플레이 노드의 명시적 `widthBeats`·`durationBeats` 또는 기본 `1 beat` 폭을 해석하고 같은 Track의 반개구간 영역 충돌을 판정한다. Metronome이 false면 SoundData와 Source를 만들지 않는다. 시작이나 update 실패의 정리는 `EditorSession:pause()` 한 곳에서 수행한다.

`MetronomePlayback`은 0.012초 길이의 1760Hz 강박과 880Hz 일반박 SoundData·정적 Source를 각각 하나만 만든다. Source는 반복하지 않으며, `EditorSession:update`가 Transport의 현재 beat를 전달하면 새 정수 beat crossing을 처리한다. 한 프레임에서 여러 beat를 건너뛰면 과거 클릭을 몰아서 재생하지 않고 두 Source를 정지한 뒤 마지막 crossed beat의 클릭 하나만 재생한다. Period의 배수 beat에는 강박을, 나머지 beat에는 일반박을 재생하므로 처리 시간과 오디오 메모리는 건너뛴 beat 수, BPM, Period와 무관하다. Core와 Project는 이 Editor 내부 구현 세부를 알지 못한다.

`EditorApp`은 Session을 Menu, Music 모달, 패널별 wheel 스크롤, Properties/Values, Timeline Event의 배치 전 Properties/Values 기본값·영역 충돌 배치·이동 실패를 알리는 최대 5개 error toast stack·Ctrl/선택 사각형 다중 선택·충돌 preview 기반 그룹 drag·Delete 삭제·노드별 속성 모달, 밝고 어두운 노드 모두에서 이름을 읽을 수 있는 1px 어두운 글자 윤곽선, wheel zoom·재생 바 drag·중간 버튼 pan과 오류 dialog에 연결한다. Timeline은 전체 너비를 사용하되 왼쪽 첫 칸을 비우고 다음 경계선을 화면의 시작 beat 원점으로 사용한다. 렌더링·seek·zoom 좌표는 이 원점을 공유하며 현재 Metronome Period의 배수 beat 번호를 경계선 중앙에 표시한다. Menu·Dialog·Beat 0 Auto 버튼은 `Core.UI.Button`을, Values와 Dialog는 `Core.UI.TextInput`을 조합하며 Values만 숫자 필터를 적용한다. Project, Stage, Music과 Auto Play 선택은 `Core.UI.ComboBox`를 조합한다. Editor의 색상, 좌표, 셀·Dialog 렌더링과 Stage 검증 연결은 `editor/ui/`에 남으며 Core UI는 이를 알지 못한다. 숫자 편집은 유효한 값을 확정할 때만 Session에 전달하고, boolean은 즉시 전환한다. Timeline zoom은 cursor beat를 고정하며 Play 중에도 허용된다. 일시정지 상태에서 Timeline 상단 클릭·drag는 주황색 기준 바를 Snap 위치로 옮기고 양끝 drag는 마우스와 기준 바의 수평 거리에 비례하는 update 기반 연속 pan을 수행한다. Play 중에는 하늘색 재생 위치 바를 별도로 표시하고 Pause하면 숨긴다. 중간 버튼 pan은 Play 중에도 허용된다. `F`는 Play/Pause, `Ctrl+S`는 Save, `R`은 Pause 후 beat 0 reset 단축키다.

`MusicOnsetDetector`는 Project Music을 LÖVE Decoder로 청크 단위 디코딩한다. 채널 평균 10ms RMS가 Stage의 Onset Threshold보다 큰 창이 두 번 연속 나타나는 첫 위치를 반환하므로 전체 곡의 raw SoundData를 한꺼번에 메모리에 올리지 않는다. 이 결과는 Offset이 기본값일 때만 Music 선택 흐름에서 자동 적용되며, 수동 Auto 버튼은 현재 값을 다시 분석 결과로 바꾼다.

`TestPlayer`는 Launcher가 주입한 `ProjectLoader.createGame`으로 프로젝트 앱을 만들고 Editor 설정의 Auto Play 선택을 선택적 `setAutoPlay(value)`에 먼저 전달한 뒤 현재 Stage와 기준 beat를 선택적 `startStage(stage, startBeat)`에 전달한다. Auto Play 기본값 `none`은 수동 입력이며 `good`, `bad`, `miss`의 구체적인 자동 입력 시점은 판정 정책을 소유한 Project가 구현한다. `update(deltaTime, beat)`와 `draw(width, height)`를 preview Canvas 안에서 실행하며 Editor는 Playback Rate가 적용된 deltaTime과 현재 beat를 전달한다. `draw`의 크기는 EditorSession이 현재 preview 영역 안에 설정 종횡비로 맞춘 Canvas 크기다. 입력이 활성화된 동안 Space는 `keypressed(key, beat)`로 전달된다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. Launcher는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, `eventCategories`의 게임플레이 노드 정의, 게임 화면, UI/UX, Sprite, 사운드, 연출, Project 리소스와 Stage를 소유한다. Sample은 Spawn Actors, Guide Turn, Player Turn과 Cue & Response를 등록하고 Core TapJudgment·BeatTween을 조합한다. 공통 입력 동작이 필요하면 Editor를 불러오지 않고 `Core.UI`를 기반으로 Project 전용 스타일과 동작을 조합한다. 프로젝트 앱의 렌더링 계약은 `draw(width, height)`다. Launcher는 전체 창 크기를, TestPlayer는 preview Canvas 크기를 전달한다.

## 데이터 흐름

```text
Project assets/audio → Editor Music 선택 → Stage의 희소 Mixtape 설정
→ EditorSession이 Project 경로 해석 → Core PlaybackTransport와 MusicPlayback

Project가 Categories/Events 등록 → Editor가 TimelineEvent 배치 → Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개 → Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
