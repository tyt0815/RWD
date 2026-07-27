# 게임 제작 워크플로우

## 1. Project 생성

저장소 루트에서 생성기를 실행한다.

```powershell
python tools/create_project.py my-game "My Game"
```

Project ID는 소문자 영숫자로 시작하고 이후 소문자 영숫자, `_`, `-`만 사용할 수 있으며 Windows 예약 이름은 사용할 수 없다. 생성기는 기존 경로를 덮어쓰지 않고 다음 실행 가능한 최소 구조를 만든다.

```text
projects/my-game/
├─ project.lua
├─ game/Game.lua
├─ game/events/README.md
├─ stages/README.md
└─ assets/
   ├─ audio/music/README.md
   ├─ audio/sfx/README.md
   └─ image/README.md
```

`project.lua`는 생성 시점의 `core/init.lua`에서 Core API 버전을 읽고 Project ID, 표시 이름과 `projects.<projectId>.game.Game` 진입 모듈을 선언한다. `Game.lua`는 Launcher와 Editor preview에서 실행 가능한 `new`, `startStage`, `update`, `draw` 계약과 Core `StageRuntime` 조합만 제공하며 Sample의 노드나 게임 규칙은 복사하지 않는다. 생성자의 선택적 두 번째 인자 `options.stageStore`에는 검증된 Stage 목록과 데이터를 읽는 Store가 주입된다. Project Event 구현은 `game/events/<CategoryName>/<EventName>.lua`에 두고 Sprite, SFX, 이동처럼 Project별로 달라지는 동작만 작성한다. 게임별 UI, 사운드, 연출과 리소스는 해당 Project 밖으로 새지 않게 한다.

## 2. Project 오디오 배치

음악 파일은 `projects/<projectId>/assets/audio/music/` 또는 그 하위 폴더에, 효과음은 `assets/audio/sfx/`에 둔다. 지원 확장자는 `.ogg`, `.mp3`, `.wav`다. 에디터 Music 모달은 `music/`만 재귀 검색해 `assets/audio/music/...` Project 상대 경로로 표시하므로 SFX는 목록에 포함되지 않는다. 저작권이 있는 파일은 저장소에 추가하지 않는다.

## 3. Pattern 작성과 에디터 등록

Pattern은 여러 beat에 걸친 신호와 플레이어 반응을 코드로 묶는 재사용 단위다. Core가 판정할 원시 노트 종류는 Tap Note와 Long Note이며, Pattern은 실행 시 이 두 노트의 일정을 생성한다.

내장 `Game Manager` Category는 `End`와 `Set Input Enabled` Event를 제공한다. Core `StageRuntime`이 모든 Stage Event의 beat 순서 실행, 중간 시작 catch-up, 입력 활성 상태와 End를 공통 처리한다. Project는 manifest의 `eventCategories`로 Project 전용 Category, Event, number 프로퍼티와 Timeline geometry를 등록하고 Category/Event별 Lua 파일에서 연출을 구현한다. 자세한 제작 순서는 `docs/PROJECT_NODES_TUTORIAL.md`를 따른다. 일반 Pattern 등록과 전개는 아직 구현하지 않았다.

## 4. Stage 생성과 재생 속성 편집

현재 제작 순서는 다음과 같다.

```text
Project audio 배치 → New/Open → Mixtape Properties에서 Music 선택
→ 첫 소리 자동 검출 또는 Beat 0 Offset·Volume·BPM 편집 → Editor Properties에서 디버깅 설정
→ wheel zoom·Snap 재생 바 이동·중간 버튼 pan으로 Timeline 탐색 → Save/Save As → Test Play → Pause
```

New는 Project, Stage ID, Name과 BPM으로 `events: []`인 schemaVersion 2 Stage를 만든다. New와 Save As의 텍스트 필드는 Values와 같은 공통 입력 모듈을 사용해 UTF-8 중간 삽입·삭제, 좌우 커서 이동과 커서 깜빡임을 지원한다. New/Open의 Project·Stage, Music과 Auto Play 선택은 공통 ComboBox를 사용하며, 클릭해 선택값 한 줄을 검색 입력으로 전환하고 아래 목록을 검색어로 필터링한 뒤 마우스 또는 위·아래 방향키와 Enter로 선택한다. Open, Save와 Save As는 선택한 Project의 `stages` 폴더 안에서만 동작한다. 수정된 Stage의 Menu에는 `Save*`가 보이고 New, Open, Quit은 Save/Discard/Cancel 확인을 거친다.

`Mixtape Properties`는 다음 순서다.

1. Music: `None` 또는 현재 Project의 `assets/audio/music/` 아래 음악 파일 선택
2. Volume: `0.0~1.0`
3. Beat 0 Offset: 음악 시작을 논리 beat 0과 맞추는 seconds 값. Music 선택 시 현재 값이 기본값 `0`이면 첫 소리 위치를 자동 설정하고, 오른쪽 `Auto` 버튼은 현재 값과 관계없이 다시 분석한다.
4. Onset Threshold: Beat 0 Offset Auto 분석의 RMS 기준 `0.0~1.0`. 저장은 Editor 전용 설정이며 기본값 `0.01`은 작은 압축 노이즈를 제외하는 일반 권장값이다.
5. BPM: 0보다 큰 유한 값

