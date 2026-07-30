# Core Stage 소유권과 Project Event 이름 공간 정리 설계

## 1. 목표

RWD의 Stage 형식·검증·저장 절차와 Project manifest 계약을 Core 공개 API의 단일 구현으로 통합한다. Editor와 독립 Project는 같은 Stage 계약을 사용하며 Launcher는 실제 파일 접근과 경로를 조립한다.

이번 구조 개선은 다음 결과를 목표로 한다.

- Stage 형식과 검증 규칙의 단일 권위는 Core다.
- Editor와 독립 Project가 같은 Stage 데이터를 같은 방식으로 해석한다.
- Launcher는 더 이상 `editor.stage.StageStore`를 불러오지 않는다.
- Launcher와 Editor의 중복 Project manifest 검증을 제거한다.
- Project Event ID는 Category별 이름 공간을 사용한다.
- Project는 Core와 자기 코드·리소스만으로 별도 패키징할 수 있는 모듈 경계를 가진다.
- Editor GUI의 화면 구성과 사용자 조작감은 바꾸지 않는다.

## 2. 범위

### 포함

- `Core.StageSchema` 공개 API 추가
- `Core.StageRepository` 공개 API 추가
- `Core.ProjectManifest` 공개 API 추가
- Stage 파일 접근 구현을 Editor 밖의 조립 계층으로 이동
- 하나의 Stage Repository 인스턴스를 Editor와 Project에 주입
- `StageDocument`가 Core Stage 계약을 사용하는 편집 모델로 축소
- Project Event를 `categoryId + eventId`로 식별
- Stage `schemaVersion` 3 전환
- Sample과 Rhythm Dotgeo Stage, 테스트 fixture와 제작 문서의 v3 전환
- 모듈 경계와 문서 운영 규칙을 자동 테스트로 보호

### 제외

- Editor와 Project의 `StageRuntime` 이중 소유 제거
- Launcher의 Project 메뉴 자동 생성
- `EditorApp`과 `EditorSession` 책임 분리
- 실제 `.love` 패키징 명령과 배포 도구
- Editor GUI의 화면, 단축키, Dialog, Timeline 조작 변경
- 기존 Metronome 실패 6건 수정

제외한 구조 문제는 후속 단계에서 각각 별도 설계와 구현 계획으로 다룬다.

## 3. 소유권 원칙

| 관심사 | 소유 모듈 | 소비자 |
|---|---|---|
| Stage 형식·기본값·검증·정규화 | Core | Editor, Launcher, Project |
| Stage JSON codec과 저장 절차 | Core | Launcher가 조립한 Repository |
| Stage Event 실행 | Core | Editor preview, Project |
| Stage 편집·dirty·Undo/Redo | Editor | EditorApp |
| 실제 파일 경로와 네이티브 I/O | Launcher 조립 계층 | Core StageRepository |
| Project manifest 검증 | Core | Launcher, Editor |
| 게임별 Event·Actor·연출 | Project | Category Host |
| 공통 UI 입력 상태와 동작 | Core.UI | Editor, Project |
| UI 색상·배치·렌더링 | Editor 또는 Project | 해당 화면 |

Core는 모든 코드를 흡수하는 범용 계층이 아니다. 둘 이상의 소비자가 동일하게 따라야 하는 스타일 독립적인 규칙만 소유한다. Editor 전용 Timeline 상호작용, Dialog 연결과 렌더링은 Editor에 남고 Project별 Sprite, Sound와 연출은 Project에 남는다.

## 4. Core 공개 컴포넌트

### 4.1 `Core.StageSchema`

Stage의 저장 계약과 기본값을 소유하는 순수 모듈이다. LÖVE 리소스, 파일시스템과 Editor 모듈을 사용하지 않는다.

주요 책임은 다음과 같다.

- schemaVersion, Project/Stage ID, 이름과 BPM 검증
- Mixtape와 Editor 저장 설정의 허용 필드·기본값·범위 검증
- Event 공통 필드와 Event 종류별 필드 검증
- Stage와 중첩 값의 방어적 복제
- 기본값과 같은 선택 필드를 제거하는 희소 저장 정규화
- JSON 객체·배열과 null sentinel의 안전한 왕복 계약

Editor 저장 설정은 Stage 파일 형식의 일부이므로 데이터 계약은 Core가 소유한다. 해당 설정을 화면에서 어떻게 편집하고 사용하는지는 Editor가 소유한다.

