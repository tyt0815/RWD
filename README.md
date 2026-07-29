# RWD

RWD는 LÖVE2D 11.5로 여러 개의 리듬게임을 제작하기 위한 공통 코어, Stage 에디터와 게임 프로젝트 모음이다. 게임 화면에는 노트를 직접 표시하지 않으며, 플레이어는 사운드와 시각적 신호에 맞춰 입력한다.

## 현재 상태

공통 Launcher에서 Stage 에디터, Sample Project와 Rhythm Dotgeo Project를 열 수 있다. Rhythm Dotgeo는 열릴 때 Stage 목록을 표시하고 항목을 클릭하면 Stage 음악·beat와 공통 관리 노드 실행을 시작한다. 에디터는 Stage JSON 버전 2를 만들고 열고 저장하며, Project 음악과 고정 BPM Transport를 Project Canvas에 맞춰 미리 재생한다. Editor 전용 Playback Rate, Metronome, Timeline Scale, Snap, Onset Threshold와 preview 화면 비율을 Stage에 희소 저장한다.

Core StageRuntime이 End와 Set Input Enabled, Project Event의 beat 순서 실행과 시작 위치 상태 복원을 공통 처리한다. ProjectCategories는 `game/<CategoryName>/Definition.lua`와 `Runtime.lua`를 자동 발견해 기존 manifest와 Game 수정 없이 Editor 등록과 런타임 실행을 연결한다. Game Manager의 End와 Set Input Enabled Event를 편집할 수 있다. Sample Project는 Tap 판정 예제를 제공한다. Rhythm Dotgeo의 `스피키송` Category는 배경·좌피키·좌우 반전 우피키 소환, 턴, Tap 큐 응답과 길이를 설정하는 Long Note 큐 응답을 제공한다. Core는 누름·뗌을 함께 처리하는 beat 기반 Long Note 판정을 제공하며 일반 Pattern 전개는 아직 구현하지 않았다.

## 실행 환경

- LÖVE2D 11.5
- Windows PowerShell 기준 명령
- 기본 창 해상도: 1920×1080(FHD), 최소 크기 1280×720, 비율 제한 없이 크기 조절 가능
- 기본 UI 폰트: `assets/fonts/D2Coding-Ver1.3.3-20260725-all.ttc` 14px

## 실행

```powershell
love .
```

- `E`: 에디터 열기
- `1`: Sample Project 열기
- `2`: Rhythm Dotgeo Project의 Stage 선택 화면 열기
- `Esc`: Project 화면에서 Launcher로 돌아가기, Launcher에서는 종료

자동 테스트:

```powershell
love . --test
python -m unittest discover -s tests_python -v
```

## 새 Project 생성

저장소 루트에서 Project ID와 표시 이름을 지정한다.

```powershell
python tools/create_project.py my-game "My Game"
```

생성기는 `projects/my-game/` 아래에 현재 Core API 버전의 매니페스트, 최소 게임 진입 모듈, Stage와 음악·효과음·이미지 폴더를 만든다. Project ID는 소문자 영숫자로 시작하고 이후 소문자 영숫자, `_`, `-`만 사용할 수 있다. 기존 Project는 덮어쓰지 않는다.

## Project 음악 배치

Project 음악은 `projects/<projectId>/assets/audio/music/` 또는 그 하위 폴더에, 효과음은 `assets/audio/sfx/`에 둔다. 에디터는 `music/` 아래의 `.ogg`, `.mp3`, `.wav` 파일만 재귀 검색해 Music 선택 모달에 Project 상대 경로로 표시한다. 저작권이 있는 오디오 파일은 저장소에 추가하지 않는다.

## 에디터 Menu와 Properties

Launcher에서 `E`를 눌러 에디터를 연다. Menu는 마우스로 조작한다.

- `New`: Project, Stage ID, Name과 BPM으로 빈 Stage 생성
- `Open`: Project의 `stages/*.json` 열기
- `Save`: 현재 `<stageId>.json` 저장
- `Save As`: 같은 Project 안에 새 Stage ID로 저장
- `Play`: 클릭으로 지정한 기준 beat부터 Project Canvas, 음악과 선택한 메트로놈 재생
- `Pause`: 재생 위치 바를 숨기고 기준 beat를 유지한 채 편집 화면으로 복귀
- `Quit`: 미저장 변경을 확인한 뒤 Launcher로 복귀

