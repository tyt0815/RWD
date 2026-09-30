-- Tap Cue Event에서 가이드 반응과 플레이어 응답 노트를 만든다.
-- catchUp에서는 아직 유효한 판정/연출만 복원하고 시작 beat의 Cue만 소리 재생을 허용한다.

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
        runtime.sounds:playTap("guide")
    end
end

return TapCueResponse
