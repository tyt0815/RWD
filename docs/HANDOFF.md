# 인수인계

## 현재 상태

프로젝트 초기화 단계가 완료되었다. LÖVE2D 11.5 공통 실행기에서 에디터 UI 골격과 Sample Project를 열 수 있다. Core는 API 버전과 네 가지 판정 결과 상수만 제공하며 실제 리듬 판정은 아직 없다.

## 완료된 작업

- Core, Editor, Launcher, Project의 공개 경계 생성
- 프로젝트 매니페스트와 Core API 버전 호환 검사
- 독립 Sample Project 화면과 빈 Tutorial Stage JSON 생성
- `Menu | Categories | Events | Properties | Values` 에디터 패널과 하단 타임라인 렌더링
- 외부 프레임워크 없는 14개 자동 테스트 작성
- 아키텍처, 제작 흐름, Stage 형식과 로드맵 문서 작성

## 최근 검증

- `love --version`: `LOVE 11.5 (Mysterious Mysteries)` 확인
- `love . --test`: `PASS: 14 tests` 확인
- `tutorial.json`: PowerShell `ConvertFrom-Json` 통과
- 금지된 내부 Core 의존성과 Project→Editor 의존성 없음
- `love .`: 실행 프로세스가 정상적으로 시작되어 응답하는 상태 확인
- 무시되는 GUI 스모크 하네스: 실제 `Launcher:keypressed` 호출로 Launcher→Editor→Launcher와 Launcher→Sample Project→Launcher 전환 후 각 프레임을 캡처해 화면과 두 `Esc` 복귀 동작 확인

Windows OS 키 주입은 `E`와 `1`을 SDL에 안정적으로 전달하지 못했으므로 검증 근거로 사용하지 않았다.

## 다음 작업

다음 개발 단위는 고정 BPM 재생 시계다. 구현 전에 박자 기준 시각, 오디오 재생 위치 보정 방식, 일시정지와 위치 이동 동작을 별도 설계로 확정한다. Tap/Long Note 판정 허용 범위와 Long Note 판정 방식은 재생 시계 이후 별도 설계한다.

## 현재 범위 밖인 기능

- 실제 리듬 판정
- Stage JSON 로딩과 검증
- Pattern 등록 및 전개
- 에디터 Event 편집과 저장
- 실시간 TestPlayer
- 독립 게임 패키징

## 세션 재개 순서

1. `README.md`를 읽는다.
2. `docs/ARCHITECTURE.md`와 `docs/ROADMAP.md`를 확인한다.
3. `love . --test`를 실행한다.
4. 다음 작업인 고정 BPM 재생 시계를 설계한다.
