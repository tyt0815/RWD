# Project 게임플레이 노드 제작 튜토리얼

이 문서는 Sample Project를 참고해 새 Project에 게임플레이 노드를 등록하고 실행하는 방법을 설명한다. Editor나 다른 Project를 직접 `require`하지 않고 `require("core")` 공개 API만 사용한다.

## 1. 역할 분리

- Core: 프로젝트와 무관한 판정 규칙과 Project Event 등록 형식
- Editor: 등록된 Category/Event 표시, Stage 저장, 배치와 재생
- Project: 노드 이름·프로퍼티, 화면, Sprite, 색, 사운드, 입력 결과 연출

Project 기능을 만들기 전에는 `require("core")`가 이미 제공하는 판정·시간·UI API를 먼저 확인한다. 기존 Core 객체를 Project가 조합하는 방식을 우선하고, 여러 Project에서 동일하게 쓸 스타일 독립 규칙이 없을 때만 Core 공개 API와 테스트를 추가한다. Core를 확장해 새 제작법이 생기면 이 문서도 함께 갱신한다.

현재 Sample은 다음 Category 완결 구조를 실제로 사용한다. `project.lua`와 `SampleGame.lua`는 자동 발견과 Core 위임만 담당하므로 새 Category를 추가할 때 수정하지 않는다.

새 Project의 Category도 `game/` 바로 아래에 둔다.

```text
game/
├─ Game.lua
└─ SampleGameplay/
   ├─ Definition.lua
   ├─ Runtime.lua
   ├─ SpawnActors.lua
   ├─ GuideTurn.lua
   ├─ PlayerTurn.lua
   ├─ CueResponse.lua
   ├─ SampleActor.lua 또는 역할별 Actor 모듈
   ├─ Sprites.lua
   └─ Sounds.lua
```

- `Definition.lua`: Category·Event·Property·geometry의 순수 등록 정보. Editor가 읽으므로 이미지·소리와 Runtime을 로드하지 않는다.
- `Runtime.lua`: Core occurrence, Event handler, Actor와 Category 공용 리소스를 조립한다.
- Event 파일: 해당 Event가 Actor·판정·연출 객체에 무엇을 요청하는지만 표현한다.
- Actor 파일: 자신의 상태·이동·렌더링과 전용 Sprite/SFX를 소유한다.

Actor 수가 아니라 변경 이유로 파일을 나눈다. 동작과 리소스가 같으면 `SampleActor.lua` 하나를 Guide와 Player 인스턴스로 사용한다. 독립적으로 바뀌면 `GuideActor.lua`, `PlayerActor.lua`로 분리한다. `LeftActor.lua`, `RightActor.lua`는 위치 자체가 역할일 때만 사용한다. 여러 Actor가 같은 asset을 실제로 공유하면 Category 범위의 Sprite·Sound 캐시를 주입하고, 전용 asset이면 해당 Actor가 로드하거나 전용 리소스 객체를 받는다.

## 2. Project Event 등록

새 `NewGameSample` Category를 만들려면 `game/NewGameSample/Definition.lua`와 `Runtime.lua`를 만든다. Core가 폴더를 자동 발견하므로 기존 `project.lua`, `Game.lua`와 다른 Category 파일은 수정하지 않는다.

```lua
-- game/NewGameSample/Definition.lua
-- Editor가 읽으므로 Runtime, Actor와 asset을 require하지 않는다.
return {
    id = "newGameSample",
    label = "New Game Sample",
    events = {
        {
            id = "cueResponse",
            label = "Cue & Response",
            color = { 0.92, 0.94, 0.97, 1 },
            properties = {
                {
                    id = "responseDelayBeats",
                    label = "Response Delay (Beats)",
                    kind = "number",
                    default = 4,
                    min = 0.25,
                    max = 64,
                },
            },
            geometry = {
                durationProperty = "responseDelayBeats",
                endpointWidthBeats = 1,
                connector = true,
            },
        },
    },
}
```

같은 폴더의 `Runtime.lua`는 `new(project, category, options)`를 제공하고 `handleEvent(event, occurrence, beat)`에서 해당 폴더의 Event 모듈로 위임한다. Category 추가·수정에 필요한 코드는 이 폴더 안에만 둔다.

