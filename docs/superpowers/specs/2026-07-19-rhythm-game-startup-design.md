# 리듬게임 프로젝트 초기화 설계

## 1. 문서 목적

이 문서는 LÖVE2D 11.5 기반 리듬게임 제작 도구의 초기 저장소 구조와 모듈 경계를 정의한다. 이번 작업의 결과물은 한국어 프로젝트 문서와 실행 가능한 최소 코드 골격이다. 실제 리듬 판정, 타임라인 편집, JSON 저장·불러오기와 테스트 플레이 기능은 후속 설계 및 구현 대상으로 둔다.

## 2. 제품 목표

화면에 노트를 직접 표시하지 않고, 사운드나 시각적 신호에 맞춰 플레이어가 입력하는 리듬게임을 여러 개 제작할 수 있는 기반을 만든다. 기반 시스템은 다음 세 영역으로 구분한다.

- 리듬게임 코어: 시간축, Pattern 전개, Tap/Long Note와 판정 결과를 담당하는 재사용 시스템
- 에디터: 프로젝트가 제공하는 Event를 박자 기반 타임라인에 배치하고 Stage JSON을 편집하는 도구
- 프로젝트: 각 게임의 Pattern 코드, UI/UX, 사운드, 연출, 리소스와 Stage를 소유하는 독립 게임 단위

개발 중에는 세 영역을 하나의 저장소와 공통 실행기로 운영한다. 배포 시에는 선택한 프로젝트의 코드·리소스·Stage와 필요한 코어만 포함한 독립 패키지를 만든다.

## 3. 이번 초기화 범위

이번 작업에 포함한다.

- `AGENTS.md`, `README.md`와 프로젝트 운영 문서 작성
- 코어, 에디터, 프로젝트 모듈의 실제 디렉터리와 공개 진입점 생성
- LÖVE2D 11.5에서 실행되는 공통 실행기 생성
- 실행기에서 에디터 또는 `sample` 프로젝트 화면으로 진입
- 에디터의 기본 패널 및 타임라인 영역 표시
- 모듈 로딩과 의존 방향 검증
- Stage JSON 형식과 제작 워크플로우 문서화

이번 작업에 포함하지 않는다.

- BPM 기반 재생 시계와 오디오 동기화
- Tap Note와 Long Note 판정 구현
- 실제 타임라인 Event 배치, 이동, 삭제
- Stage JSON 저장과 불러오기
- Pattern 등록 및 노트 전개 실행
- 실제 TestPlayer 재생과 입력 전달
- 독립 `.love` 또는 실행 파일 패키징 도구
- 도킹, 패널 크기 조절과 완성형 에디터 UX

## 4. 저장소 전략

초기에는 단일 저장소를 사용한다.

```text
RWD/
├─ main.lua
├─ conf.lua
├─ launcher/
│  ├─ Launcher.lua
│  └─ ProjectLoader.lua
├─ core/
│  └─ init.lua
├─ editor/
│  ├─ init.lua
│  ├─ EditorApp.lua
│  ├─ ui/
│  │  └─ EditorLayout.lua
│  └─ playback/
│     └─ TestPlayer.lua
├─ projects/
│  └─ sample/
│     ├─ project.lua
│     ├─ patterns/
│     ├─ game/
│     │  └─ SampleGame.lua
│     ├─ stages/
│     └─ assets/
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ WORKFLOW.md
│  ├─ STAGE_FORMAT.md
│  ├─ ROADMAP.md
│  └─ HANDOFF.md
├─ AGENTS.md
└─ README.md
```

빈 디렉터리를 유지하기 위한 파일은 필요한 경우에만 둔다. 초기 골격에서 사용하지 않는 추상 계층이나 확장 지점은 만들지 않는다.

## 5. 모듈 책임과 의존 방향

### 5.1 공통 실행기

루트 `main.lua`와 `launcher/`는 개발 중 사용할 조립 계층이다. 실행 모드를 선택하고 에디터 또는 게임 프로젝트에 LÖVE 콜백을 위임한다.

- 에디터 모드와 프로젝트 모드를 선택한다.
- `projects/` 아래의 프로젝트를 찾는다.
- 잘못된 프로젝트를 선택하면 실행기를 유지하고 오류를 표시한다.
- 게임 규칙, 판정 또는 에디터 기능을 직접 구현하지 않는다.

### 5.2 리듬게임 코어

`core/init.lua`는 코어의 유일한 공개 진입점이다. 에디터와 프로젝트는 코어 내부 파일을 직접 `require`하지 않는다.

