# 에디터 Menu와 Stage 파일 작업 설계

## 1. 목적

에디터의 첫 번째 패널인 `Menu`를 실제로 사용할 수 있는 Stage 작업 메뉴로 완성한다. 메뉴는 다음 일곱 항목만 제공한다.

```text
New
Open
Save
Save As
Play
Pause
Quit
```

`Upload`는 포함하지 않는다. 이번 작업은 새 Stage 생성, 프로젝트 내부 JSON 파일 열기와 저장, 미저장 변경 보호, BPM 편집, 재생 시계와 프로젝트 화면 미리보기를 제공한다. 타임라인 Event 실행과 리듬 판정은 후속 작업으로 남긴다.

## 2. 확정된 범위

### 2.1 포함

- 마우스로 조작하는 일곱 Menu 항목
- Project, Stage ID, Name, BPM을 입력하는 새 Stage 생성
- 프로젝트별 Stage JSON 브라우저
- Save와 Save As
- dirty 상태 및 `Save*` 표시
- New, Open, Quit 전에 `Save / Discard / Cancel` 확인
- `Global → Mixtape Properties`의 BPM 표시와 편집
- 고정 BPM 재생 시계, Play/Pause와 타임라인 플레이헤드
- Play 중 Properties와 Values를 대체하는 프로젝트 TestPlayer Canvas
- Pause 후 Properties와 Values 복귀
- 오류 모달
- Launcher 복귀 방식의 Quit

### 2.2 제외

- 타임라인 Event 배치, 이동과 삭제
- Pattern, Tap Note와 Long Note 실행
- 오디오 동기화와 리듬 판정
- 플레이헤드 직접 이동
- 프로젝트 입력 전달
- `Global`, `Mixtape Properties`, BPM 이외의 Categories/Events/Properties
- 메뉴 단축키
- 원본 프로젝트 폴더 밖의 Stage 파일 열기와 저장
- 독립 패키징

## 3. 구조와 책임

```text
EditorApp
├─ EditorSession
│  ├─ StageDocument
│  ├─ StageStore ── dkjson
│  └─ Core.PlaybackClock
├─ TestPlayer
├─ EditorMenu
├─ EditorDialog
└─ EditorLayout
```

### 3.1 EditorApp

LÖVE 입력, 업데이트와 그리기를 조율한다. 현재 열린 모달을 우선 처리하며 모달이 열려 있을 때 배경 입력을 차단한다. 파일 작업과 재생 규칙을 직접 구현하지 않고 각 책임 객체에 위임한다.

### 3.2 EditorSession

현재 Project, StageDocument, 저장 대상 경로, dirty 여부, PlaybackClock과 TestPlayer 상태를 한 작업 세션으로 묶는다. Menu 명령은 EditorSession의 공개 동작을 통해 상태를 변경한다.

### 3.3 StageDocument

Stage schema version 1의 생성, 값 변경과 구조 검증을 담당한다. 새 Stage는 다음 구조를 사용한다.

```json
{
  "schemaVersion": 1,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "tempoMap": [
    {
      "startBeat": 0,
      "bpm": 120
    }
  ],
  "events": []
}
```

빈 `events` 배열은 타임라인에 Pattern, Tap Note 또는 Long Note 노드가 하나도 배치되지 않았다는 뜻이다. 새 Stage의 타임라인에는 눈금과 플레이헤드만 표시된다.

### 3.4 StageStore

개발 저장소의 Project와 Stage 파일을 탐색하고 JSON을 읽고 쓴다. 모든 경로는 `projects/<projectId>/stages/` 내부로 제한한다. Project 목록은 유효한 `projects/<projectId>/project.lua` 매니페스트를 기준으로 만든다.

에디터가 압축된 `.love`에서 실행되어 원본 Project 폴더에 쓸 수 없으면 저장 기능을 사용하지 않고 오류를 반환한다. Stage는 LÖVE 사용자 저장 폴더에 복사하지 않는다.

### 3.5 JSON 모듈