StageSchema의 사용자 데이터 오류는 예외가 아니라 오류 값으로 반환한다. 구체적인 내부 helper 수보다 다음 외부 계약을 우선한다.

```lua
local valid, message, code = Core.StageSchema.validate(stage)
local normalized, message, code = Core.StageSchema.normalize(stage)
```

성공 시 `validate`는 `true`, `normalize`는 호출자가 안전하게 소유할 수 있는 새 table을 반환한다.

### 4.2 `Core.StageRepository`

Stage 목록·읽기·저장의 공통 절차를 소유한다. 실제 파일 접근 객체, Project별 경로 계산 함수와 JSON 구현은 생성 시 주입받는다.

```lua
local repository = Core.StageRepository.new({
    fileSystem = fileSystem,
    paths = paths,
    json = json,
})
```

공개 동작은 현재 Editor가 필요로 하는 최소 계약을 유지한다.

- `listStages(projectId)`
- `stageExists(projectId, stageId)`
- `load(projectId, stageId)`
- `save(stage, overwrite)`

Repository는 다음 순서를 소유한다.

1. 안전한 Project/Stage ID 확인
2. 주입된 경로 규칙으로 상대 경로 계산
3. JSON decode 또는 encode
4. `Core.StageSchema` 검증·정규화
5. 주입된 FileSystem을 통한 읽기 또는 원자 저장

Core는 `projects/` 루트, Windows 절대 경로와 LÖVE source 경로를 직접 알지 않는다. 해당 정보는 Launcher가 주입한다.

### 4.3 `Core.ProjectManifest`

Launcher `ProjectLoader`와 Editor `ProjectCatalog`에 복제된 manifest 검증을 대체한다.

검증 범위는 다음과 같다.

- manifest table 여부
- `id`, `title`, `entryModule`
- `coreApiVersion`
- 요청한 디렉터리 ID와 manifest ID 일치
- Category ID의 Project 내 고유성
- Event ID의 Category 내부 고유성
- Event property 계약과 Runtime module 계약에 필요한 등록 데이터

검증 API는 예상 ID와 Core API version을 명시적으로 받는다.

```lua
local valid, message, code = Core.ProjectManifest.validate(project, {
    expectedId = projectId,
    expectedCoreApiVersion = Core.CORE_API_VERSION,
})
```

Launcher와 Editor는 별도 검증 규칙을 추가하지 않는다.

## 5. 조립 계층과 기존 모듈

### Launcher

Launcher는 앱 시작 시 실제 FileSystem, Stage 경로 규칙과 JSON 구현으로 StageRepository를 한 번 조립한다. 같은 Repository 인스턴스를 Editor와 독립 Project에 전달한다.

현재 `editor/stage/NativeFileSystem.lua`의 네이티브 source 읽기와 원자 저장 구현은 Editor 소유가 아니므로 Launcher 조립 계층으로 이동한다. Project는 이 모듈을 직접 require하지 않고 생성 옵션으로 받은 Repository만 사용한다.

`ProjectLoader.createGame`은 `stageStore` 대신 `stageRepository`를 전달한다. 기본값을 만들기 위해 Editor 모듈을 require하지 않는다. 프로덕션 조립은 Launcher가 담당하고 테스트는 fake Repository를 주입한다.

### Editor

Editor 생성 시 Project catalog와 Stage Repository를 필수 의존성으로 받는다. Editor는 Repository의 구현 위치나 실제 경로를 알지 않는다.

`editor/stage/StageDocument.lua`는 다음 책임만 유지한다.

- 편집 중인 Stage snapshot 소유
- dirty 상태
- Event 추가·이동·삭제·property 변경
- Stage 복제와 편집 명령의 원자성

Stage 형식, 기본값과 범위 검증은 `Core.StageSchema`에 위임한다. EditorSession의 Undo/Redo와 재생 조립은 이번 단계에서 변경하지 않는다.

### Project

Project는 Stage JSON을 직접 decode하거나 검증하지 않는다. 독립 실행 Stage 선택 화면은 주입된 Repository로 목록과 검증된 Stage를 읽는다. Editor preview에서는 같은 Repository가 게임 생성 경로에 전달된다.

실제 패키징 도구는 후속 작업이지만, Project 코드가 Editor 모듈과 Launcher 구현을 require하지 않는 경계를 유지해 Core와 Project만 묶을 수 있게 한다.

