# 아키텍처

## 의존 방향

```text
Launcher → Editor → Core 공개 API
        ↘ Project → Core 공개 API
Editor → Project Manifest
```

Core는 Editor와 Project를 알지 못한다. Project는 Editor를 알지 못한다.

## Core

`core/init.lua`는 유일한 공개 진입점이다. 현재는 `CORE_API_VERSION`과 `JudgmentResult` 상수만 제공한다. 향후 시간 변환, Pattern 전개, Tap/Long Note 판정을 이 경계 뒤에 추가한다.

판정 결과는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 네 가지다. Core는 결과를 만들지만 사운드, UI와 시각 효과는 Project가 처리한다.

## Editor

Editor는 `Menu | Categories | Events | Properties | Values` 상단 영역과 하단 타임라인을 가진다. 테스트 플레이 중에는 Properties와 Values 영역을 프로젝트의 실시간 `TestPlayer` Canvas가 대체한다.

현재 구현은 고정 패널과 타임라인을 렌더링하고, 비활성 TestPlayer 객체만 소유한다. `StageDocument`는 Stage 버전 1 데이터를 검증하고, `StageStore`는 검증된 식별자로 `projects/<projectId>/stages/<stageId>.json` 경로만 읽고 쓴다. 네이티브 파일 경계는 원자 교체를 사용하며 패키징된 `.love` 소스에는 쓰지 않는다. Event 편집과 실제 프로젝트 미리보기는 현재 범위에 없다.

## Project

각 `projects/<projectId>/project.lua`는 `id`, `title`, `coreApiVersion`, `entryModule`을 제공한다. 실행기는 `coreApiVersion`이 `Core.CORE_API_VERSION`과 같은 프로젝트만 연다.

프로젝트는 Pattern, 게임 화면, UI/UX, 사운드, 연출, 리소스와 Stage를 소유한다. 배포 도구가 추가되면 선택 프로젝트와 Core만 독립 패키지에 포함한다.

## 데이터 흐름

```text
Project가 Categories/Events 등록
→ Editor가 TimelineEvent 배치
→ Stage JSON 저장
→ Pattern이 Tap/Long Note로 전개
→ Core가 JudgmentResult 생성
→ Project가 피드백 연출
```