코어의 장기 책임은 다음과 같다.

- 박자와 실제 시간 사이의 변환
- Pattern을 Tap Note와 Long Note 일정으로 전개
- 입력과 노트의 타이밍 판정
- 놓친 노트 검출
- 판정 결과 전달

코어는 게임별 화면, 사운드와 연출을 소유하지 않는다. 코어가 생성한 판정 결과를 프로젝트가 해석하고 표현한다.

### 5.3 에디터

에디터는 코어 공개 API와 선택한 프로젝트의 매니페스트 계약만 사용한다.

- 프로젝트 선택
- Categories와 Events 표시
- Event 속성 편집
- 박자 기반 타임라인 표시와 편집
- Stage JSON 저장 및 불러오기
- 선택 프로젝트의 테스트 플레이 호스팅

에디터는 프로젝트 내부 구현을 직접 탐색하지 않는다. `project.lua`가 노출한 등록 정보와 콜백만 사용한다.

### 5.4 프로젝트

각 프로젝트는 하나의 독립 게임이다.

- 코드 기반 Pattern
- 게임 화면과 입력 해석
- UI/UX
- 사운드와 시각 효과
- 프로젝트 전용 리소스
- Stage JSON

프로젝트는 코어 공개 API에 의존할 수 있지만 에디터에는 의존하지 않는다. 에디터 없이도 프로젝트 런타임을 실행할 수 있어야 한다.

## 6. 향후 버전형 엔진 패키지 전환

초기에는 모든 프로젝트가 저장소의 동일한 코어 소스를 사용한다. 다음 경계를 유지해 향후 코어와 에디터를 별도 버전 패키지로 분리할 수 있게 한다.

- 코어 접근은 `core/init.lua` 공개 API로 제한한다.
- 코어 공개 API는 정수 `CORE_API_VERSION = 1`을 노출한다.
- 프로젝트 매니페스트는 정수 `coreApiVersion = 1`을 선언한다.
- 실행기는 두 값이 다르면 프로젝트를 실행하지 않고 호환성 오류를 표시한다.
- 프로젝트는 자신의 코드와 리소스 경로를 자체적으로 소유한다.
- 에디터는 매니페스트 계약으로만 프로젝트를 발견한다.
- 배포 결과에는 선택 프로젝트와 필요한 코어만 포함하고 에디터 및 다른 프로젝트는 포함하지 않는다.

초기화 단계에서는 버전 해결기, 패키지 설치기와 빌드 도구를 구현하지 않는다.

## 7. 에디터 UI 구성

에디터의 시각 구성은 사용자 제공 참고 이미지 `.references/editorui1.png`, `.references/editorui2.png`, `.references/editorui3.png`의 배치를 기준으로 한다.

상단 패널 이름은 다음과 같이 확정한다.

```text
Menu | Categories | Events | Properties | Values
```

- Menu: 프로젝트 및 재생 관련 명령을 둘 영역
- Categories: `Global`, `Game Manager`, 개별 미니게임처럼 Event의 소속이나 범위를 선택하는 영역
- Events: 선택한 Category가 제공하는 타임라인 배치 항목을 표시하는 영역
- Properties: 선택한 Category 또는 Event가 제공하는 속성 이름을 표시하는 영역
- Values: 각 속성의 현재 값을 표시하고 편집할 영역

Properties가 없는 Event를 선택하면 Properties와 Values에는 편집 항목을 표시하지 않는다. 각 메뉴의 구체적인 항목과 동작은 기능을 개발할 때 별도로 정한다.

하단에는 전체 너비의 박자 기반 타임라인을 둔다. 편집 상태에서는 우측 상단에 Properties와 Values를 표시한다. 테스트 플레이 상태에서는 그 영역을 `TestPlayer` 화면으로 교체하고, Menu, Categories, Events와 하단 타임라인은 유지한다.

`TestPlayer`는 녹화 영상 재생기가 아니다. 선택 프로젝트의 코드를 현재 Stage 배치대로 실시간 실행하고, 게임 화면을 LÖVE `Canvas`에 렌더링하는 호스트다. 완성 시 에디터 타임라인과 TestPlayer는 하나의 코어 재생 시계를 공유한다.

초기 골격에서는 고정 패널 배치만 렌더링한다. 메뉴 기능, Event 선택, 속성 편집과 실제 TestPlayer 실행은 구현하지 않는다.

## 8. 제작 모델

