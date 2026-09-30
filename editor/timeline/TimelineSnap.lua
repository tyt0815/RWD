-- Timeline snap의 두 규칙: 기준선은 가장 가까운 격자, Event 배치는 앞쪽 격자에 맞춘다.
-- 두 함수를 같은 반올림으로 바꾸면 기존 배치 감각이 달라진다.

local TimelineSnap = {}

function TimelineSnap.snapBeat(beat, interval)
    return math.max(0, math.floor(beat / interval + 0.5) * interval)
end

function TimelineSnap.snapEventBeat(beat, interval)
    -- 0.3 / 0.1처럼 정수 경계가 미세하게 작아지는 부동소수점 오차를 보정한다.
    return math.max(0, math.floor(beat / interval + 1e-12) * interval)
end

return TimelineSnap
