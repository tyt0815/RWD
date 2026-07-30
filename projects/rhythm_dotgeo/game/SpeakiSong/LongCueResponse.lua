local LongCueResponse = {}

function LongCueResponse.apply(runtime, event, occurrence)
    local lengthBeats = event.params.longNoteLengthBeats
    local responseBeat = event.startBeat + event.params.responseDelayBeats
    local responseEndBeat = responseBeat + lengthBeats
    if runtime.currentBeat <= event.startBeat + lengthBeats then
        runtime.guideActor:startLong(event.startBeat, lengthBeats)
    end
    if runtime.currentBeat <= responseBeat + runtime.badWindowBeats then
        runtime.longJudgment:addNote(event.id, responseBeat, responseEndBeat)
        table.insert(runtime.longCues, {
            id = event.id,
            startBeat = responseBeat,
            endBeat = responseEndBeat,
            autoPressed = false,
            autoReleased = false,
        })
    end
    local isCurrentCue = math.abs(event.startBeat - runtime.currentBeat) < 0.000001
    if (not occurrence.catchUp or isCurrentCue)
        and runtime.currentBeat <= event.startBeat + lengthBeats then
        runtime:startGuideLongSound(event.startBeat, lengthBeats)
    end
end

return LongCueResponse
