# 아키텍처

## 의존 방향

```text
Project 생성기 → Project 기본 파일·폴더
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
        ↘ ProjectLoader.createGame → Editor TestPlayer
        ↘ StageRepository 하나를 Editor·Project에 주입
Editor → Project Manifest·assets/audio/music
```

`tools/create_project.py`는 개발 시에만 실행되며 런타임 모듈에 의존하지 않는다. `core/init.lua`에서 현재 API 버전을 읽어 최소 Project 매니페스트와 게임 진입 모듈을 생성한다.

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못하며, `editor/`와 `projects/`는 `require("core")` 공개 진입점만 사용한다. 스타일 독립적인 공통 UI 동작은 Core가 제공하고 Editor와 Project가 각자 스타일·배치와 도메인 동작을 조합한다. Launcher의 `AppFont`는 앱 시작 시 D2Coding TTC를 14px 기본 폰트로 한 번 설정해 Launcher, Editor와 Project의 한글 렌더링을 통일한다. Project 상대 Music 경로를 실제 경로로 바꾸고 Editor 전용 설정을 적용하는 책임은 Editor에 있다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. `CORE_API_VERSION`, `JudgmentResult`, `PlaybackClock`과 함께 `TapJudgment`, `LongNoteJudgment`, `PlayerAction`, `BeatTween`, `ProjectManifest`, `ProjectEvents`, `ProjectCategories`, `ProjectConfig`, `StageSchema`, `StageRepository`, `StageRuntime`, `MixtapeSettings`, `TempoMap`, `MusicPlayback`, `PlaybackTransport`, `UI`를 공개한다. 현재 `CORE_API_VERSION = 2`는 Project manifest가 Category별 Event ID와 `runtimeModule`, 게임 생성자의 `stageRepository` 주입 계약을 사용한다는 뜻이다. Launcher와 Editor는 manifest의 `coreApiVersion`이 이 값과 같은 Project만 연다.

- `StageSchema.isSafeId(value)`, `validate(stage)`, `normalize(stage)`, `resolveEditorSettings(stage)`는 schemaVersion 3 Stage 형식, 공통 Event 구조와 희소 Editor 설정을 소유한다. `validate`와 `normalize`는 성공 시 값과 `nil, nil`, 실패 시 `nil, message, "INVALID_STAGE"`를 반환한다.
- `StageRepository.new({ fileSystem, paths, json })`는 파일 시스템과 `stageDirectory/projectId`, `stageFile/projectId/stageId` 경로 함수, JSON codec을 주입받는다. 공개 메서드는 `listStages(projectId)`, `stageExists(projectId, stageId)`, `load(projectId, stageId)`, `save(stage, overwrite)`다. 경로 ID 검증, JSON decode/encode, 선택 경로와 JSON ID 일치, 정규화와 원자 교체를 이 경계에서 처리한다.
- `ProjectManifest.validate(project, { expectedId, expectedCoreApiVersion })`는 manifest 필수 필드, 디렉터리 ID, Core API 버전과 Category/Event/Property 등록 구조를 검사한다. Category ID는 Project 범위에서, Event ID는 각 Category 범위에서 고유하므로 서로 다른 Category가 같은 Event ID를 사용할 수 있다. 실패 코드는 `INVALID_PROJECT`다.

