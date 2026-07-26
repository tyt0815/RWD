# 게임 제작 워크플로우

## 1. Project 생성

게임별 코드는 `projects/<projectId>/`에 둔다. `project.lua`는 Project ID, 표시 이름, 요구 Core API 버전과 게임 진입 모듈을 선언한다. UI, 사운드, 연출과 리소스는 해당 Project 밖으로 새지 않게 한다.

## 2. Project 오디오 배치

음악 파일은 `projects/<projectId>/assets/audio/` 또는 그 하위 폴더에 둔다. 지원 확장자는 `.ogg`, `.mp3`, `.wav`다. 에디터 Music 모달은 이 폴더를 재귀 검색해 `assets/audio/...` Project 상대 경로로 표시한다. 저작권이 있는 파일은 저장소에 추가하지 않는다.

## 3. Pattern 작성과 에디터 등록

Pattern은 여러 beat에 걸친 신호와 플레이어 반응을 코드로 묶는 재사용 단위다. Core가 판정할 원시 노트 종류는 Tap Note와 Long Note이며, Pattern은 실행 시 이 두 노트의 일정을 생성한다.

Project는 에디터에 Categories와 Events를 제공한다. Categories에는 `Global`, `Game Manager`, 미니게임 단위가 들어갈 수 있고 Events에는 Pattern, 개별 Tap/Long Note와 게임 관리 항목이 들어갈 수 있다. 이 등록 계약과 Event 배치 UI는 아직 구현하지 않았다.

## 4. Stage 생성과 재생 속성 편집

현재 제작 순서는 다음과 같다.

```text
Project audio 배치 → New/Open → Mixtape Properties에서 Music 선택
→ 첫 소리 자동 검출 또는 Beat 0 Offset·Volume·BPM 편집 → Editor Properties에서 디버깅 설정
→ wheel zoom·재생 바 이동·중간 버튼 pan으로 Timeline 탐색 → Save/Save As → Test Play → Pause
```

New는 Project, Stage ID, Name과 BPM으로 `events: []`인 schemaVersion 2 Stage를 만든다. New와 Save As의 텍스트 필드는 Values와 같은 공통 입력 모듈을 사용해 UTF-8 중간 삽입·삭제, 좌우 커서 이동과 커서 깜빡임을 지원한다. New/Open의 Project·Stage와 Music 선택은 공통 ComboBox를 사용하며, 클릭해 선택값 한 줄을 검색 입력으로 전환하고 아래 목록을 검색어로 필터링한 뒤 마우스 또는 위·아래 방향키와 Enter로 선택한다. Open, Save와 Save As는 선택한 Project의 `stages` 폴더 안에서만 동작한다. 수정된 Stage의 Menu에는 `Save*`가 보이고 New, Open, Quit은 Save/Discard/Cancel 확인을 거친다.

`Mixtape Properties`는 다음 순서다.

1. Music: `None` 또는 현재 Project의 오디오 파일 선택
2. Volume: `0.0~1.0`
3. Beat 0 Offset: 음악 시작을 논리 beat 0과 맞추는 seconds 값. Music 선택 시 현재 값이 기본값 `0`이면 첫 소리 위치를 자동 설정하고, 오른쪽 `Auto` 버튼은 현재 값과 관계없이 다시 분석한다.
4. BPM: 0보다 큰 유한 값

`Editor Properties`는 다음 순서다.

1. Scale: Timeline 확대 배율 `0.25~8.0`
2. Playback Rate: Editor preview 속도 `0.25~4.0`
3. Metronome: Editor 디버깅 click 사용 여부
4. Metronome Period: BPM 한 박마다 울리는 클릭을 몇 박 단위로 강박 그룹화할지 지정한다. 값 4는 `강 약 약 약`을 반복한다.

숫자 Value는 셀을 클릭하면 값 끝에 깜빡이는 커서가 바로 표시된다. 공통 입력 모듈에 숫자 필터를 적용하며 첫 입력부터 현재 커서 위치에 이어서 입력한다. 좌우 방향키로 커서를 옮겨 중간 삽입하고 Backspace/Delete로 커서 주변 문자를 삭제할 수 있다. Enter 또는 다른 영역 클릭은 유효한 값을 확정하며 Escape는 취소한다. boolean은 클릭 즉시 바뀐다. 기본값과 같은 선택 속성은 저장 JSON에서 제거된다.

첫 소리 분석은 Project Music을 청크 단위로 읽고 채널 평균 10ms RMS가 `-40dB` 이상인 구간이 20ms 이상 이어지는 첫 위치를 사용한다. 순간 노이즈는 줄이지만 음악적 첫 박자를 찾는 기능은 아니다. 분석 실패나 유효한 소리를 찾지 못하면 Music 선택은 유지하고 Offset은 바꾸지 않은 채 오류 모달을 표시한다.

Timeline 위의 wheel zoom은 커서가 가리키는 beat를 화면의 같은 x에 유지한다. 일시정지 상태에서는 재생 바 상단의 역삼각형 핸들을 좌클릭 드래그해 현재 beat를 옮긴다. Timeline 안을 마우스 중간 버튼으로 드래그하면 보이는 구간을 이동하며 시작 beat는 0 아래로 내려가지 않는다. zoom과 구간 이동은 Play 중에도 사용할 수 있으며 직접 Scale Value를 편집할 때는 현재 Timeline 시작 beat를 바꾸지 않는다. 재생 바 이동과 구간 이동은 Stage 저장 데이터와 dirty 상태를 바꾸지 않는다.

## 5. Test Play

Play는 현재 beat부터 다음 구성 요소를 함께 시작한다.

- Core `PlaybackTransport`: 논리 시간, beat, Music Offset과 pitch
- `TestPlayer`: Project Canvas와 Playback Rate가 적용된 update deltaTime
- 선택한 경우 `MetronomePlayback`: 같은 BPM, 현재 beat와 Playback Rate

Music이 `None`이어도 Transport와 Project preview는 정상 동작한다. 음수 Offset이면 음악 위치가 0이 될 때 시작하고, 양수 Offset이면 해당 위치부터 시작한다. 음악 duration이 끝나도 Timeline beat와 Project preview는 계속 진행한다. Pause는 현재 beat를 보존하고 모든 재생 구성 요소를 정지한 뒤 Properties/Values 편집 화면으로 돌아온다.

decode, Source, preview 시작·update·draw가 실패하면 오류 모달을 표시하고 `EditorSession:pause()`를 통해 Transport, Metronome과 TestPlayer를 함께 정리한다. TestPlayer update 실패는 pause 뒤 이전 beat로 rollback한다.

현재 preview는 Project 화면, 음악, Metronome, Timeline과 재생 속성의 동작을 확인하는 범위다. Stage Event 실행, 판정과 Project 입력은 후속 작업이다.

## 6. 게임 연출

Core는 `JudgmentResult`만 전달한다. Project는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT`에 대응하는 화면, 사운드와 UX를 구현한다.

## 7. 독립 배포

배포 시에는 선택 Project의 코드·리소스·Stage와 호환 Core만 포함한다. Editor와 다른 Project는 포함하지 않는다. 패키징 도구는 로드맵의 후속 단계에서 구현한다.