현재 프로퍼티는 유한 `number`를 지원한다. `singleton = true`이면 Stage에 같은 Event를 하나만 배치할 수 있다. `geometry.widthBeats`는 고정 폭이다. `geometry.endpointWidthBeats`는 연결형 노드의 시작·끝 블록이 차지하는 beat 폭이며 Sample의 `1`은 각각 한 박을 뜻한다. 이 의미와 값은 Project가 선언하고 Editor가 Timeline 배율에 맞춰 렌더링·충돌 판정한다. `connector = true`이면 연결 영역은 기본 색의 18% alpha로 채우고 90% alpha 외곽선을 그리며, 시작·끝 상자만 충돌에 참여하므로 가운데에 다른 노드를 놓을 수 있다. 다른 노드의 색조를 덜 왜곡하려면 Sample처럼 중립적인 밝은 회색을 기본 색으로 사용하는 것이 좋다.

## 3. 저장 형식

등록한 노드는 Stage에 일반 `projectEvent`로 저장된다.

```json
{
  "id": "event-003",
  "type": "projectEvent",
  "eventId": "cueResponse",
  "startBeat": 4,
  "track": 2,
  "params": {
    "responseDelayBeats": 4
  }
}
```

`eventId`는 Project 등록 ID와 같아야 한다. Project별 값은 `params` 안에 둔다.

## 4. Stage 실행과 Event 파일 분리

생성된 Game과 Core `ProjectCategories` Host가 Stage lifecycle과 occurrence를 자동으로 Category Runtime에 전달한다. 새 Category에서는 Game을 수정하지 않고 `Runtime.lua`만 구현한다.

```lua
-- game/NewGameSample/Runtime.lua
local Core = require("core")
local CueResponse = require("projects.mygame.game.NewGameSample.CueResponse")

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(project, category, options)
    return setmetatable({
        project = project,
        category = category,
        judgment = nil,
    }, Runtime)
end

function Runtime:startStage(stage, startBeat)
    self.judgment = Core.TapJudgment.new({
        goodWindowBeats = 0.1,
        badWindowBeats = 0.25,
    })
end

function Runtime:handleEvent(event, occurrence, beat)
    if event.eventId == "cueResponse" then
        CueResponse.apply(self, event, occurrence, beat)
    end
end

function Runtime:update(deltaTime, beat)
    for _, result in ipairs(self.judgment:update(beat)) do
        self:showResult(result)
    end
end

return Runtime
```

Category와 Event 이름을 PascalCase 경로로 바꿔 `game/<CategoryName>/<EventName>.lua`에 둔다. Event 파일은 Core가 정한 시점을 받아 Project 전용 상태만 바꾼다.

```lua
local CueResponse = {}

function CueResponse.apply(runtime, event, occurrence)
    local targetBeat = event.startBeat + event.params.responseDelayBeats
    runtime.judgment:addNote(event.id, targetBeat)
    if not occurrence.catchUp then
        runtime.sounds:play("cue")
    end
end

return CueResponse
```

`occurrence.catchUp`은 중간 beat에서 시작하면서 과거 Event 상태를 복원하는 호출이다. 이때 Sprite 위치 같은 지속 상태는 적용하되 이미 지난 SFX 같은 일회성 연출은 다시 재생하지 않는다.

## 5. Editor Auto Play

Editor Properties의 Auto Play를 지원하려면 Category Runtime에 선택적 `setAutoPlay(value)`를 구현한다. TestPlayer는 `startStage`보다 먼저 `none`, `good`, `bad`, `miss` 중 하나를 전달한다. Core는 Project별 판정창과 노트 일정을 모르므로, 목표 beat 입력과 MISS 처리 시점은 Project가 기존 판정기를 조합해 구현한다.

```lua
function Runtime:setAutoPlay(value)
    self.autoPlay = value or "none"
end
```

`good`은 목표 beat에 입력하고, `bad`는 GOOD 창 밖이면서 BAD 창 안인 시점에 입력한다. `miss`는 자동 입력 없이 MISS 갱신을 진행하며 수동 입력이 결과를 바꾸지 않게 막는다. `none`만 수동 입력을 허용한다. Sample 구현은 `projects/sample/game/SampleGameplay/Runtime.lua`를 참고한다.

