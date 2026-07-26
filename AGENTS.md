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
