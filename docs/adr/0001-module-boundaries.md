# Core, Launcher, Editor, Project의 의존 방향

Status: Accepted

Decision: `core/`는 리듬게임 공통 규칙과 스타일 독립적인 공통 UI 동작을 소유한다. `editor/`와 `projects/`는 `require("core")` 공개 진입점만 사용하고, Project는 Editor를 불러오지 않는다. `launcher/`는 모듈을 조립하지만 게임 규칙이나 Editor 기능을 구현하지 않는다.

Reason: 공통 규칙, 제작 도구, 게임별 표현을 분리해야 Editor를 교체해도 Core와 Project를 독립적으로 유지할 수 있다.
