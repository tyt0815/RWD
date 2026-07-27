local GuideTurn = {}

function GuideTurn.apply(game, event)
    game:applyTurn(event.eventId, event.startBeat)
end

return GuideTurn