## 6. Stage v3와 Project Event 이름 공간

Stage v3의 Project Event는 Category와 Event를 함께 저장한다.

```json
{
  "id": "event-001",
  "type": "projectEvent",
  "categoryId": "sampleGameplay",
  "eventId": "spawnActors",
  "startBeat": 0,
  "track": 1,
  "params": {}
}
```

규칙은 다음과 같다.

- Category ID는 Project 전체에서 고유하다.
- Event ID는 같은 Category 안에서만 고유하다.
- 서로 다른 Category는 같은 Event ID를 사용할 수 있다.
- `ProjectEvents.getEvent`는 `project, categoryId, eventId`를 받는다.
- Category Host는 `categoryId -> eventId -> Runtime`으로 occurrence를 전달한다.
- Editor의 내부 Timeline type도 Category와 Event를 모두 포함해 충돌하지 않게 만든다.
- StageSchema는 `categoryId`와 `eventId`의 구조를 검증한다.
- 현재 Project에 실제 정의가 있는지와 params가 유효한지는 Project manifest를 아는 EditorSession 또는 게임 시작 경로가 검증한다.

Stage v2 자동 변환기는 만들지 않는다. 저장소의 Sample과 Rhythm Dotgeo Stage, 테스트 fixture를 v3로 직접 갱신한다. 사용자가 Editor에서 Category와 Event를 선택하는 흐름은 바뀌지 않는다.

## 7. 데이터 흐름

### Stage 열기

```text
Launcher
  -> FileSystem + paths + JSON으로 Core.StageRepository 조립
  -> Editor와 Project에 같은 Repository 주입

EditorSession
  -> repository:load(projectId, stageId)
  -> JSON decode
  -> Core.StageSchema 검증·정규화
  -> StageDocument 생성
  -> 기존 Editor GUI에 표시
```

### Stage 저장

```text
StageDocument snapshot
  -> Core.StageSchema 검증·희소 정규화
  -> JSON encode
  -> 임시 파일 쓰기
  -> 기존 파일 backup
  -> 원자 교체
  -> StageDocument markClean
```

검증 또는 저장이 실패하면 StageDocument와 dirty 상태를 바꾸지 않는다. 기존 원본을 복원하지 못하면 backup 경로를 오류 메시지에 남기는 현재 안전 정책을 유지한다.

### 독립 Project 실행

```text
Launcher -> Project 생성(stageRepository 주입)
Project Stage 선택 -> repository:listStages/load
검증된 Stage -> Core.StageRuntime 또는 후속 공통 재생 계층
```

이번 단계에서는 Editor와 Project의 StageRuntime 인스턴스 이중 소유를 제거하지 않는다. Stage 계약 통합 후 다음 단계에서 단일 실행 권위를 설계한다.

## 8. 오류 계약

사용자 데이터와 파일 I/O 오류는 다음 형태를 사용한다.

```lua
nil, "사용자에게 표시할 메시지", "ERROR_CODE"
```

초기 오류 코드는 다음으로 제한한다.

- `INVALID_STAGE`
- `INVALID_PROJECT`
- `NOT_FOUND`
- `STAGE_EXISTS`
- `DECODE_FAILED`
- `READ_FAILED`
- `WRITE_FAILED`

Core는 Dialog, Toast와 화면 문구 배치를 만들지 않는다. Editor는 기존 오류 Dialog/Toast에 메시지를 연결하고 Project Stage 선택 화면은 기존 오류 표시 방식으로 연결한다.

주입 객체에 필수 메서드가 없는 경우와 같이 프로그래머가 계약을 위반한 상황은 생성 시 `assert` 또는 즉시 오류로 드러낸다. 손상된 JSON이나 유효하지 않은 Stage처럼 사용자가 복구할 수 있는 입력은 예외로 처리하지 않는다.

## 9. UI 불변 조건

이번 구조 변경 뒤에도 다음 사용자 경험을 유지한다.

- New, Open, Save, Save As와 덮어쓰기 확인 흐름
- Project, Stage, Music과 Auto Play 선택 방식
- Timeline Event 배치·선택·drag·clipboard·Undo/Redo
- Properties/Values 편집과 오류 표시
- Play/Pause, 기준 beat, preview와 단축키
- Project별 Stage 선택 화면의 기존 조작