Stage가 수정되면 `Save*`로 표시된다. 상단 패널은 헤더 아래에 15개 행이 들어가는 고정 높이를 사용하고 Timeline은 그 아래의 남은 화면을 사용한다. Categories와 Events는 각각 독립적으로 스크롤하며 Properties와 Values는 행이 어긋나지 않도록 함께 스크롤한다. 내용이 패널을 넘을 때만 오른쪽에 얇은 스크롤바가 표시된다. `Events`에서 선택한 Property 그룹에 따라 다음 순서로 `Properties | Values`가 표시된다.

- `Editor Properties`(기본 선택): Snap, Scale, Playback Rate, Auto Play, Metronome, Metronome Period, Track, Preview Aspect Width, Preview Aspect Height
- `Mixtape Properties`: Music, Volume, Beat 0 Offset, Onset Threshold, BPM

Metronome은 BPM 한 박마다 한 번 울리며, Metronome Period는 클릭 속도가 아니라 강박 반복 길이입니다. Period 4는 `강 약 약 약`, Period 5는 `강 약 약 약 약`을 반복합니다.

Project, Stage, Music과 Auto Play 선택은 공통 ComboBox를 사용한다. 선택값을 클릭하면 해당 한 줄이 검색 입력으로 바뀌고 그 아래에 목록이 열리며, 타이핑으로 필터링한 뒤 마우스 또는 위·아래 방향키와 Enter로 선택한다. Escape는 열린 목록을 닫는다. Music 선택 시 Beat 0 Offset이 기본값 `0`이면 첫 소리를 자동으로 찾아 설정하며, Offset 오른쪽의 `Auto` 버튼으로 언제든 다시 분석할 수 있다. Onset Threshold는 연속된 10ms RMS 창이 설정값보다 커지는 첫 위치를 정하며 기본값 `0.01`은 작은 압축 노이즈를 건너뛴다.

에디터의 Dialog 입력과 숫자 Values는 공통 텍스트 입력 동작을 사용한다. 포커스되면 값 끝에 깜빡이는 커서가 바로 표시되며, 첫 입력부터 현재 커서 위치에 이어서 입력한다. 좌우 방향키로 커서를 옮겨 중간에 입력하거나 Backspace/Delete로 삭제할 수 있다. Enter 또는 다른 영역 클릭으로 확정하고 Escape로 취소한다. 유효하지 않은 값은 Stage에 적용하지 않고 빨간 테두리로 표시한다. boolean은 클릭 즉시 바뀌며 Music은 `None`과 현재 Project 파일 목록을 제공하는 모달에서 선택한다.

`Game Manager` Category에는 보라색 `End`와 청록색 `Set Input Enabled`가 있다. 두 관리 노드는 beat 길이와 무관하므로 왼쪽이 beat 선에 맞는 `0.25 beat` 폭을 사용한다. Event 행을 선택하고 Timeline 본문을 우클릭하면 커서가 들어간 Snap 박스의 시작 beat와 Track에 노드가 배치된다. 해당 beat 영역에 다른 노드가 있으면 배치하지 않고 화면 우상단에 3초간 에러 토스트를 표시한다. 토스트는 최신순으로 최대 5개까지 쌓이며 각각 독립적으로 사라진다. 노드 이름은 1px 어두운 윤곽선과 함께 박스 내부에 표시되고, 폭을 넘는 부분은 잘리며 마우스를 올리면 윤곽선을 유지한 전체 이름이 표시된다. 노드를 좌클릭하거나 드래그하면 해당 노드가 흰색 선택 상태가 되고, `Ctrl+클릭`으로 여러 노드를 선택·해제할 수 있다. 빈 배경 drag는 선택 사각형과 일부라도 겹친 노드를 한꺼번에 선택하며 `Ctrl+drag`는 기존 선택에 추가한다. 선택된 노드 하나를 drag하면 전체 선택이 간격을 유지한 채 함께 움직인다. 이동 preview는 반투명 흰색이며 가변 beat 폭 영역이 다른 노드와 겹치면 충돌 양쪽을 빨간색으로 표시하고, 이 상태로 놓으면 원래 위치로 돌아가고 같은 에러 토스트를 표시한다. `Delete`는 선택된 노드를 모두 삭제한다. `Set Input Enabled` Event를 선택하면 Properties/Values에서 새 노드의 `Enabled` 기본값을 정할 수 있고, 배치된 노드를 더블클릭하면 노드별 값을 다시 편집할 수 있다. 입력은 기본적으로 활성화되며 재생 중 이 Event 값으로 바뀐다. `End`는 Stage에 하나만 둘 수 있고 두 번째 배치는 에러 토스트로 거부된다. `End`에 도달하면 에디터 재생이 끝나며, End가 없는 Stage는 Music이 끝나는 순간 자동 종료되고 정보 토스트를 표시한다. Music도 End도 없으면 기존처럼 계속 재생된다.

