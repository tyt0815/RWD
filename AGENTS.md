# AGENTS.md

## 세션 시작 순서

1. `README.md`에서 프로젝트 목표와 실행법을 확인한다.
2. `docs/HANDOFF.md`에서 현재 상태, 마지막 검증 결과와 다음 작업을 확인한다.
3. 변경할 영역의 문서를 읽는다. 구조 변경은 `docs/ARCHITECTURE.md`, Stage 변경은 `docs/STAGE_FORMAT.md`, 제작 흐름 변경은 `docs/WORKFLOW.md`를 먼저 읽는다.
4. 다단계 작업은 구현 전에 성공 기준과 짧은 계획을 작성한다.

## 프로젝트 원칙

- LÖVE2D 11.5와 LuaJIT/Lua 5.1 호환 문법을 사용한다.
- 요청된 기능에 필요한 최소 코드만 작성한다.
- 관련 없는 코드, 문서, 포맷을 함께 정리하지 않는다.
- 모호한 요구사항은 구현 전에 질문하고 선택한 해석을 문서에 남긴다.
- 사용자 소유 변경과 `.references/` 파일을 임의로 수정하거나 삭제하지 않는다.

## 모듈 경계

- `core/`는 리듬게임 공통 규칙과 스타일 독립적인 공통 UI 동작을 소유하며 게임별·에디터별 UI 스타일, 사운드와 연출을 소유하지 않는다.
- `editor/`와 `projects/`는 `require("core")`만 사용한다. `core` 내부 경로를 직접 불러오지 않는다.
- `projects/`는 `editor/`를 불러오지 않는다.
- `launcher/`는 모듈을 조립하지만 게임 규칙이나 에디터 기능을 구현하지 않는다.
- 프로젝트별 코드와 리소스는 `projects/<projectId>/` 안에 둔다.
- 게임플레이 노드는 공통 판정·등록 계약처럼 재사용 가능한 규칙만 Core 공개 API에 두고, 노드 정의·화면·색·사운드·연출은 해당 Project에 둔다.
- Stage Event의 beat 순서 실행, 중간 시작 상태 복원, End와 입력 활성 상태는 `Core.StageRuntime`을 사용한다. Project에서 Event crossing과 Game Manager 실행을 다시 구현하지 않는다.
- Project 기능은 `projects/<projectId>/game/<CategoryName>/`에 Category 단위로 모으고, Event·Actor·Sprite·SFX·이동 등 해당 기능에만 필요한 구현은 Category 폴더 밖으로 흩뜨리지 않는다. `Definition.lua`와 `Runtime.lua`를 추가하면 `Core.ProjectCategories`가 자동 발견하므로 새 Category나 노드를 만들기 위해 기존 `project.lua`, 게임 진입 모듈 또는 다른 Category를 수정하지 않는다. 게임 진입 모듈은 Core 런타임과 Category Host 조립만 소유한다.
- Project는 Stage JSON을 직접 decode·검증하거나 Event 실행 시점을 계산하지 않는다. Stage 형식·검증·실행 규칙은 Core 공개 API가 소유하고 Launcher·Editor는 Project 경로와 파일 접근을 조립한다.
- Project 기능을 구현하기 전에 Core 공개 API를 검색하고, 기존 Core 인스턴스 조합으로 해결할지 공통 기능을 Core에 추가할지 판단한다. Lua에서는 상속보다 조합을 우선하며 선택 근거가 불명확하면 구현 전에 질문한다.
- 공통 기능을 Core에 추가하면 공개 API와 Core 테스트를 함께 변경하고, 새 Project 제작자가 알아야 하는 경우 Sample 참고 주석과 `docs/PROJECT_NODES_TUTORIAL.md`도 갱신한다.

## Project Category 구성

- Category의 `Definition.lua`는 Editor도 읽을 수 있는 순수 등록 데이터만 제공하며 LÖVE 리소스를 생성하거나 Runtime·Actor를 불러오지 않는다.
- Category의 `Runtime.lua`는 Core occurrence를 Event handler에 전달하고 Category 상태, Actor와 공용 리소스를 조립한다. 구체적인 Event 파일은 Actor·판정·연출 객체를 조율하며 저수준 Sprite/SFX 로딩을 중복 소유하지 않는다.
- `Actors.lua` 같은 단일 파일을 강제하지 않는다. 같은 상태·행동·리소스를 공유하면 `SampleActor.lua` 하나를 여러 인스턴스로 조합하고, 독립적으로 변경되면 `GuideActor.lua`, `PlayerActor.lua`처럼 역할별 모듈로 분리한다.
- `LeftActor.lua`, `RightActor.lua`처럼 현재 배치 위치로 이름 짓는 것은 위치 자체가 정체성일 때만 사용한다. Turn이나 레이아웃 변경에도 유지되는 역할 이름을 우선한다.
- Actor 전용 Sprite·SFX는 해당 Actor가 직접 소유하거나 Actor 전용 리소스 객체를 주입받는다. 여러 Actor가 실제로 같은 파일과 수명을 공유할 때만 Category 범위의 `Sprites.lua`, `Sounds.lua` 또는 리소스 캐시로 올리고, 같은 asset을 Actor마다 중복 로드하지 않는다.
- 처음에는 변경 이유가 같은 코드를 한 모듈에 두고, 상태·행동·리소스 수명 중 하나가 독립적으로 바뀔 때 분리한다. 파일 수를 맞추기 위한 선제 분리는 하지 않는다.