- `ProjectConfig`는 Project 상대 JSON 파일을 캐시하지 않고 호출마다 읽고 decode한다. Project Category가 Stage와 독립적인 설정을 Play마다 다시 적용할 때 사용하며 구체적인 필드 검증은 해당 Project가 소유한다.
- `MixtapeSettings`는 Music, Volume과 Beat 0 Offset을 검증하고 기본값을 해석하거나 희소 객체로 줄인다.
- `TempoMap`은 양수 유한 BPM 하나를 소유하고 beat와 논리 seconds를 상호 변환한다. Stage 형식과 독립적이므로 이후 BPM 변화 구조를 이 경계 뒤에서 확장할 수 있다.
- `MusicPlayback`은 LÖVE stream Source의 생성, Volume, seek, pitch, play/pause/stop, duration 종료 상태와 1초 간격 drift 보정을 감싼다. LÖVE 11.5가 정지된 stream의 1초 미만 seek를 play 시작 때 다시 더하는 동작을 피하도록 Source를 먼저 재생한 뒤 요청 위치로 seek한다. 첫 위치 검사에서 Transport와 Source의 기준점을 각각 기록하고 이후 진행 시간의 차이만 비교하므로, streamed MP3가 초기 seek 위치와 다른 원점으로 `tell()`해도 drift로 오인하지 않는다. Source 오류를 문자열로 바꾸고 내부 Source를 정리한다.
- `PlaybackTransport`는 논리 seconds, beat, Mixtape Offset과 Music 시작 상태를 함께 소유한다. `play(rate)`의 rate 생략값은 실제 게임 경로의 `1.0`이며, Editor만 Stage의 Playback Rate를 명시적으로 전달한다. 음악 duration 도달 시 Transport는 정확한 Music 종료 timeline 위치와 `isMusicFinished()` 상태를 제공한다. Core Transport 자체는 계속 재생 가능하며, End가 없는 EditorSession만 이 상태를 Stage 자동 종료로 해석한다.
- `UI.Button`은 enabled 상태와 좌클릭 hit-test를, `UI.TextInput`은 UTF-8 텍스트·커서, 삽입·삭제와 깜빡임 상태를, `UI.ComboBox`는 TextInput 기반 검색·필터·선택과 키보드 탐색 상태를 제공한다. `UI.ScrollArea`는 content와 viewport 크기, wheel 이동, offset 제한과 조건부 scrollbar thumb 비율을 소유한다. 네 모듈은 색상과 LÖVE graphics 호출을 포함하지 않는다.

`Core.PlaybackTransport:seekBeat(beat)`는 재생 중 호출을 거부하는 paused-only 경계다. `EditorSession:update`에서 TestPlayer update가 실패하면 먼저 `pause()`로 Transport, Metronome과 TestPlayer를 모두 정지한 뒤 이전 beat로 rollback할 때만 이 API를 사용한다. rollback도 실패하면 원래 preview 오류와 rollback 오류를 함께 반환한다. 이 순서는 재생 중 Source와 논리 시간을 동시에 이동시키지 않도록 보장한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. `TapJudgment`는 등록한 목표 beat에 대해 GOOD/BAD 입력 판정과 시간 경과 MISS, 대상 없는 EMPTY_INPUT을 만든다. `LongNoteJudgment`는 시작·종료 beat를 등록하고 `press`, `release`, `update`로 양 끝의 GOOD/BAD와 누락 MISS를 판정한다. 시작이나 종료 중 하나가 BAD면 최종 BAD이며 판정창 밖에서 떼거나 끝까지 떼지 않으면 MISS다. 판정창은 생성 옵션으로 받아 Project가 beat 정책을 명시할 수 있다. `PlayerAction`은 예정된 노트 종류를 보지 않고 실제 누름 시간과 Project가 주입한 `longHoldThresholdMs`로 짧은 입력의 `TAP`, 임계점의 `LONG_START`, 이후 뗌의 `LONG_RELEASE`를 분류한다. Tap과 Long의 시작 판정에는 분류를 기다리기 전 최초 press beat를 보존한다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