코어의 실제 판정 대상은 Tap Note와 Long Note 두 종류다. 프로젝트는 여러 노트와 사운드·시각 신호를 조합하는 재사용 가능한 Pattern을 코드로 정의한다.

에디터는 다음 두 배치 방식을 모두 지원하는 방향으로 개발한다.

- 프로젝트 코드가 제공하는 Pattern Event 배치
- 개별 Tap Note 또는 Long Note 직접 배치

주요 제작 방식은 Pattern Event 배치다. 예를 들어 프로젝트가 “4박자 동안 효과음으로 신호를 준 뒤 다음 4박자에 네 번 탭을 요구하는 Pattern”을 코드로 정의하고, 에디터에서는 해당 Pattern의 참조와 시작 박자만 Stage에 배치한다.

## 9. Stage JSON

Stage JSON은 Pattern이 생성한 노트를 펼쳐 저장하지 않는다. Pattern 참조, 시작 박자와 파라미터를 저장하고, 실행 시 선택 프로젝트의 코드가 실제 노트 일정으로 전개한다. Pattern 코드가 변경되면 해당 Pattern을 참조하는 Stage의 실행 결과도 함께 변경된다.

초기 형식은 다음과 같다.

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
  "events": [
    {
      "id": "event-001",
      "type": "pattern",
      "patternId": "fourTapResponse",
      "startBeat": 8,
      "params": {}
    },
    {
      "id": "event-002",
      "type": "tapNote",
      "startBeat": 24
    },
    {
      "id": "event-003",
      "type": "longNote",
      "startBeat": 28,
      "durationBeats": 2
    }
  ]
}
```

### 9.1 공통 필드

- `schemaVersion`: Stage JSON 형식 버전. 초기값은 정수 `1`이다.
- `projectId`: Stage를 해석할 프로젝트 ID다.
- `stageId`: 프로젝트 안에서 고유한 Stage ID다.
- `name`: 에디터와 게임에서 표시할 Stage 이름이다.
- `tempoMap`: 박자별 BPM 정보 배열이다.
- `events`: 타임라인 배치 항목 배열이다.

### 9.2 템포 규칙

버전 1 구현은 `startBeat`가 `0`인 템포 항목 하나만 허용한다. JSON은 배열 구조를 사용해 향후 박자 중간의 BPM 변경을 추가할 때 Stage의 상위 구조를 바꾸지 않도록 한다. 여러 템포 항목의 시간 변환 및 편집은 후속 기능이다.

### 9.3 Event 규칙

- 모든 Event는 Stage 안에서 고유한 `id`, `type`, `startBeat`를 가진다.
- Pattern Event는 프로젝트가 등록한 `patternId`를 가진다.
- Pattern Event의 `params`는 JSON 객체다. 생략하면 로더가 빈 객체로 정규화한다.
- Tap Note는 `type: "tapNote"`를 사용한다.
- Long Note는 `type: "longNote"`와 양수인 `durationBeats`를 사용한다.

입력 키 매핑, 판정 허용 범위와 Long Note의 세부 판정 방식은 이번 초기화에서 정의하지 않는다. 이 항목들은 코어 판정 시스템 구현 전 별도 설계에서 확정한다.

## 10. 데이터 흐름

```text
프로젝트 코드가 Categories와 Events를 등록
→ 에디터가 등록 정보를 목록으로 표시
→ 제작자가 Event를 타임라인에 배치
→ 에디터가 배치 참조를 Stage JSON에 저장
→ 런타임 또는 TestPlayer가 Stage JSON을 로드
→ 프로젝트 코드가 Pattern Event를 Tap/Long Note 일정으로 전개
→ 코어가 재생 시계와 플레이어 입력으로 판정
→ 코어가 JudgmentResult를 프로젝트에 전달
→ 프로젝트가 UI, 사운드와 시각 효과로 결과를 표현
```

에디터 화면의 `Events`와 런타임 알림이 코드에서 충돌하지 않도록 다음 이름을 사용한다.

- 타임라인 배치 데이터: `TimelineEvent`
- 판정 결과 데이터: `JudgmentResult`

## 11. 판정 결과

코어가 프로젝트에 전달할 기본 판정 결과는 네 가지다.

```lua
GOOD
BAD
MISS
EMPTY_INPUT
```

- `GOOD`: 적절한 타이밍에 요구 입력을 수행함
- `BAD`: 요구 입력은 수행했지만 타이밍이 부적절함
- `MISS`: 판정 가능 시간이 끝날 때까지 반응하지 못함
- `EMPTY_INPUT`: 판정 대상이 없는 시점에 입력함

초기 골격에서는 이 판정 로직을 구현하지 않는다.

## 12. 오류 처리 원칙

후속 Stage 로더와 에디터는 다음 원칙을 따른다.

- 지원하지 않는 `schemaVersion`은 파일을 적용하지 않고 명확한 오류를 표시한다.
- 존재하지 않는 `patternId`는 Stage Event ID와 함께 보고하고 테스트 플레이를 시작하지 않는다.
- 잘못된 필드 값은 가능한 경우 해당 JSON 경로를 오류에 포함한다.
- Stage 로드가 실패하면 현재 편집 중인 Stage 상태를 변경하지 않는다.
- 프로젝트 로드가 실패하면 공통 실행기를 유지하고 원인을 표시한다.

초기 골격에서는 실제 Stage 로더가 없으므로 프로젝트 모듈 로딩 실패만 처리한다.

## 13. 검증 전략

초기화 작업은 다음 기준으로 검증한다.

- 모든 Lua 파일의 문법이 유효하다.
- 코어, 에디터와 `sample` 프로젝트의 공개 모듈을 로드할 수 있다.
- LÖVE2D 11.5에서 공통 실행기가 오류 없이 열린다.
- 실행기에서 에디터와 `sample` 프로젝트 화면에 진입할 수 있다.
- 에디터 화면에 확정한 다섯 패널과 하단 타임라인 영역이 표시된다.
- 에디터와 프로젝트가 코어 내부 구현을 직접 불러오지 않는다.
- 프로젝트가 에디터 모듈을 불러오지 않는다.
- 문서에 적힌 실행 방법이 실제 명령과 일치한다.

자동 검사는 외부 테스트 프레임워크를 추가하지 않고 최소한의 모듈 로딩 스모크 테스트로 시작한다. 시각 배치는 LÖVE2D 실행 화면을 직접 확인한다.

## 14. 문서 운영

초기화 작업에서 다음 문서를 만든다.

- `AGENTS.md`: 작업 원칙, 코드 컨벤션, 모듈 경계와 문서 갱신 규칙
- `README.md`: 제품 소개, 실행 방법, 저장소 구조와 기본 제작 흐름
- `docs/ARCHITECTURE.md`: 모듈 책임, 공개 경계와 데이터 흐름
- `docs/WORKFLOW.md`: 프로젝트 생성, Pattern 작성, Stage 편집과 UI/UX 제작 흐름
- `docs/STAGE_FORMAT.md`: Stage JSON 규칙과 예제
- `docs/ROADMAP.md`: 기능 개발 순서와 현재 단계
- `docs/HANDOFF.md`: 현재 상태, 완료 작업, 다음 작업, 검증 결과와 알려진 문제

새 작업 세션은 `AGENTS.md`의 지시에 따라 `README.md`와 `docs/HANDOFF.md`를 우선 확인한다. 작업자는 기능이나 구조를 변경한 뒤 `docs/HANDOFF.md`의 현재 상태와 다음 작업을 갱신한다.

## 15. 코드 컨벤션

Lua 코드에는 다음 이름 규칙을 적용한다.

- 클래스 역할의 테이블과 해당 파일 이름: `PascalCase`
- 변수와 함수: `camelCase`
- 상수: `UPPER_SNAKE_CASE`

예시는 다음과 같다.

```lua
local ProjectLoader = {}

local DEFAULT_PROJECT_ID = "sample"

function ProjectLoader.loadProject(projectId)
    local projectPath = "projects." .. projectId .. ".project"
    return require(projectPath)
end

return ProjectLoader
```

한 번만 쓰는 기능을 위한 추상화는 만들지 않는다. 변경은 요청된 범위에 한정하고, 공개 경계를 추가할 때는 실제 소비자가 있는 경우에만 추가한다.

## 16. 완료 정의

다음 조건을 모두 만족하면 프로젝트 초기화가 완료된 것으로 본다.

1. 문서에 확정된 파일과 최소 코드 골격이 존재한다.
2. `love .`로 공통 실행기를 시작할 수 있다.
3. 에디터와 `sample` 프로젝트 화면을 각각 열 수 있다.
4. 확정된 에디터 패널 구성이 표시된다.
5. Lua 문법 및 모듈 로딩 검사가 통과한다.
6. `docs/HANDOFF.md`에 완료 내용, 검증 결과와 다음 개발 항목이 기록된다.