Timeline 위에 마우스를 두고 wheel을 돌리면 커서가 가리키는 beat를 유지한 채 Scale이 `0.25~8` 범위에서 바뀐다. Timeline은 왼쪽 첫 칸을 비워 둔 뒤 그 오른쪽 경계선부터 beat를 배치하며, 번호는 경계선 중앙에 현재 Metronome Period 간격으로 표시된다. 일시정지 상태에서는 번호가 있는 Timeline 상단을 좌클릭하거나 드래그해 Snap 간격으로 주황색 기준 바를 옮길 수 있다. Play 중에는 기준 바를 유지한 채 하늘색 재생 위치 바가 별도로 나타나 시간에 따라 이동한다. Pause하면 재생 위치 바가 사라지고, 다음 Play는 일시정지 위치가 아니라 기준 바에서 다시 시작한다. 드래그 중 좌우 끝에 머물면 보이는 구간이 자동 이동하며 마우스와 기준 바의 수평 거리가 클수록 빨라진다. Timeline 안을 마우스 중간 버튼으로 드래그하면 보이는 구간이 이동한다. `F`는 Play/Pause를 전환하고 `Ctrl+S`는 저장하며, `R`은 재생을 멈춘 뒤 기준 beat와 Timeline 시작 위치를 0으로 되돌린다. Play 중에도 zoom과 구간 이동을 사용할 수 있다. Music이 없어도 Play/Pause와 Project preview는 동작한다. Preview는 기본 `16:9`이며 Preview Aspect Width와 Height로 정한 비율을 유지한 채 Properties·Values 영역 중앙에 최대 크기로 표시된다. 음악 decode 또는 preview 시작이 실패하면 Transport, Metronome과 TestPlayer를 모두 정지하고 오류 모달을 표시한다. Auto Play 기본값은 `None`이며 `Good`, `Bad`, `Miss`를 선택하면 Play 중 Project가 해당 판정을 자동으로 발생시킨다.

## 구조

```text
core/       공통 시간·음악·리듬게임과 스타일 독립 UI API
editor/     Stage 에디터와 Editor 전용 재생 도구
launcher/   개발용 모드 및 프로젝트 선택
projects/       서로 독립적인 게임 프로젝트
tools/          Project 생성 등 개발용 도구
tests/          외부 프레임워크 없는 LÖVE 자동 테스트
tests_python/   개발용 Python 도구 테스트
docs/           아키텍처, 제작 흐름, Stage 형식, 로드맵, 인수인계
```

## 제작 방향

1. 프로젝트가 코드로 Pattern과 타임라인 Event를 정의한다.
2. 에디터가 프로젝트의 Categories와 Events를 표시한다.
3. 제작자가 Event 참조를 박자 기반 타임라인에 배치한다.
4. 에디터가 배치와 재생 설정을 Stage JSON으로 저장한다.
5. 런타임이 Pattern을 Tap Note와 Long Note 일정으로 전개한다.
6. 코어가 입력을 판정하고 프로젝트가 결과를 사운드·화면 연출로 표현한다.

자세한 내용은 `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `docs/STAGE_FORMAT.md`를 참고한다. 새 Project 게임플레이 노드 제작은 `docs/PROJECT_NODES_TUTORIAL.md`에 설명되어 있다. 새 세션에서는 `docs/HANDOFF.md`를 먼저 확인한다.
