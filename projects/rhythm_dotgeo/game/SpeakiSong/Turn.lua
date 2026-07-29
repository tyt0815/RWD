local Turn = {}

function Turn.apply(runtime, event)
    runtime:applyTurn(event.eventId, event.startBeat)
end

return Turn