Lua 5.1부터 5.5까지 지원하고 들여쓰기 인코딩을 제공하는 `dkjson` 단일 파일을 `vendor/`에 포함한다. 원본 라이선스를 함께 보관하고 외부 코드에는 프로젝트 코드 컨벤션을 강제하지 않는다.

- 공식 문서: https://dkolf.de/dkjson-lua/documentation
- 라이선스: dkjson 배포본에 포함된 조건을 그대로 보존

### 3.6 Core.PlaybackClock

고정 BPM, 현재 beat와 재생 여부를 담당한다. `play`, `pause`, `update`, `getBeat`, `setBpm`을 제공한다. Pause는 beat를 보존하고 다음 Play가 같은 위치에서 재개한다. 재생 중 BPM을 바꾸면 현재 beat를 유지한 채 이후 진행 속도만 변경한다.

이번 구현은 Event 실행 없이 beat를 계속 증가시킨다. Stage 길이와 자동 종료 규칙은 정의하지 않는다.

### 3.7 TestPlayer

선택 Project의 게임 인스턴스를 만들고 에디터가 제공한 LÖVE Canvas 안에서 업데이트하고 그린다. Stage Event와 프로젝트 입력은 전달하지 않는다.

Project 앱의 그리기 계약은 `draw(width, height)`로 확장한다. Launcher는 전체 창 크기를, TestPlayer는 Canvas 크기를 전달한다. Project는 전달된 크기를 기준으로 화면을 구성해야 한다.

Pause하면 TestPlayer 업데이트를 중지하고 Canvas를 숨긴다. Properties와 Values가 즉시 다시 표시된다. 다음 Play에서는 보존된 beat부터 PlaybackClock을 재개하되 프로젝트 미리보기 인스턴스는 새로 생성한다. Project 생성 또는 실행 오류는 편집 세션을 종료하지 않는다.

### 3.8 Quit 경계

Editor는 Launcher를 직접 불러오지 않는다. `Editor.createApp`이 받은 `onQuit` 콜백을 EditorApp에 전달하고, Quit 완료 시 콜백을 호출한다. Launcher는 이 콜백으로 에디터를 닫고 공통 메뉴로 돌아간다.

## 4. Menu 상태와 표시

Menu 항목은 기존 첫 번째 패널에 세로로 표시한다. hover 중인 항목은 배경색 또는 글자색으로 구분한다. 사용할 수 없는 항목은 흐린 색으로 표시하고 클릭을 무시한다.

| 항목 | 활성 조건 |
| --- | --- |
| New | 항상 |
| Open | 항상 |
| Save | Stage가 있음 |
| Save As | Stage가 있음 |
| Play | Stage가 있고 재생 중이 아님 |
| Pause | Stage가 있고 재생 중임 |
| Quit | 항상 |

dirty 상태에서는 Menu 표기만 `Save*`로 바꾼다. 명령 이름과 저장 동작은 Save와 같다.

메뉴 단축키는 추가하지 않는다. 모달 입력에 필요한 문자 입력, Backspace, Tab, Enter와 Escape만 지원한다.

## 5. 명령별 동작

### 5.1 New

에디터 시작 시에는 Project와 Stage가 선택되지 않은 상태다. New 모달은 다음 필드를 제공한다.

- Project: 발견된 Project 중 하나 선택
- Stage ID: Project 안에서 고유한 안전한 식별자
- Name: 비어 있지 않은 표시 이름
- BPM: 0보다 큰 유한 숫자

Stage ID는 영문 소문자 또는 숫자로 시작하고 이후 영문 소문자, 숫자, `_`, `-`만 허용한다. 파일 이름은 항상 `<stageId>.json`이다. 같은 Project에 해당 파일이 이미 있으면 새 Stage를 만들지 않고 Open 또는 다른 Stage ID를 사용하라는 오류를 표시한다.

생성된 Stage는 아직 저장되지 않았으므로 dirty 상태다. 선택 Project가 현재 Project가 되고 PlaybackClock은 일시정지된 0 beat로 초기화된다.

### 5.2 Open

Open 모달 상단에서 Project를 선택하면 해당 `stages` 폴더의 `.json` 파일을 정렬해 표시한다. 사용자가 파일을 선택하면 StageStore가 읽고 JSON을 해석한 뒤 StageDocument가 검증한다.

