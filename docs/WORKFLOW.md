# 게임 제작 워크플로우

## 1. 프로젝트 생성

게임별 코드는 `projects/<projectId>/`에 둔다. `project.lua`는 프로젝트 ID, 표시 이름, 요구 코어 API 버전과 게임 진입 모듈을 선언한다. UI, 사운드, 연출과 리소스는 해당 프로젝트 밖으로 새지 않게 한다.

## 2. Pattern 작성

Pattern은 여러 박자에 걸친 신호와 플레이어 반응을 코드로 묶는 재사용 단위다. 예를 들어 첫 4박자에 효과음을 들려주고 다음 4박자에 네 번 탭하도록 만드는 Pattern을 정의할 수 있다.

Core가 판정하는 원시 노트 종류는 Tap Note와 Long Note뿐이다. Pattern은 실행 시 이 두 노트의 일정을 생성한다.

## 3. 에디터 등록

프로젝트는 에디터에 Categories와 Events를 제공한다. Categories에는 `Global`, `Game Manager`, 미니게임 단위가 들어갈 수 있다. Events에는 Pattern, 개별 Tap/Long Note와 게임 관리 항목이 들어갈 수 있다.

## 4. Stage 편집

제작자는 에디터에서 프로젝트와 Stage를 선택하고 Event를 박자 기반 타임라인에 배치한다. Stage JSON에는 Pattern이 만든 노트를 펼치지 않고 `patternId`, `startBeat`, `params`를 저장한다.

## 5. 테스트 플레이

EditorSession은 Stage와 고정 BPM 재생 시계를 소유하고 TestPlayer의 시작·중지·업데이트를 함께 제어한다. TestPlayer는 재생할 때마다 새 프로젝트 게임을 만들고 에디터 우측 상단 Canvas에서 실행한다. 화면 연결과 Stage Event 실행은 후속 작업 범위다.

## 6. 게임 연출

Core는 `JudgmentResult`만 전달한다. Project는 `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT`에 대응하는 화면, 사운드와 UX를 구현한다.

## 7. 독립 배포

배포 시에는 선택 프로젝트의 코드·리소스·Stage와 호환 Core만 포함한다. Editor와 다른 Project는 포함하지 않는다. 패키징 도구는 로드맵의 후속 단계에서 구현한다.