`ProjectEvents`는 검증된 manifest에서 Category/Event를 조회하고 기본 params 생성과 값 범위 검사를 제공한다. manifest 구조 검증 자체는 `ProjectManifest`가 소유한다. `ProjectCategories.discover`는 `game/` 바로 아래의 `Definition.lua`·`Runtime.lua` 쌍을 찾아 순수 Definition만 로드해 manifest Category로 만들고, `createHost`는 게임 생성 시에만 Runtime을 로드한다. Host는 `categoryId + eventId`로 Runtime을 찾아 occurrence와 Category lifecycle을 전달한다. 따라서 Category 추가는 기존 manifest와 Game 진입 모듈을 수정하지 않는다. `StageRuntime`은 Stage Event를 beat·원래 배치 순서로 한 번씩 전개하고, 중간 beat 시작의 catch-up Event와 `Set Input Enabled`, 최초 `End` 종료 위치를 처리한다. 현재 Editor와 Project가 각각 StageRuntime 인스턴스를 조립하며, 단일 실행 권위로 통합하는 작업은 다음 단계다. Event 결과의 Sprite, SFX와 이동은 소유하지 않고 `{ event, catchUp }` occurrence를 Project에 반환한다. `BeatTween`은 시작·목표 값과 beat 구간을 받아 BPM에 따라 실제 이동 시간이 달라지는 선형 보간 값을 제공한다. 구체적인 Event 정의와 좌표·Sprite·연출은 Project가 소유한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values`의 392px 고정 상단 영역과 Scale 기반 하단 Timeline을 가진다. 이 높이는 32px 헤더와 24px짜리 콘텐츠 15행을 합친 크기다. Categories와 Events는 각각 독립적으로 스크롤하며 Properties와 Values는 같은 `Core.UI.ScrollArea`를 공유해 행 정렬을 유지한다. 각 패널은 내용이 viewport를 넘을 때만 얇은 scrollbar를 표시한다. 기본 선택인 `Editor Properties`는 Snap, Scale, Playback Rate, Auto Play, Metronome, Metronome Period, Track, Preview Aspect Width, Preview Aspect Height를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, Onset Threshold, BPM을 순서대로 제공한다. Onset Threshold는 화면상 Auto 기능 옆 그룹에 있지만 실제 저장 소유권은 `editorSettings`에 유지한다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

`StageDocument`는 `Core.StageSchema`가 정규화한 schemaVersion 3 table의 편집 snapshot과 dirty 상태를 소유한다. `create`, `fromTable`, `fromSnapshot`, `toTable`로 snapshot을 만들고 복제하며, BPM·Mixtape·Editor 설정 변경, Event 원자 추가·이동·삭제와 노드 Property 변경을 수행한다. 각 mutation 후보를 `Core.StageSchema.normalize`에 통과시켜 공통 형식과 End singleton 검증을 재사용하고, Project Event 정의·params·singleton 검증은 현재 Project를 가진 `EditorSession`이 수행한다. 저장 성공 뒤 `markClean`으로 dirty 상태를 갱신한다. JSON decode/encode와 파일 경로는 소유하지 않는다.

Launcher는 `NativeFileSystem`, `STAGE_PATHS`와 `vendor.dkjson`을 `Core.StageRepository.new`에 주입해 Repository 하나를 만든다. 개발용 네이티브 source에서는 실제 `sourceRoot` 파일을 기준으로 목록·읽기·존재 확인·원자 저장을 수행해 LÖVE save directory의 shadow 파일을 원본으로 취급하지 않는다. 패키징된 `.love`는 읽기만 허용한다. 같은 Repository 인스턴스를 `Editor.createApp`, Editor preview의 `ProjectLoader.createGame`, 독립 Project `ProjectLoader.createGame`에 전달한다.

`EditorSession`은 Project, `StageDocument`, 주입된 `StageRepository`, Core `PlaybackTransport`·`StageRuntime`, Editor 전용 `MetronomePlayback`과 `TestPlayer`를 조립한다. Timeline Event 배치·이동에 공통 Snap을 적용하고, 재생 입력 상태를 기본 true에서 `setInputEnabled` 값으로 변경하며 `end` 도달 시 정확한 Event beat에서 preview를 정지한다. End가 없으면 Transport의 Music 종료 상태에서 preview를 정지하고 App에 정보 toast 상태를 반환한다. 클릭으로 정한 `anchorBeat`를 Transport의 이동 beat와 분리해 유지하며, Play할 때마다 Transport를 기준 beat로 되돌린 뒤 resolved Mixtape와 `projects/<projectId>/...` Music 경로를 전달한다. Stage의 Playback Rate는 Transport·TestPlayer·Metronome 속도에 함께 적용된다. Preview Canvas는 기본 `16:9`인 Stage의 Preview Aspect Width·Height 비율을 유지하며 Properties·Values 영역 중앙에 맞춘다. `seekTimeline`은 `TimelineSnap`을 적용한 paused-only Transport seek와 기준 beat 갱신을, `resetTimeline`은 기준 beat와 보이는 시작 위치를 0으로 되돌리는 동작을, `panTimeline`은 저장 데이터와 분리된 Timeline 시작 beat 이동을 제공한다. `editor/timeline/TimelineSnap`은 화면과 무관한 Snap 규칙을 소유한다. 재생 바는 가장 가까운 간격선에 맞추고, Event 생성·drag는 같은 공통 함수로 커서가 포함된 Snap 크기 셀의 시작점에 맞춘다. `TimelineEventGeometry`는 관리 노드의 `0.25 beat`, 게임플레이 노드의 명시적 `widthBeats`·`durationBeats` 또는 기본 `1 beat` 폭을 해석하고 같은 Track의 반개구간 영역 충돌을 판정한다. 연결형 노드는 시작·응답 폭을 따로 계산하며 `startEndpointWidthProperty`·`endEndpointWidthProperty`가 있으면 Long Note 길이 Property를 각 GUI 블록 폭과 충돌 영역에 함께 적용한다. Metronome이 false면 SoundData와 Source를 만들지 않는다. 시작이나 update 실패의 정리는 `EditorSession:pause()` 한 곳에서 수행한다.

`MetronomePlayback`은 0.012초 길이의 1760Hz 강박과 880Hz 일반박 SoundData·정적 Source를 각각 하나만 만든다. Source는 반복하지 않으며, `EditorSession:update`가 Transport의 현재 beat를 전달하면 새 정수 beat crossing을 처리한다. 한 프레임에서 여러 beat를 건너뛰면 과거 클릭을 몰아서 재생하지 않고 두 Source를 정지한 뒤 마지막 crossed beat의 클릭 하나만 재생한다. Period의 배수 beat에는 강박을, 나머지 beat에는 일반박을 재생하므로 처리 시간과 오디오 메모리는 건너뛴 beat 수, BPM, Period와 무관하다. Core와 Project는 이 Editor 내부 구현 세부를 알지 못한다.

`EditorApp`은 Session을 Menu, Music 모달, 패널별 wheel 스크롤, Properties/Values, Timeline Event의 배치 전 Properties/Values 기본값·영역 충돌 배치·이동 실패를 알리는 최대 5개 error toast stack·Ctrl/선택 사각형 다중 선택·충돌 preview 기반 그룹 drag·Delete 삭제·전체 프로퍼티와 상대 위치를 보존하는 Ctrl+C/X/V·Ctrl+Z와 Ctrl+Shift+Z 편집 이력·노드별 속성 모달, 밝고 어두운 노드 모두에서 이름을 읽을 수 있는 1px 어두운 글자 윤곽선, wheel zoom·재생 바 drag·중간 버튼 pan과 오류 dialog에 연결한다. Timeline은 전체 너비를 사용하되 왼쪽 첫 칸을 비우고 다음 경계선을 화면의 시작 beat 원점으로 사용한다. 렌더링·seek·zoom 좌표는 이 원점을 공유하며 현재 Metronome Period의 배수 beat 번호를 경계선 중앙에 표시한다. Menu·Dialog·Beat 0 Auto 버튼은 `Core.UI.Button`을, Values와 Dialog는 `Core.UI.TextInput`을 조합하며 Values만 숫자 필터를 적용한다. Project, Stage, Music과 Auto Play 선택은 `Core.UI.ComboBox`를 조합한다. Editor의 색상, 좌표, 셀·Dialog 렌더링과 Stage 검증 연결은 `editor/ui/`에 남으며 Core UI는 이를 알지 못한다. 숫자 편집은 유효한 값을 확정할 때만 Session에 전달하고, boolean은 즉시 전환한다. Timeline zoom은 cursor beat를 고정하며 Play 중에도 허용된다. 일시정지 상태에서 Timeline 상단 클릭·drag는 주황색 기준 바를 Snap 위치로 옮기고 양끝 drag는 마우스와 기준 바의 수평 거리에 비례하는 update 기반 연속 pan을 수행한다. Play 중에는 하늘색 재생 위치 바를 별도로 표시하고 Pause하면 숨긴다. 중간 버튼 pan은 Play 중에도 허용된다. 붙여넣기는 선택 묶음의 최소 beat·Track을 Timeline 본문의 현재 마우스 Snap beat·Track에 맞추고 새 ID를 발급하며, 충돌·범위·singleton 검증 실패 시 원자적으로 거부한다. `EditorSession`의 Stage snapshot 이력은 새 편집 시 redo 분기를 제거하고 Undo/Redo 때 BPM Transport와 dirty 상태도 복원한다. `F`는 Play/Pause, `Ctrl+S`는 Save, `Ctrl+Z`와 `Ctrl+Shift+Z`는 Undo/Redo, `R`은 Pause 후 beat 0 reset 단축키다.

`MusicOnsetDetector`는 Project Music을 LÖVE Decoder로 청크 단위 디코딩한다. 채널 평균 10ms RMS가 Stage의 Onset Threshold보다 큰 창이 두 번 연속 나타나는 첫 위치를 반환하므로 전체 곡의 raw SoundData를 한꺼번에 메모리에 올리지 않는다. 이 결과는 Offset이 기본값일 때만 Music 선택 흐름에서 자동 적용되며, 수동 Auto 버튼은 현재 값을 다시 분석 결과로 바꾼다.

`TestPlayer`는 Launcher가 주입한 `ProjectLoader.createGame`으로 프로젝트 앱을 만들고 Editor 설정의 Auto Play 선택을 선택적 `setAutoPlay(value)`에 먼저 전달한 뒤 현재 Stage와 기준 beat를 선택적 `startStage(stage, startBeat)`에 전달한다. Auto Play 기본값 `none`은 수동 입력이며 `good`, `bad`, `miss`의 구체적인 자동 입력 시점은 판정 정책을 소유한 Project가 구현한다. `update(deltaTime, beat, realDeltaTime)`와 `draw(width, height)`를 preview Canvas 안에서 실행하며 Editor는 Playback Rate가 적용된 deltaTime, 현재 beat와 배속이 적용되지 않은 실제 deltaTime을 전달한다. 세 번째 인자는 선택적 확장이므로 기존 Project는 추가 인자를 무시할 수 있고, ms 기반 입력 의도 분류처럼 Playback Rate와 무관해야 하는 동작만 사용한다. `draw`의 크기는 EditorSession이 현재 preview 영역 안에 설정 종횡비로 맞춘 Canvas 크기다. 입력이 활성화된 동안 Space는 `keypressed(key, beat)`로 전달된다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. Launcher는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, `eventCategories`의 게임플레이 노드 정의, 게임 화면, UI/UX, Sprite, 사운드, 연출, Project 리소스와 Stage를 소유한다. 새 기능과 구조 개편은 `game/<CategoryName>/`을 소유권 경계로 삼는다. Category의 순수 `Definition.lua`와 실행 `Runtime.lua`, Event 및 Actor 구현을 함께 두며, Actor는 공통 구현의 여러 인스턴스 또는 역할별 모듈 중 실제 변경 이유에 맞는 쪽을 선택한다. Actor 전용 리소스는 Actor가, 실제 공유 리소스와 캐시는 Category가 소유한다. `ProjectLoader.createGame`은 Launcher의 `StageRepository` 인스턴스와 독립 실행 여부를 생성 옵션으로 주입하므로 Project는 Editor 모듈, JSON 라이브러리나 Stage 경로 계산을 직접 사용하지 않는다. Rhythm Dotgeo는 `game/StageSelect.lua`에서 이 경계와 `Core.UI.Button`을 조합해 Stage 이름 목록을 그리고, `game/StagePlayback.lua`에서 Core `MusicPlayback`·`PlaybackTransport`·`StageRuntime`과 Category Host를 조합해 음악, beat와 관리·Project 노드를 실행한다. `game/SpeakiSong/`은 공유 Sprite·Sound, 배경, 동일 Actor 인스턴스 두 개, Tap·Long 판정과 자동 Turn 연출을 소유한다. Runtime은 검증된 Stage의 Cue와 Response beat를 역할 순서로 정렬해 연속된 같은 역할을 하나의 Turn으로 묶고, 역할이 바뀌는 목표 beat 0.5박 전에 0.5박 BeatTween을 시작한다. 별도 좌피키·우피키 Stage Event는 등록하지 않는다. `config/gameplay.json`은 모든 Rhythm Dotgeo Stage가 공유하는 Tap/Long 구분 시간 `longHoldThresholdMs`를, `config/speaki_song.json`은 액터 크기·여백·화면 밖 거리, Long/Tap 이동값, Long start·loop·end와 Tap SFX 경로를 Stage 밖에서 소유한다. Runtime `startStage`가 둘을 매번 다시 읽어 입력 분류기, 두 Actor와 Sounds에 적용한다. Space 누름과 뗌은 `keypressed`·`keyreleased`로 Category Host까지 전달된다. Sample은 같은 `StageRuntime`으로 Event 시점을 받고 자동 발견된 `game/SampleGameplay/`의 Runtime에 occurrence를 전달한다. `Definition.lua`, Event 파일, `SampleActor.lua`, 공유 `Sprites.lua`·`Sounds.lua`가 Category 폴더 안에서 등록·Actor·Sprite·SFX·이동 책임을 완결한다. 공통 입력 동작이 필요하면 Editor를 불러오지 않고 `Core.UI`를 기반으로 Project 전용 스타일과 동작을 조합한다. 프로젝트 앱의 렌더링 계약은 `draw(width, height)`다. Launcher는 전체 창 크기를, TestPlayer는 preview Canvas 크기를 전달한다.

## 데이터 흐름

```text
Project assets/audio/music → Editor Music 선택 → Stage의 희소 Mixtape 설정
→ EditorSession이 Project 경로 해석 → Core PlaybackTransport와 MusicPlayback

Project가 Categories/Events 등록 → Editor가 TimelineEvent 배치 → Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개 → Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
