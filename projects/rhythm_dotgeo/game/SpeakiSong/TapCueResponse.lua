local TapCueResponse = {}

function TapCueResponse.apply(runtime, event, occurrence)
    local responseBeat = event.startBeat + event.params.responseDelayBeats
    if runtime.currentBeat <= event.startBeat + runtime.tapDurationBeats then
        runtime.guideActor:tap(event.startBeat)
    end
    if runtime.currentBeat <= responseBeat + runtime.badWindowBeats then
        runtime.tapJudgment:addNote(event.id, responseBeat)
        table.insert(runtime.tapCues, {
            id = event.id,
            responseBeat = responseBeat,
            autoPlayed = false,
        })
    end
    local isCurrentCue = math.abs(event.startBeat - runtime.currentBeat) < 0.000001
    if not occurrence.catchUp or isCurrentCue then
        runtime.sounds:play("doNotNerGuide")
    end
end

return TapCueResponse