`Editor Properties`는 다음 순서다.

1. Snap: Timeline 재생 바와 Event 노드를 맞출 박자 간격 `1~32`. 값 1은 한 박, 값 4는 네 박 크기의 노드 스냅 박스를 뜻한다.
2. Scale: Timeline 확대 배율 `0.25~8.0`
3. Playback Rate: Editor preview 속도 `0.25~4.0`
4. Auto Play: 기본값 `None`. `Good`, `Bad`, `Miss` 선택 시 Play 중 Project가 해당 판정을 자동 실행한다.
5. Metronome: Editor 디버깅 click 사용 여부
6. Metronome Period: BPM 한 박마다 울리는 클릭을 몇 박 단위로 강박 그룹화할지 지정한다. 값 4는 `강 약 약 약`을 반복한다.
7. Track: Timeline Track 수 `1~32`. 기본값은 `10`이며 현재 노드가 있는 Track보다 작게 줄일 수 없다.
8. Preview Aspect Width: Editor Play 화면 비율의 너비. 기본값은 `16`이며 0보다 커야 한다.
9. Preview Aspect Height: Editor Play 화면 비율의 높이. 기본값은 `9`이며 0보다 커야 한다.

숫자 Value는 셀을 클릭하면 값 끝에 깜빡이는 커서가 바로 표시된다. 공통 입력 모듈에 숫자 필터를 적용하며 첫 입력부터 현재 커서 위치에 이어서 입력한다. 좌우 방향키로 커서를 옮겨 중간 삽입하고 Backspace/Delete로 커서 주변 문자를 삭제할 수 있다. Enter 또는 다른 영역 클릭은 유효한 값을 확정하며 Escape는 취소한다. boolean은 클릭 즉시 바뀐다. 기본값과 같은 선택 속성은 저장 JSON에서 제거된다.

첫 소리 분석은 Project Music을 청크 단위로 읽고 채널 평균 10ms RMS가 Onset Threshold보다 큰 구간이 20ms 이상 이어지는 첫 위치를 사용한다. 순간 노이즈는 줄이지만 음악적 첫 박자를 찾는 기능은 아니다. 분석 실패나 유효한 소리를 찾지 못하면 Music 선택은 유지하고 Offset은 바꾸지 않은 채 오류 모달을 표시한다.

`Game Manager`에서 Event 행을 고른 뒤 Timeline 본문을 우클릭하면 해당 Track에서 커서가 들어간 Snap 박스의 시작 beat에 노드가 생긴다. 노드 drag도 같은 규칙을 사용하며 Snap 1은 한 박 크기 박스, Snap 4는 네 박 크기 박스마다 시작 위치가 정해진다. 같은 Track의 beat 폭 영역에 기존 노드가 겹치면 생성하지 않고 화면 우상단에 3초간 error toast를 표시한다. toast는 최신순으로 최대 5개까지 세로로 쌓이고 각자 만료된다. 노드는 좌클릭 또는 drag 시작 시 흰색 선택 상태가 되며, `Ctrl+클릭`으로 선택을 추가하거나 해제한다. 빈 배경 drag는 선택 사각형과 일부라도 겹친 노드를 선택하고 `Ctrl+drag`는 기존 선택에 추가한다. 선택된 노드를 drag하면 선택 전체가 beat·Track 간격을 유지한 채 이동 preview로 표시된다. preview 노드는 반투명 흰색이며, 같은 Track의 beat 폭 영역이 고정 노드와 겹치면 충돌 양쪽이 빨간색이 되고 놓을 때 전체 이동을 취소하고 같은 error toast를 추가한다. 유효한 이동만 한 번에 Stage에 반영된다. `Delete`는 선택된 모든 노드를 Stage에서 삭제한다. 보라색 `End`는 Stage에 하나만 둘 수 있는 종료 지점이며 두 번째 배치는 error toast로 거부된다. 청록색 `Set Input Enabled`는 노드별 `Enabled` boolean을 가진다. 두 관리 노드는 박자 길이와 무관해 beat 선에서 시작하는 `0.25 beat` 폭을 사용한다. 게임플레이 노드는 명시된 beat 길이를 사용하며 생략 시 기본 폭은 `1 beat`다. Event 행을 선택하면 Properties/Values에서 새 노드에 적용할 값을 먼저 정할 수 있으며 이 선택값 자체는 Stage를 수정하지 않는다. 배치된 노드는 더블클릭해 전용 모달에서 값을 다시 수정한다.

