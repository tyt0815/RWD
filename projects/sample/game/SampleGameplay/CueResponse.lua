local CueResponse = {}

function CueResponse.apply(runtime, event, occurrence)
    local responseBeat = event.startBeat + event.params.responseDelayBeats
    local cue = {
        id = event.id,
        cueBeat = event.startBeat,
        responseBeat = responseBeat,
        autoPlayed = false,
    }
    table.insert(runtime.cueEvents, cue)

    -- 중간 beat 시작의 catch-up은 지속 상태만 복원하고 지난 cue SFX는 반복하지 않는다.
    local isCurrentCue = math.abs(event.startBeat - runtime.currentBeat) < 0.000001
    if not occurrence.catchUp or isCurrentCue then
        runtime:playCue()
    end
    if responseBeat + runtime.badWindowBeats >= runtime.currentBeat then
        runtime.judgment:addNote(event.id, responseBeat)
    end

    if runtime.autoPlay == "good" or runtime.autoPlay == "bad" then
        local offset = runtime.autoPlay == "bad" and runtime.autoBadOffsetBeats or 0
        local inputBeat = responseBeat + offset
        if inputBeat <= runtime.currentBeat
            and responseBeat + runtime.badWindowBeats >= runtime.currentBeat then
            cue.autoPlayed = true
            runtime:showResult(runtime.judgment:input(inputBeat))
        end
    end
end

return CueResponse
