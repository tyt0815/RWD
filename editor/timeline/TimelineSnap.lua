local TimelineSnap = {}

function TimelineSnap.snapBeat(beat, interval)
    return math.max(0, math.floor(beat / interval + 0.5) * interval)
end

function TimelineSnap.snapEventBeat(beat, interval)
    -- 0.3 / 0.1처럼 정수 경계가 미세하게 작아지는 부동소수점 오차를 보정한다.
    return math.max(0, math.floor(beat / interval + 1e-12) * interval)
end

return TimelineSnap
