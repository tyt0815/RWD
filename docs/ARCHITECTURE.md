# 아키텍처

## 의존 방향

```text
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
        ↘ ProjectLoader.createGame → Editor TestPlayer
Editor → Project Manifest·assets/audio
```

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못하며, `editor/`와 `projects/`는 `require("core")` 공개 진입점만 사용한다. Project 상대 Music 경로를 실제 경로로 바꾸고 Editor 전용 설정을 적용하는 책임은 Editor에 있다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. `CORE_API_VERSION`, `JudgmentResult`, `PlaybackClock`과 함께 `MixtapeSettings`, `TempoMap`, `MusicPlayback`, `PlaybackTransport`를 공개한다.

- `MixtapeSettings`는 Music, Volume과 Beat 0 Offset을 검증하고 기본값을 해석하거나 희소 객체로 줄인다.
- `TempoMap`은 양수 유한 BPM 하나를 소유하고 beat와 논리 seconds를 상호 변환한다. Stage 형식과 독립적이므로 이후 BPM 변화 구조를 이 경계 뒤에서 확장할 수 있다.
- `MusicPlayback`은 LÖVE stream Source의 생성, Volume, seek, pitch, play/pause/stop, duration 종료와 1초 간격 drift 보정을 감싼다. Source 오류를 문자열로 바꾸고 내부 Source를 정리한다.
- `PlaybackTransport`는 논리 seconds, beat, Mixtape Offset과 Music 시작 상태를 함께 소유한다. `play(rate)`의 rate 생략값은 실제 게임 경로의 `1.0`이며, Editor만 Stage의 Playback Rate를 명시적으로 전달한다. 음악 duration이 끝나도 Transport의 논리 시간과 beat는 계속 진행한다.

`Core.PlaybackTransport:seekBeat(beat)`는 재생 중 호출을 거부하는 paused-only 경계다. `EditorSession:update`에서 TestPlayer update가 실패하면 먼저 `pause()`로 Transport, Metronome과 TestPlayer를 모두 정지한 뒤 이전 beat로 rollback할 때만 이 API를 사용한다. rollback도 실패하면 원래 preview 오류와 rollback 오류를 함께 반환한다. 이 순서는 재생 중 Source와 논리 시간을 동시에 이동시키지 않도록 보장한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values` 상단 영역과 Scale 기반 하단 Timeline을 가진다. 기본 선택인 `Editor Properties`는 Scale, Playback Rate, Metronome, Metronome Period를, `Mixtape Properties`는 Music, Volume, Beat 0 Offset, BPM을 순서대로 제공한다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

`StageDocument`는 Stage 버전 2의 최상위 BPM, 선택적 Mixtape·Editor 설정과 Event 구조를 검증하고 dirty 상태를 소유한다. 기본값과 같은 선택 속성은 저장 데이터에서 제거한다. JSON에서 decode된 table은 객체·배열 메타정보와 key shape를 문맥에 맞게 검사하며, `pattern.params` 내부 JSON null sentinel은 복제와 저장 왕복에서도 보존한다.

`StageStore`는 검증된 식별자로 `projects/<projectId>/stages/<stageId>.json`만 읽고 쓴다. 개발용 네이티브 source에서는 실제 `sourceRoot` 파일을 기준으로 목록·읽기·존재 확인·원자 저장을 수행해 LÖVE save directory의 shadow 파일을 원본으로 취급하지 않는다. 패키징된 `.love`는 읽기만 허용한다.

`EditorSession`은 Project, `StageDocument`, `StageStore`, Core `PlaybackTransport`, Editor 전용 `MetronomePlayback`과 `TestPlayer`를 조립한다. Play는 resolved Mixtape와 `projects/<projectId>/...` Music 경로를 Transport에 전달하고, Stage의 Playback Rate로 Transport·TestPlayer·Metronome 속도를 함께 바꾼다. Metronome이 false면 SoundData와 Source를 만들지 않는다. 시작이나 update 실패의 정리는 `EditorSession:pause()` 한 곳에서 수행한다.

`MetronomePlayback`은 0.012초 길이의 1760Hz 강박과 880Hz 일반박 SoundData·정적 Source를 각각 하나만 만든다. Source는 반복하지 않으며, `EditorSession:update`가 Transport의 현재 beat를 전달하면 새 정수 beat crossing을 처리한다. 한 프레임에서 여러 beat를 건너뛰면 과거 클릭을 몰아서 재생하지 않고 두 Source를 정지한 뒤 마지막 crossed beat의 클릭 하나만 재생한다. Period의 배수 beat에는 강박을, 나머지 beat에는 일반박을 재생하므로 처리 시간과 오디오 메모리는 건너뛴 beat 수, BPM, Period와 무관하다. Core와 Project는 이 Editor 내부 구현 세부를 알지 못한다.

`EditorApp`은 Session을 Menu, Music 모달, Properties/Values, Timeline wheel zoom과 오류 dialog에 연결한다. `editor.ui.TextInput`은 Values와 Dialog가 함께 사용하는 UTF-8 커서 이동, 중간 삽입·삭제와 커서 깜빡임 상태를 소유하며, Values만 숫자 필터를 적용한다. 모든 입력은 첫 포커스부터 현재 커서 위치에 문자를 삽입한다. `editor.ui.ComboBox`는 Project, Stage와 Music 선택이 함께 사용하는 선택값, 드롭다운, TextInput 기반 검색 필터와 키보드 탐색 상태를 소유한다. 향후 Project UI와 공유할 때는 Project가 Editor를 의존하지 않도록 중립적인 공용 UI 경계를 먼저 분리한다. 숫자 편집은 유효한 값을 확정할 때만 Session에 전달하고, boolean은 즉시 전환한다. Timeline zoom은 cursor beat를 고정하며 Play 중에도 허용된다.

`TestPlayer`는 Launcher가 주입한 `ProjectLoader.createGame`으로 프로젝트 앱을 만들고 Project의 `update(deltaTime)`과 `draw(width, height)`를 preview Canvas 안에서 실행한다. Editor는 Playback Rate가 적용된 deltaTime을 전달한다. Stage Event와 Project 입력은 아직 TestPlayer에 전달하지 않는다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. Launcher는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, 게임 화면, UI/UX, 사운드, 연출, `assets/audio` 리소스와 Stage를 소유한다. 프로젝트 앱의 렌더링 계약은 `draw(width, height)`다. Launcher는 전체 창 크기를, TestPlayer는 preview Canvas 크기를 전달한다.

## 데이터 흐름

```text
Project assets/audio → Editor Music 선택 → Stage의 희소 Mixtape 설정
→ EditorSession이 Project 경로 해석 → Core PlaybackTransport와 MusicPlayback

Project가 Categories/Events 등록 → Editor가 TimelineEvent 배치 → Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개 → Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
