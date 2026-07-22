# RWD

RWD는 LÖVE2D 11.5로 여러 개의 리듬게임을 제작하기 위한 코어, 스테이지 에디터와 게임 프로젝트 모음이다. 게임 화면에는 노트를 직접 표시하지 않으며, 플레이어는 사운드와 시각적 신호에 맞춰 입력한다.

## 현재 상태

공통 실행기에서 에디터와 Sample Project를 열 수 있다. 에디터 Menu에서 Stage를 만들고 열고 저장하며, 고정 BPM 시계와 Sample Project Canvas를 사용해 테스트 플레이할 수 있다. Stage Event 실행, 오디오 동기화, 리듬 판정, 타임라인 Event 편집과 Project 입력 전달은 아직 구현하지 않았다.

## 실행 환경

- LÖVE2D 11.5
- Windows PowerShell 기준 명령

## 실행

```powershell
love .
```

- `E`: 에디터 열기
- `1`: Sample Project 열기
- `Esc`: Project 화면에서 실행기로 돌아가기, 실행기에서는 종료

자동 테스트:

```powershell
love . --test
```

## 에디터 Menu

Launcher에서 `E`를 눌러 에디터를 연다. 에디터 Menu는 마우스로 조작한다.

- `New`: Project, Stage ID, Name과 BPM으로 빈 Stage 생성
- `Open`: Project의 `stages/*.json` 열기
- `Save`: 현재 `<stageId>.json` 저장
- `Save As`: 같은 Project 안에 새 Stage ID로 저장
- `Play`: 현재 beat부터 Project 화면 미리보기와 플레이헤드 재생
- `Pause`: 현재 beat를 보존하고 편집 화면으로 복귀
- `Quit`: 미저장 변경을 확인한 뒤 Launcher로 복귀

Stage가 수정되면 `Save*`로 표시된다. 에디터 화면에서 Escape는 Menu Quit을 대신하지 않으며, 모달 취소에만 사용한다.

## 구조

```text
core/       공통 리듬게임 API
editor/     Stage 에디터와 TestPlayer 경계
launcher/   개발용 모드 및 프로젝트 선택
projects/   서로 독립적인 게임 프로젝트
tests/      외부 프레임워크 없는 스모크 테스트
docs/       아키텍처, 제작 흐름, Stage 형식, 로드맵, 인수인계
```

## 제작 방향

1. 프로젝트가 코드로 Pattern과 타임라인 Event를 정의한다.
2. 에디터가 프로젝트의 Categories와 Events를 표시한다.
3. 제작자가 Event 참조를 박자 기반 타임라인에 배치한다.
4. 에디터가 배치 정보를 Stage JSON으로 저장한다.
5. 런타임이 Pattern을 Tap Note와 Long Note 일정으로 전개한다.
6. 코어가 입력을 판정하고 프로젝트가 결과를 사운드·화면 연출로 표현한다.

자세한 내용은 `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `docs/STAGE_FORMAT.md`를 참고한다. 새 세션에서는 `docs/HANDOFF.md`를 먼저 확인한다.
