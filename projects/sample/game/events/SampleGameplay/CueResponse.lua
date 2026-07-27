local CueResponse = {}

local function isAtCurrentBeat(game, event)
    return math.abs(event.startBeat - game.currentBeat) < 0.000001
end

function CueResponse.apply(game, event, occurrence)
    local responseBeat = event.startBeat + event.params.responseDelayBeats
    local cue = {
        id = event.id,
        cueBeat = event.startBeat,
        responseBeat = responseBeat,
        cuePlayed = occurrence.catchUp and not isAtCurrentBeat(game, event),
        autoPlayed = false,
    }
    table.insert(game.cueEvents, cue)

    if not cue.cuePlayed then
        cue.cuePlayed = true
        game.guideFlashRemaining = game.flashSeconds
        game.sounds:play("cue")
    end
    if responseBeat + game.badWindowBeats >= game.currentBeat then
        game.judgment:addNote(event.id, responseBeat)
    end

    if game.autoPlay == "good" or game.autoPlay == "bad" then
        local offset = game.autoPlay == "bad" and game.autoBadOffsetBeats or 0
        local inputBeat = responseBeat + offset
        if inputBeat <= game.currentBeat
            and responseBeat + game.badWindowBeats >= game.currentBeat then
            cue.autoPlayed = true
            game:showResult(game.judgment:input(inputBeat))
        end
    end
end

return CueResponse