## 6. Space 입력과 판정

Editor는 입력이 활성화된 동안 `keypressed(key, beat)`로 Space와 입력 beat를 전달한다.

```lua
function Runtime:keypressed(key, beat)
    if key == "space" then
        self:showResult(self.judgment:input(beat))
    end
end
```

`Core.TapJudgment`의 현재 기본 샘플 판정은 다음과 같다.

- 목표에서 `±0.1 beat`: `GOOD`
- 목표에서 `±0.25 beat`: `BAD`
- BAD 창이 끝날 때까지 무입력: `MISS`
- 판정 가능한 노트가 없을 때 입력: `EMPTY_INPUT`

일반 상용 리듬게임은 BPM과 무관한 ms 판정창을 자주 사용한다. 이 샘플은 초기 제작 편의를 위해 beat 기반 임시값을 명시적으로 전달한다. 결과 색, 사운드와 점멸은 Core가 아니라 Project에서 구현한다.

### Long Note 누름·뗌 판정

`Core.LongNoteJudgment`는 `addNote(noteId, startBeat, endBeat)`로 길이가 있는 노트를 등록한다. Project는 Space 누름을 `press(beat)`, 뗌을 `release(beat)`로 전달하고 매 frame `update(beat)`의 MISS 결과를 처리한다. 반환값의 `phase`는 `PRESS` 또는 `RELEASE`다. 시작·종료가 모두 GOOD이면 최종 GOOD, 둘 중 하나가 BAD이면 최종 BAD, 판정창을 벗어나거나 입력을 생략하면 MISS다.

```lua
self.longJudgment:addNote(event.id, responseBeat, responseBeat + lengthBeats)
local pressResult = self.longJudgment:press(beat)
local finalResult = self.longJudgment:release(beat)
```

롱 노트를 사용하는 게임은 `keyreleased(key, beat)`도 구현해야 한다. Main, Launcher, Editor TestPlayer와 Category Host가 현재 beat를 이 메서드까지 전달한다. 길이·판정 결과에 따른 Sprite와 SFX는 Project Category가 소유한다.

## 7. Beat 기반 액터 이동

`Core.BeatTween`은 BPM을 직접 알 필요 없이 현재 beat로 값을 선형 보간한다. Sample의 Guide Turn과 Player Turn은 이를 상속하지 않고 좌우 액터마다 하나씩 조합한다.

```lua
self.movement = Core.BeatTween.new(0)

-- Actor 내부에서 0은 생성 위치, 1은 화면 바깥 위치다.
self.movement:moveTo(1, event.startBeat, 0.5)
local progress = self.movement:getValue(currentBeat)
```

0.5박 이동은 BPM이 높을수록 실제 seconds가 짧아진다. 어느 방향으로 움직이는지, 화면 안·밖 좌표, easing과 Sprite 렌더링은 Project 연출 책임이다. Sample 오른쪽 액터는 같은 Sprite를 음수 x scale로 그려 좌우 반전한다.

## 8. 새 노드 체크리스트

1. `game/<CategoryName>/Definition.lua`에 고유 Category/Event ID와 프로퍼티를 등록한다.
2. 같은 폴더에 `Runtime.lua`와 Project 전용 Event handler를 작성한다.
3. Runtime의 handler map에 `eventId`와 같은 폴더의 모듈을 연결한다. 기존 `project.lua`와 `Game.lua`는 수정하지 않는다.
4. `update`에서 판정과 MISS처럼 Event 이후 계속 진행되는 Project 상태를 처리한다.
5. Auto Play를 지원하면 `setAutoPlay`에서 선택값을 받고 Project 판정창에 맞춰 자동 입력한다.
6. `keypressed`에서 필요한 입력만 Core 판정기로 전달한다.
7. 기존 Core API 조합으로 가능한지 확인한 뒤 Project 안에서 화면과 사운드를 구현한다.
8. 공통 규칙을 Core에 추가했다면 공개 API 테스트와 이 튜토리얼을 갱신한다.
9. Event 등록, Stage 왕복, 판정과 연출 상태를 테스트한다.
10. Stage 필드 계약을 바꾸면 `docs/STAGE_FORMAT.md`도 갱신한다.
