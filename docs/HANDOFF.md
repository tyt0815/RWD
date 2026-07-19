# 인수인계

## 현재 상태

프로젝트 초기화 단계가 완료되었다. LÖVE2D 11.5 공통 실행기에서 에디터 UI 골격과 Sample Project를 열 수 있다. 고정 BPM 재생 시계, Stage 문서 모델, 프로젝트 카탈로그와 프로젝트 범위 Stage 저장 경계가 추가되었다. 실제 리듬 판정과 Stage 선택 UI는 아직 없다.

## 완료된 작업

- Core, Editor, Launcher, Project의 공개 경계 생성
- 프로젝트 매니페스트와 Core API 버전 호환 검사
- 독립 Sample Project 화면과 빈 Tutorial Stage JSON 생성
- `Menu | Categories | Events | Properties | Values` 에디터 패널과 하단 타임라인 렌더링
- 외부 프레임워크 없는 16개 자동 테스트 작성
- 아키텍처, 제작 흐름, Stage 형식과 로드맵 문서 작성
- 고정 BPM 재생 시계와 Stage 버전 1 문서 검증
- 주입 가능한 프로젝트 카탈로그와 프로젝트 게임 생성 경계
- `projects/<projectId>/stages/<stageId>.json` 전용 Stage 목록, 로드와 원자 저장
- 공식 dkjson 2.10 원본과 MIT 라이선스 고정

## 최근 검증

- `love --version`: `LOVE 11.5 (Mysterious Mysteries)` 확인
- `C:\Program Files\LOVE\lovec.exe . --test`: `PASS: 42 tests` 확인
- `tutorial.json`: PowerShell `ConvertFrom-Json` 통과
- `vendor/dkjson.lua`: `dkjson 2.10`과 `Copyright (C) 2010-2026 David Heiko Kolf` 확인
- `vendor/dkjson.lua` SHA-256: `52F30BE905216796CCB1E97DA6135F3F5CFAAF6359544E66046E40F516A36B94`
- 금지된 내부 Core 의존성과 Project→Editor 의존성 없음
- `love .`: 실행 프로세스가 정상적으로 시작되어 응답하는 상태 확인
- 무시되는 GUI 스모크 하네스: 실제 `Launcher:keypressed` 호출로 Launcher→Editor→Launcher와 Launcher→Sample Project→Launcher 전환 후 각 프레임을 캡처해 화면과 두 `Esc` 복귀 동작 확인

Windows OS 키 주입은 `E`와 `1`을 SDL에 안정적으로 전달하지 못했으므로 검증 근거로 사용하지 않았다.

## 다음 작업

다음 개발 단위는 프로젝트와 Stage 선택 메뉴를 현재 에디터 상태에 연결하는 작업이다. StageStore는 파일 경계만 제공하므로 선택, 새 Stage, 열기와 저장 명령의 UI 상태 전이는 아직 구현하지 않는다.

## 현재 범위 밖인 기능

- 실제 리듬 판정
- Pattern 등록 및 전개
- Stage 선택 UI와 에디터 Event 편집
- 실시간 TestPlayer
- 독립 게임 패키징

## 세션 재개 순서

1. `README.md`를 읽는다.
2. `docs/ARCHITECTURE.md`와 `docs/ROADMAP.md`를 확인한다.
3. `love . --test`를 실행한다.
4. 다음 작업인 프로젝트와 Stage 선택 메뉴 연결 범위를 확인한다.
