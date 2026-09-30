-- Guide Turn Event를 Runtime의 역할 전환 동작으로 연결한다. 이동 세부 구현은 Actor가 담당한다.

local GuideTurn = {}

function GuideTurn.apply(runtime, event)
    runtime:applyTurn(event.eventId, event.startBeat)
end

return GuideTurn
