-- Long Cue Event에서 가이드 hold와 플레이어 시작/해제 목표 beat를 등록한다.
-- 중간 시작에서는 남아 있는 상태를 복원하고 과거 일회성 소리는 재생하지 않는다.

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
