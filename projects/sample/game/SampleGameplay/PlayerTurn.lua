local PlayerTurn = {}

function PlayerTurn.apply(runtime, event)
    runtime:applyTurn(event.eventId, event.startBeat)
end

return PlayerTurn
