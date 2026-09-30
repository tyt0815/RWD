-- Player Turn Event를 Runtime의 역할 전환 동작으로 연결한다. Event 파일에는 리소스 로딩을 두지 않는다.

local PlayerTurn = {}

function PlayerTurn.apply(runtime, event)
    runtime:applyTurn(event.eventId, event.startBeat)
end

return PlayerTurn