## Project 템플릿 유지보수

- 새 Project는 수동으로 기본 폴더를 만들지 않고 `python tools/create_project.py <projectId> "<title>"`로 생성한다.
- Project 매니페스트 필수 필드, 게임 진입 계약, 필수 리소스 폴더처럼 빈 Project가 기본으로 가져야 할 구조가 바뀌면 같은 작업에서 `tools/create_project.py`, `tests_python/test_create_project.py`와 `docs/WORKFLOW.md`를 함께 갱신한다.
- 생성기는 Sample의 게임 규칙·노드·연출을 복사하지 않고 실행 가능한 최소 Project만 만든다.

## 코드 컨벤션

- 클래스 역할의 테이블과 파일 이름: `PascalCase`
- 변수와 함수: `camelCase`
- 상수: `UPPER_SNAKE_CASE`
- 들여쓰기: 공백 4칸
- 한 파일은 한 가지 책임만 가진다.

## 공통 UI 컴포넌트

- 스타일 독립적인 입력 상태와 동작은 `core/ui/`에 두고 `require("core").UI` 공개 API로 제공한다. Core UI는 Editor·Project의 색상, 배치, 렌더링과 도메인 검증을 소유하지 않는다.
- Editor와 각 Project의 UI 모듈은 `Core.UI`의 관련 컴포넌트를 기반으로 상속 또는 조합하고 화면별 스타일과 연결 동작만 구현한다. `core.ui.*` 내부 경로를 직접 불러오거나 커서 이동, 삽입·삭제, 필터링, 드롭다운 상태를 다시 구현하지 않는다.
- Lua에서는 구현 상속보다 Core UI 인스턴스의 조합을 우선한다. 공통 동작 자체를 확장해야 할 때만 Core 공개 API와 테스트를 함께 변경한다.
- UI 구현을 시작하기 전에 `Core.UI` 공개 API와 기존 Editor·Project UI를 검색해 재사용 가능한 동작이 있는지 확인한다. 같은 입력·선택·스크롤 동작을 두 화면에서 별도로 구현하지 않는다.
- 재사용할 공통 동작이 없으면 화면 코드에 먼저 만들지 않고 Core에 스타일 독립적인 Base 컴포넌트와 테스트를 추가한 뒤 Editor·Project에서 조합한다. 색상·배치·렌더링과 화면별 연결 동작만 각 모듈에 둔다.
- 현재 텍스트 입력은 `Core.UI.TextInput`, 선택·검색 목록은 `Core.UI.ComboBox`, 클릭 동작은 `Core.UI.Button`, 세로 스크롤 상태는 `Core.UI.ScrollArea`를 사용한다. RadioButton 등 요청되지 않은 컴포넌트는 미리 구현하지 않는다.

## 검증

- 기능 또는 버그 수정은 먼저 실패하는 테스트로 요구사항을 재현한다.
- 전체 자동 테스트는 `love . --test`로 실행한다.
- LÖVE 화면 변경은 `love .`로 직접 확인한다.
- Stage JSON은 PowerShell의 `ConvertFrom-Json`으로 문법을 확인한다.
- 완료를 보고하기 전에 실행한 명령과 결과를 `docs/HANDOFF.md`에 기록한다.

## 문서와 인수인계

- 사용자 대상 문서는 한국어로 작성한다.
- 공개 모듈 경계가 바뀌면 `docs/ARCHITECTURE.md`를 갱신한다.
- 제작 흐름이 바뀌면 `docs/WORKFLOW.md`를 갱신한다.
- Stage 필드가 바뀌면 `docs/STAGE_FORMAT.md`와 `schemaVersion` 정책을 함께 갱신한다.
- 각 작업을 마칠 때 `docs/ROADMAP.md`의 진행 상태와 `docs/HANDOFF.md`의 현재 상태, 검증 결과, 다음 작업을 갱신한다.
