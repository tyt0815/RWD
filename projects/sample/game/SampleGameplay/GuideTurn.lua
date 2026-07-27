local GuideTurn = {}

function GuideTurn.apply(runtime, event)
    runtime:applyTurn(event.eventId, event.startBeat)
end

return GuideTurn