파일의 `projectId`는 선택한 Project와 같아야 한다. 모든 검증이 성공한 뒤에만 현재 Project와 Stage를 교체한다. 성공 시 dirty는 false가 되고 PlaybackClock은 일시정지된 0 beat로 초기화된다.

### 5.3 Save

현재 Stage 전체를 검증한 뒤 `projects/<projectId>/stages/<stageId>.json`에 들여쓰기 JSON으로 저장한다. 같은 폴더의 임시 파일 쓰기가 먼저 성공해야 대상 파일 교체를 시도한다. 저장이 성공한 뒤에만 dirty를 false로 바꾼다.

### 5.4 Save As

현재 Project는 유지하고 새 Stage ID와 Name을 입력받는다. 파일 이름은 새 `<stageId>.json`으로 자동 결정된다. 대상이 이미 있으면 덮어쓰기 확인 모달을 표시한다.

현재 Stage를 복제한 데이터에 새 ID와 Name을 적용해 저장한다. 저장이 성공한 뒤에만 현재 Stage의 ID, Name과 경로를 새 값으로 교체하고 dirty를 false로 바꾼다. 취소 또는 실패 시 기존 Stage 상태를 유지한다.

### 5.5 Play

저장 여부와 관계없이 현재 메모리의 Stage를 사용한다. PlaybackClock이 보존 중인 beat부터 진행하고, TestPlayer가 선택 Project의 게임 인스턴스를 생성해 업데이트와 렌더링을 시작한다.

Play 중에도 Menu, Categories, Events와 타임라인은 유지한다. Properties와 Values 영역은 두 패널의 합친 크기와 위치를 사용하는 TestPlayer Canvas로 교체한다. 타임라인에는 현재 beat 위치의 세로 플레이헤드를 표시한다.

### 5.6 Pause

PlaybackClock을 현재 beat에서 멈춘다. TestPlayer를 중지하고 Canvas를 숨긴 뒤 Properties와 Values를 복원한다. 다음 Play는 같은 beat에서 재개한다.

### 5.7 Quit

dirty가 아니면 즉시 `onQuit`을 호출해 Launcher로 돌아간다. dirty라면 Save, Discard, Cancel 확인 모달을 먼저 처리한다.

- Save: 저장 성공 후 Quit을 계속한다.
- Discard: 저장하지 않고 Quit을 계속한다.
- Cancel: 에디터에 남는다.

## 6. 미저장 변경 처리

dirty 상태에서 New 또는 Open을 누를 때도 Quit과 같은 Save, Discard, Cancel 모달을 사용한다.

- Save가 성공하면 원래 요청한 New 또는 Open 모달로 이어진다.
- Save가 실패하면 원래 요청을 실행하지 않고 오류 모달을 표시한다.
- Discard는 원래 요청을 계속한다.
- Cancel은 현재 Stage와 재생 상태를 유지하고 요청을 취소한다.

New 또는 Open이 최종적으로 성공하면 기존 재생은 중지되고 beat는 0으로 초기화된다. 모달을 취소하거나 Open이 실패하면 기존 Stage를 교체하지 않는다.

## 7. BPM 편집 UI

Stage가 있으면 다음 선택과 행을 표시한다.

```text
Categories        Events                 Properties    Values
> Global          > Mixtape Properties   BPM           120
```

`Mixtape Properties`를 선택하면 Properties와 Values가 동시에 채워진다. BPM Property를 별도로 선택해야 값을 표시하는 구조가 아니다.

Values의 BPM 숫자를 클릭하면 숫자 입력 모달을 연다. 유효한 값으로 확정하면 `tempoMap[1].bpm`과 PlaybackClock BPM을 함께 변경하고 Stage를 dirty로 표시한다. 같은 값을 입력하면 dirty 상태를 새로 만들지 않는다.

## 8. 모달과 입력

모달은 에디터 중앙에 표시하고 배경을 어둡게 처리한다. 모달이 열려 있으면 Menu, 패널과 타임라인의 마우스 입력을 차단한다.

