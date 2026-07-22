# 인수인계

## 현재 상태

LÖVE2D 11.5 Launcher에서 Sample Project와 Stage 에디터를 열 수 있다. 에디터 Menu의 `New | Open | Save | Save As | Play | Pause | Quit` 일곱 항목, dirty 상태의 `Save*` 표시와 New/Open/Quit의 Save/Discard/Cancel 보호가 연결되었다. 실제 source 폴더에 Stage JSON을 저장·열고, BPM을 편집하며, 고정 BPM clock과 Project Canvas로 테스트 플레이한 뒤 beat를 보존해 편집 화면으로 돌아올 수 있다.

Project Canvas는 표시하지만 Stage Event는 실행하지 않는다. Event 실행, 오디오 동기화, 리듬 판정과 Project 입력 전달은 아직 구현하지 않았다.

## 완료된 작업

- Core, Editor, Launcher, Project의 공개 경계 생성
- 프로젝트 매니페스트와 Core API 버전 호환 검사
- 독립 Sample Project 화면과 빈 Tutorial Stage JSON 생성
- `Menu | Categories | Events | Properties | Values` 에디터 패널과 하단 타임라인 렌더링
- 외부 프레임워크 없는 89개 자동 테스트 작성
- 아키텍처, 제작 흐름, Stage 형식과 로드맵 문서 작성
- 고정 BPM 재생 시계와 Stage 버전 1 문서 검증
- 주입 가능한 프로젝트 카탈로그와 프로젝트 게임 생성 경계
- `projects/<projectId>/stages/<stageId>.json` 전용 Stage 목록, 로드와 원자 저장
- 네이티브 sourceRoot로 통일한 Stage 목록·읽기·존재 확인·쓰기와 save-only/shadow 제외
- Stage JSON 객체·배열 종류 검증과 `params` 내부 null 보존, null Event·`params: null` 거부
- `createGame(project)`로 프로젝트 앱을 생성하고 Canvas 크기로 그리는 TestPlayer
- Stage 생성·열기·저장, BPM, 재생과 타임라인 추적을 조정하는 EditorSession
- Launcher 창 크기와 TestPlayer Canvas 크기를 구분하는 프로젝트 `draw(width, height)` 계약
- 공식 dkjson 2.10 원본과 MIT 라이선스 고정
- Menu 일곱 항목과 마우스 hit test, Stage New/Open/Save/Save As, dirty 확인 모달 연결
- `Global → Mixtape Properties`의 BPM 표시·편집과 `Save*` 상태 표시
- Play/Pause의 고정 BPM clock, Project Canvas 전환과 자동 플레이헤드 추적
- Launcher가 Editor에 `ProjectLoader.createGame`과 `onQuit`을 주입하고 포인터·문자 입력을 전달하는 경계

## 최근 검증

- sourceRoot·null·JSON 종류 focused 테스트: `PASS: 13 focused tests`, `PASS: 14 focused tests` 확인
- `C:\Program Files\LOVE\lovec.exe --version`: `LOVE 11.5 (Mysterious Mysteries)` 확인
- `C:\Program Files\LOVE\lovec.exe . --test`: `PASS: 89 tests` 확인
- `projects` 아래 JSON 1개: PowerShell `ConvertFrom-Json` 통과
- 실제 source Stage 왕복: `PASS: native Stage save/open round trip`, 실행 전후 `projects/sample/stages/editor-menu-smoke.json` 부재 확인
- production Launcher GUI 하네스: `PASS: editor menu GUI smoke`, `launcher → editor → new → save → open → play → pause → launcher` 확인
- GUI 캡처 8개 생성. `launcher.png`와 `launcher-return.png` SHA-256은 모두 `1E94559FAD2141002CCB83260BE39E5A6D95D613715AD192B504325648FFDA9B`
- `new-dialog.png`, `editor-dirty.png`, `playing.png`, `paused.png`를 직접 확인해 New 필드, `Save*`와 BPM 123, Project Canvas, Pause 뒤 Properties/Values와 BPM 123 복원을 확인
- `vendor/dkjson.lua`: `dkjson 2.10`과 `Copyright (C) 2010-2026 David Heiko Kolf` 확인
- dkjson 공식 URL: `https://dkolf.de/dkjson-lua/dkjson-2.10.lua`
- `vendor/dkjson.lua` SHA-256: `52F30BE905216796CCB1E97DA6135F3F5CFAAF6359544E66046E40F516A36B94`
- 금지된 내부 Core 의존성과 Project→Editor 의존성 없음
- `StageDocument`의 `vendor.dkjson` 직접 의존성 없음
- `love .`: 실제 `RWD` 창의 `Responding=True`와 정상 종료 확인. Windows `PostMessage`의 `E`는 SDL에 전달되지 않아 실제 창에서 Editor 진입은 확인하지 못함
- `git diff --check`: 출력 없음

Windows OS 키 주입은 `E`를 SDL에 전달하지 못했으므로 Editor 기능 검증 근거로 사용하지 않았다. Editor 진입과 Menu 화면은 production Launcher를 사용하는 프레임 기반 GUI 하네스로 검증했다.

## 다음 작업

다음 개발 단위는 Project Event 등록 계약을 정의하고 Stage Event를 TestPlayer 실행에 연결하는 작업이다. 등록되지 않은 `patternId`의 오류 보고 기준도 이 계약에 포함한다.

## 현재 범위 밖인 기능

- 실제 리듬 판정
- Pattern 등록 및 참조 전개
- Stage Event 실행과 에디터 Event 배치·편집
- 오디오 동기화
- TestPlayer의 Project 입력 전달
- 독립 게임 패키징

## 세션 재개 순서

1. `README.md`를 읽는다.
2. `docs/ARCHITECTURE.md`와 `docs/ROADMAP.md`를 확인한다.
3. `love . --test`를 실행한다.
4. Project Event 등록 계약과 Stage Event 실행 연결 범위를 확인한다.