Timeline 위의 wheel zoom은 커서가 가리키는 beat를 화면의 같은 x에 유지한다. 일시정지 상태에서는 번호가 표시되는 Timeline 상단을 좌클릭하면 주황색 기준 바가 가장 가까운 Snap beat로 즉시 이동하며, 누른 채 drag하면 계속 이동한다. 좌우 끝 32px 안에서 drag를 유지하면 기본 초당 8박에 마우스와 기준 바의 수평 거리 1박당 초당 8박을 더한 속도로 보이는 구간과 기준 바가 함께 이동하며 최대 속도는 초당 64박이다. Play 중에는 기준 바와 별도로 하늘색 재생 위치 바가 시간에 따라 이동하고, Pause하면 재생 위치 바만 사라진다. Timeline 안을 마우스 중간 버튼으로 드래그하면 보이는 구간을 이동하며 시작 beat는 0 아래로 내려가지 않는다. zoom과 구간 이동은 Play 중에도 사용할 수 있으며 직접 Scale Value를 편집할 때는 현재 Timeline 시작 beat를 바꾸지 않는다. 재생 바 이동과 구간 이동은 Stage 저장 데이터와 dirty 상태를 바꾸지 않는다.

`F`는 Play와 Pause를 전환하고 `Ctrl+S`는 현재 Stage를 저장한다. `R`은 재생 중이면 먼저 Pause한 뒤 기준 바와 Timeline 시작 위치를 beat 0으로 되돌린다. Dialog나 숫자 Value를 편집 중일 때는 이 단축키를 실행하지 않으며 key repeat도 무시한다.

## 5. Test Play

Play는 클릭으로 지정한 기준 beat부터 다음 구성 요소를 함께 시작한다. Pause 뒤 다시 Play해도 직전 재생 위치에서 이어가지 않고 같은 기준 beat에서 새로 시작한다.

- Core `PlaybackTransport`: 논리 시간, beat, Music Offset과 pitch
- `TestPlayer`: Project Canvas와 Playback Rate가 적용된 update deltaTime
- 선택한 경우 `MetronomePlayback`: 같은 BPM, 현재 beat와 Playback Rate

Music이 `None`이어도 Transport와 Project preview는 정상 동작한다. Project preview는 Preview Aspect Width와 Height의 비율을 유지하면서 Properties·Values 영역 안에 들어가는 최대 크기로 중앙 정렬된다. 음수 Offset이면 음악 위치가 0이 될 때 시작하고, 양수 Offset이면 해당 위치부터 시작한다. End Event가 있으면 음악 duration 이후에도 Timeline beat와 Project preview는 End까지 계속 진행한다. End가 없으면 Music duration에서 자동 종료한다. Pause는 기준 beat를 보존하고 모든 재생 구성 요소를 정지한 뒤 재생 위치 바를 숨기고 Properties/Values 편집 화면으로 돌아온다.

decode, Source, preview 시작·update·draw가 실패하면 오류 모달을 표시하고 `EditorSession:pause()`를 통해 Transport, Metronome과 TestPlayer를 함께 정리한다. TestPlayer update 실패는 pause 뒤 이전 beat로 rollback한다.

현재 preview는 현재 Stage와 기준 beat를 Project의 `startStage`에 전달한다. Auto Play가 `None`이 아니고 Project가 선택적 `setAutoPlay(value)`를 구현하면 Stage 시작 전에 `good`, `bad`, `miss` 중 선택값을 전달한다. 입력 상태는 기본 true이고 `Set Input Enabled` 도달 시 바뀌며, 활성 상태의 Space를 현재 beat와 함께 Project `keypressed`로 전달한다. `End` 도달 시 해당 beat에서 끝나고, End가 없고 Music이 있으면 Music duration에서 자동 종료한다. Sample은 검은 Stage 화면에서 Sprite 기반 Spawn Actors와 Cue & Response를 실행하고 Core TapJudgment로 GOOD/BAD/MISS/EMPTY_INPUT을 판정한다. Guide Turn과 Player Turn은 Core BeatTween을 조합해 반대편 액터를 0.5박 동안 화면 밖으로 이동시키며 오른쪽 액터는 좌우 반전한다. 일반 Pattern 실행과 Long Note 판정은 후속 작업이다.

## 6. 독립 실행 Stage 선택

Launcher의 `2`로 Rhythm Dotgeo를 열면 `projects/rhythm_dotgeo/stages/*.json`의 검증된 Stage 이름 목록을 표시한다. 목록 항목은 `Core.UI.Button`의 클릭 판정을 사용하며 클릭 시 최신 Stage JSON을 다시 읽어 `startStage(stage, 0)`로 시작한다. Stage의 BPM, Music, Volume과 Beat 0 Offset은 Core `PlaybackTransport`에 적용되어 독립 실행 rate `1.0`으로 재생된다. Stage 목록·JSON 로딩은 Launcher가 주입한 기존 StageStore를 사용하므로 Project는 Editor 내부 모듈이나 JSON 라이브러리를 직접 불러오지 않는다. 현재 이 선택 화면은 Rhythm Dotgeo 전용이며 Sample은 기존 직접 실행 흐름을 유지한다.

## 7. 게임 연출

Core는 `JudgmentResult`만 전달한다. Project는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT`에 대응하는 화면, 사운드와 UX를 구현한다.

## 8. 독립 배포

배포 시에는 선택 Project의 코드·리소스·Stage와 호환 Core만 포함한다. Editor와 다른 Project는 포함하지 않는다. 패키징 도구는 로드맵의 후속 단계에서 구현한다.
