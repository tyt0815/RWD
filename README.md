# RWD

RWD는 LÖVE2D 11.5로 여러 개의 리듬게임을 제작하기 위한 공통 코어, Stage 에디터와 게임 프로젝트 모음이다. 게임 화면에는 노트를 직접 표시하지 않으며, 플레이어는 사운드와 시각적 신호에 맞춰 입력한다.

## 현재 상태

공통 Launcher에서 Stage 에디터와 Sample Project를 열 수 있다. 에디터는 Stage JSON 버전 2를 만들고 열고 저장하며, Project 음악과 고정 BPM Transport를 Project Canvas에 맞춰 미리 재생한다. Editor 전용 Playback Rate와 Metronome, Timeline Scale을 Stage에 희소 저장한다.

Stage Event 실행, 리듬 판정, 타임라인 Event 배치·편집과 Project 입력 전달은 아직 구현하지 않았다.

## 실행 환경

- LÖVE2D 11.5
- Windows PowerShell 기준 명령

## 실행

```powershell
love .
```

- `E`: 에디터 열기
- `1`: Sample Project 열기
- `Esc`: Project 화면에서 Launcher로 돌아가기, Launcher에서는 종료

자동 테스트:

```powershell
love . --test
```

## Project 음악 배치

Project 음악은 `projects/<projectId>/assets/audio/` 또는 그 하위 폴더에 둔다. 에디터는 `.ogg`, `.mp3`, `.wav` 파일을 재귀 검색해 Music 선택 모달에 Project 상대 경로로 표시한다. 저작권이 있는 오디오 파일은 저장소에 추가하지 않는다.

## 에디터 Menu와 Properties

Launcher에서 `E`를 눌러 에디터를 연다. Menu는 마우스로 조작한다.

- `New`: Project, Stage ID, Name과 BPM으로 빈 Stage 생성
- `Open`: Project의 `stages/*.json` 열기
- `Save`: 현재 `<stageId>.json` 저장
- `Save As`: 같은 Project 안에 새 Stage ID로 저장
- `Play`: 현재 beat부터 Project Canvas, 음악과 선택한 메트로놈 재생
- `Pause`: 현재 beat를 보존하고 편집 화면으로 복귀
- `Quit`: 미저장 변경을 확인한 뒤 Launcher로 복귀

Stage가 수정되면 `Save*`로 표시된다. `Events`에서 선택한 Property 그룹에 따라 다음 순서로 `Properties | Values`가 표시된다.

- `Editor Properties`(기본 선택): Scale, Playback Rate, Metronome, Metronome Period
- `Mixtape Properties`: Music, Volume, Beat 0 Offset, BPM

Metronome은 BPM 한 박마다 한 번 울리며, Metronome Period는 클릭 속도가 아니라 강박 반복 길이입니다. Period 4는 `강 약 약 약`, Period 5는 `강 약 약 약 약`을 반복합니다.

숫자 Value는 셀을 클릭해 직접 편집한다. Enter 또는 다른 영역 클릭으로 확정하고 Escape로 취소한다. 유효하지 않은 값은 Stage에 적용하지 않고 빨간 테두리로 표시한다. boolean은 클릭 즉시 바뀌며 Music은 `None`과 현재 Project 파일 목록을 제공하는 모달에서 선택한다.

Timeline 위에 마우스를 두고 wheel을 돌리면 커서가 가리키는 beat를 유지한 채 Scale이 `0.25~8` 범위에서 바뀐다. Play 중에도 zoom할 수 있다. Music이 없어도 Play/Pause와 Project preview는 동작하며, 음악 decode 또는 preview 시작이 실패하면 Transport, Metronome과 TestPlayer를 모두 정지하고 오류 모달을 표시한다.

## 구조

```text
core/       공통 시간·음악·리듬게임 API
editor/     Stage 에디터와 Editor 전용 재생 도구
launcher/   개발용 모드 및 프로젝트 선택
projects/   서로 독립적인 게임 프로젝트
tests/      외부 프레임워크 없는 자동 테스트
docs/       아키텍처, 제작 흐름, Stage 형식, 로드맵, 인수인계
```

## 제작 방향

1. 프로젝트가 코드로 Pattern과 타임라인 Event를 정의한다.
2. 에디터가 프로젝트의 Categories와 Events를 표시한다.
3. 제작자가 Event 참조를 박자 기반 타임라인에 배치한다.
4. 에디터가 배치와 재생 설정을 Stage JSON으로 저장한다.
5. 런타임이 Pattern을 Tap Note와 Long Note 일정으로 전개한다.
6. 코어가 입력을 판정하고 프로젝트가 결과를 사운드·화면 연출로 표현한다.

자세한 내용은 `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `docs/STAGE_FORMAT.md`를 참고한다. 새 세션에서는 `docs/HANDOFF.md`를 먼저 확인한다.
