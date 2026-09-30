-- beat를 기준으로 두 숫자 사이를 선형 보간한다. Actor의 위치 같은 값만 계산하며 렌더링은 하지 않는다.

local BeatTween = {}
BeatTween.__index = BeatTween

local function isFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function BeatTween.new(initialValue)
    assert(isFinite(initialValue), "initialValue must be finite")
    return setmetatable({
        fromValue = initialValue,
        toValue = initialValue,
        startBeat = 0,
        durationBeats = 0,
    }, BeatTween)
end

function BeatTween:start(fromValue, toValue, startBeat, durationBeats)
    assert(isFinite(fromValue) and isFinite(toValue), "Tween values must be finite")
    assert(isFinite(startBeat), "startBeat must be finite")
    assert(isFinite(durationBeats) and durationBeats > 0,
        "durationBeats must be positive")
    self.fromValue = fromValue
    self.toValue = toValue
    self.startBeat = startBeat
    self.durationBeats = durationBeats
end

function BeatTween:getValue(beat)
    if self.durationBeats <= 0 or beat >= self.startBeat + self.durationBeats then
        return self.toValue
    end
    if beat <= self.startBeat then return self.fromValue end
    local progress = (beat - self.startBeat) / self.durationBeats
    return self.fromValue + (self.toValue - self.fromValue) * progress
end

function BeatTween:moveTo(toValue, startBeat, durationBeats)
    self:start(self:getValue(startBeat), toValue, startBeat, durationBeats)
end

function BeatTween:isActive(beat)
    return beat < self.startBeat + self.durationBeats
        and self.fromValue ~= self.toValue
end

return BeatTween
