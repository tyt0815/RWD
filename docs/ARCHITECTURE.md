# 아키텍처

## 의존 방향

```text
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
        ↘ ProjectLoader.createGame → Editor TestPlayer
Editor → Project Manifest
```

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못한다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. 현재는 `CORE_API_VERSION`, `JudgmentResult` 상수와 고정 BPM `Core.PlaybackClock`을 제공한다. `PlaybackClock`은 play, pause, update와 현재 beat를 소유하며 Pause 뒤에도 beat를 보존한다. 향후 시간 변환, Pattern 전개, Tap/Long Note 판정을 이 경계 뒤에 추가한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values` 상단 영역과 하단 타임라인을 가진다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

`StageDocument`는 Stage 버전 1의 ID, 단일 BPM과 Event 구조를 검증하고 dirty 상태를 소유한다. JSON에서 decode된 table은 객체·배열 메타정보와 key shape를 문맥에 맞게 검사하며, `pattern.params` 내부의 JSON null sentinel은 문서 복제 중에도 보존한다. `StageStore`는 검증된 식별자로 `projects/<projectId>/stages/<stageId>.json` 경로만 읽고 쓰며, 선택한 Project·파일 ID와 JSON 내부 ID가 일치하는지 확인한다.

개발용 네이티브 source에서는 Stage 목록 후보를 실제 `sourceRoot` 파일로 제한하고 읽기·존재 확인·원자 저장도 같은 경로를 사용한다. 따라서 LÖVE save directory의 같은 이름 shadow 파일이나 save-only 파일은 Stage 원본으로 취급하지 않는다. 패키징된 `.love`는 가상 파일시스템으로 읽되 기존처럼 내부 쓰기를 거부한다.

`EditorSession`은 Project, `StageDocument`, `StageStore`, `Core.PlaybackClock`과 `TestPlayer`를 조립한다. Stage 생성·열기·저장·Save As, BPM 편집, 재생·일시정지와 4박자 단위 타임라인 자동 추적 상태를 소유한다. `EditorApp`은 이 상태를 Menu, 모달, Properties/Values와 타임라인에 연결하고 Values 셀의 BPM 인라인 편집 상태를 소유한다. 인라인 편집은 모달을 사용하지 않으며 유효한 값을 확정할 때만 `EditorSession:setBpm`을 호출한다.

`TestPlayer`는 Launcher가 주입한 `ProjectLoader.createGame`으로 프로젝트 앱을 만들고, 프로젝트의 `update(deltaTime)`과 `draw(width, height)`를 Properties와 Values 영역을 합친 Canvas 안에서 실행한다. Stage Event와 Project 입력은 아직 TestPlayer에 전달하지 않는다. 파일·preview 오류는 Editor 모달로 바꾸고 재생을 정지해 Launcher 전체를 중단시키지 않는다.

Launcher는 Editor를 만들 때 `onQuit` 콜백을 주입한다. Editor의 Menu Quit은 dirty 확인을 마친 뒤 재생을 멈추고 이 콜백을 호출하며, Launcher는 `returnToMenu()`로 복귀한다. 에디터 Escape는 이 경계를 우회하지 않고 모달 취소에만 사용된다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. 실행기는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, 게임 화면, UI/UX, 사운드, 연출, 리소스와 Stage를 소유한다. 배포 도구가 추가되면 선택 프로젝트와 Core만 독립 패키지에 포함한다.

프로젝트 앱의 렌더링 계약은 `draw(width, height)`다. Launcher는 전체 창 크기를 전달하고 TestPlayer는 미리보기 Canvas 크기를 전달한다. 따라서 Project는 전역 창 크기를 직접 가정하지 않는다.

## 데이터 흐름

```text
Project가 Categories/Events 등록
→ Editor가 TimelineEvent 배치
→ Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개
→ Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
