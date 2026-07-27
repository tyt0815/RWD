local PlayerTurn = {}

function PlayerTurn.apply(game, event)
    game:applyTurn(event.eventId, event.startBeat)
end

return PlayerTurn