Core.UI는 TextInput, ComboBox, Button과 ScrollArea처럼 스타일 독립적인 동작을 계속 소유한다. 색상·좌표·레이아웃·렌더링과 화면별 연결은 Editor 또는 Project에 남는다. 이번 단계는 새 UI 컴포넌트를 선제적으로 추가하지 않는다.

## 10. 테스트 전략

### Core 단위 테스트

- StageSchema의 유효·무효 Stage와 희소 정규화
- Stage v3 Project Event의 `categoryId + eventId`
- JSON 객체·배열과 null sentinel 왕복
- ProjectManifest의 ID/API version/Category/Event 범위
- 서로 다른 Category의 같은 Event ID 허용
- 같은 Category의 Event ID 중복 거부

### Repository 테스트

- fake FileSystem과 fake JSON을 사용한 목록·존재·읽기
- decode 뒤 StageSchema 검증
- encode 전 StageSchema 검증
- overwrite 거부와 오류 코드
- 임시 파일·backup·교체·rollback 원자 저장
- packaged source 읽기 전용 정책

### 통합·경계 테스트

- Launcher가 하나의 Repository를 Editor와 Project에 주입
- Launcher가 `editor.stage.*`를 require하지 않음
- Editor와 Project가 `require("core")` 공개 진입점만 사용
- Launcher와 Editor가 같은 ProjectManifest 결과를 사용
- Sample과 Rhythm Dotgeo v3 Stage가 Editor와 독립 실행에서 로드됨
- 기존 Editor Workflow/UI 테스트로 사용자 조작 회귀 방지

전체 LÖVE suite에서는 작업 전부터 존재하는 Metronome 6건 외에 새 실패가 없어야 한다. 구조 변경의 관련 focused suite는 모두 통과해야 하며 Python Project 생성기 테스트와 Project JSON 문법 검사도 실행한다. Metronome 구현과 기대값 불일치는 이번 작업에서 수정하지 않는다.

## 11. 문서 운영

`docs/ARCHITECTURE.md`는 목표나 작업 일지가 아니라 현재 코드 구조의 단일 기준 문서로 유지한다. 모듈 소유권 표, 허용 의존 방향과 Core 공개 API를 실제 코드와 함께 갱신한다.

`docs/HANDOFF.md`는 과거 작업을 계속 누적하지 않고 다음만 유지한다.

- 현재 구현 상태
- 현재 알려진 실패와 수동 확인 항목
- 가장 최근 검증 명령과 결과
- 다음 작업

과거 구현 기록은 Git history와 날짜별 spec/plan에 남긴다. `AGENTS.md`에는 짧고 강제 가능한 경계만 유지하고, 상세 설명은 ARCHITECTURE를 가리킨다. 문서 규칙 중 가능한 항목은 의존성 테스트로 자동화한다.

## 12. 구현 순서와 완료 기준

권장 구현 순서는 다음과 같다.

1. 실패하는 Core StageSchema와 ProjectManifest 테스트 작성
2. StageSchema와 ProjectManifest 구현 후 기존 검증 소비자 전환
3. 실패하는 StageRepository와 조립 테스트 작성
4. StageRepository 구현과 NativeFileSystem 소유권 이동
5. Launcher가 Repository 하나를 Editor와 Project에 주입하도록 변경
6. Stage v3와 Category별 Event 이름 공간 전환
7. Sample, Rhythm Dotgeo, 생성기와 fixture 갱신
8. 의존성 경계와 Editor GUI 회귀 검증
9. ARCHITECTURE, STAGE_FORMAT, WORKFLOW, ROADMAP와 HANDOFF 갱신

완료 기준은 다음과 같다.

- Stage 형식·검증·저장 절차가 Core 공개 API 한곳에 있다.
- Launcher와 Editor의 Project manifest 검증 중복이 없다.
- Launcher가 Editor Stage 모듈을 require하지 않는다.
- Editor와 Project가 같은 Repository 인스턴스를 사용한다.
- 서로 다른 Category에서 같은 Event ID를 사용할 수 있다.
- 저장소의 모든 Stage가 schemaVersion 3이며 Category ID를 명시한다.
- Editor GUI 사용감과 기존 작업 흐름이 유지된다.
- 관련 focused test가 모두 통과하고 전체 suite에 새 실패가 없다.
- 현재 코드와 문서의 소유권 설명이 일치한다.