필요한 모달은 다음과 같다.

- New Stage
- Open Stage
- Save As
- Edit BPM
- Unsaved Changes
- Confirm Overwrite
- Error

입력 필드는 마우스로 포커스하며 문자 입력, Backspace와 Tab을 지원한다. Enter는 현재 모달의 기본 동작을, Escape는 취소 가능한 모달의 취소를 실행한다. 오류 모달은 OK로 닫는다.

## 9. 검증 규칙

Stage version 1은 최소한 다음 조건을 만족해야 한다.

- `schemaVersion`은 정수 `1`
- `projectId`, `stageId`, `name`은 유효한 비어 있지 않은 문자열
- `projectId`와 `stageId`는 안전한 식별자 형식
- `tempoMap`은 `startBeat: 0`과 유효한 BPM을 가진 항목 하나
- `events`는 배열
- 각 Event는 문서화된 `pattern`, `tapNote`, `longNote` 구조 중 하나

Pattern 등록 여부와 Event의 실제 실행 가능성은 이번 단계에서 검사하지 않는다.

## 10. 오류 처리

- 경로에 `..`, 절대 경로 또는 경로 구분자를 허용하지 않는다.
- 지원하지 않는 schemaVersion이나 잘못된 필드는 가능한 경우 JSON 경로를 포함해 보고한다.
- Open 실패 시 현재 Stage, dirty와 플레이헤드를 변경하지 않는다.
- Save 실패 시 dirty를 유지한다.
- 덮어쓰기는 명시적 확인 없이는 수행하지 않는다.
- Project 게임 생성, update 또는 draw 실패 시 PlaybackClock과 TestPlayer를 중지하고 Properties와 Values로 복귀한 뒤 오류 모달을 표시한다.
- 어떤 파일 또는 미리보기 오류도 에디터나 Launcher 전체를 중단시키지 않는다.

## 11. 테스트 전략

### 11.1 단위 테스트

- 새 Stage의 schemaVersion, tempoMap과 빈 events
- Stage ID, BPM, schemaVersion과 Event 검증
- BPM 변경과 dirty 전환
- PlaybackClock의 진행, Pause, 재개와 BPM 변경 시 beat 보존
- Menu 활성 조건과 `Save*` 표시
- Project와 Stage 경로 검증 및 경로 탈출 차단
- JSON 저장과 다시 열기 왕복
- Save As ID/Name 변경과 충돌 처리

### 11.2 상태 흐름 테스트

- New/Open/Quit의 Save, Discard, Cancel 각 분기
- Open 실패 시 기존 Stage 보존
- Save 실패 시 dirty 보존
- Play 중 TestPlayer 모드와 Pause 후 Properties/Values 복귀
- 미리보기 오류 후 안전한 편집 상태 복귀
- Quit 콜백을 통한 Launcher 복귀

### 11.3 실행 검증

- `love . --test` 전체 테스트
- 저장된 모든 Stage JSON의 PowerShell `ConvertFrom-Json` 검사
- 마우스 기반 GUI 하네스로 New → Save → Open → Play → Pause → Quit 흐름 확인
- 편집 화면, TestPlayer 화면과 Pause 복귀 화면 캡처 확인
- `love .` 실제 GUI 실행 확인

## 12. 완료 기준

- Menu에 요청한 일곱 항목만 표시되고 마우스로 동작한다.
- 새 Stage를 만들고 프로젝트 폴더에 저장한 뒤 다시 열 수 있다.
- dirty 변경을 잃을 수 있는 모든 동작에 확인 절차가 있다.
- Mixtape Properties 선택만으로 BPM Property와 Value가 함께 보이고 값을 바꿀 수 있다.
- Play/Pause가 beat를 보존하며 타임라인 플레이헤드를 움직인다.
- Play 중 프로젝트 화면이 Properties와 Values를 대체하고 Pause 시 두 패널이 복원된다.
- 파일과 Project 미리보기 오류가 현재 편집 세션을 파괴하지 않는다.
- 기존 모듈 의존 방향과 Lua 명명 규칙을 유지한다.
