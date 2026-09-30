-- Stage Event를 beat 순서대로 소비하고 입력 활성 상태와 End를 관리한다.
-- 반환하는 occurrence는 { event, catchUp }이며 Project Event의 실제 동작은 Category Host가 수행한다.

local StageRuntime = {}
StageRuntime.__index = StageRuntime

local function isNonNegativeFinite(value)
    return type(value) == "number"
        and value == value
        and value >= 0
        and value < math.huge
end

-- 같은 beat에서는 원래 events 배열 순서를 유지한다. track 번호는 실행 순서에 영향을 주지 않는다.
local function sortedEvents(stage)
    local events = {}
    for index, event in ipairs(stage.events or {}) do
        table.insert(events, {
            event = event,
            index = index,
        })
    end
    table.sort(events, function(left, right)
        if left.event.startBeat == right.event.startBeat then
            return left.index < right.index
        end
        return left.event.startBeat < right.event.startBeat
    end)
    return events
end

function StageRuntime.new()
    return setmetatable({
        events = {},
        nextEventIndex = 1,
        currentBeat = 0,
        inputEnabled = true,
        endBeat = nil,
        ended = false,
        started = false,
    }, StageRuntime)
end

function StageRuntime:processUntil(targetBeat, catchUp)
    local occurrences = {}
    while self.nextEventIndex <= #self.events do
        local event = self.events[self.nextEventIndex].event
        if event.startBeat > targetBeat then break end

        if event.type == "setInputEnabled" then
            self.inputEnabled = event.enabled
        end
        table.insert(occurrences, {
            event = event,
            catchUp = catchUp,
        })
        self.nextEventIndex = self.nextEventIndex + 1
    end
    return occurrences
end

-- 시작 beat 이하의 Event를 catchUp=true로 소비해 상태를 복원한다. 시작 beat와 같은 Event도 포함된다.
function StageRuntime:start(stage, startBeat)
    startBeat = startBeat or 0
    if type(stage) ~= "table" or type(stage.events) ~= "table" then
        return nil, "StageRuntime requires a Stage with events."
    end
    if not isNonNegativeFinite(startBeat) then
        return nil, "StageRuntime start beat must be a non-negative finite number."
    end

    self.events = sortedEvents(stage)
    self.nextEventIndex = 1
    self.currentBeat = 0
    self.inputEnabled = true
    self.endBeat = nil
    self.ended = false
    self.started = true

    for _, entry in ipairs(self.events) do
        local event = entry.event
        if event.type == "end"
            and (self.endBeat == nil or event.startBeat < self.endBeat) then
            self.endBeat = event.startBeat
        end
    end

    local effectiveBeat = startBeat
    if self.endBeat ~= nil then effectiveBeat = math.min(effectiveBeat, self.endBeat) end
    local occurrences = self:processUntil(effectiveBeat, true)
    self.currentBeat = effectiveBeat
    self.ended = self.endBeat ~= nil and startBeat >= self.endBeat
    return occurrences, nil
end

-- 앞으로만 진행하는 커서다. 중간 beat로 되돌릴 때는 update가 아니라 새 start로 상태를 다시 만들어야 한다.
function StageRuntime:update(beat)
    if not self.started then return nil, "StageRuntime has not started." end
    if not isNonNegativeFinite(beat) then
        return nil, "StageRuntime beat must be a non-negative finite number."
    end
    if beat < self.currentBeat then
        return nil, "StageRuntime cannot move backwards."
    end
    if self.ended then return {}, nil end

    local effectiveBeat = beat
    if self.endBeat ~= nil then effectiveBeat = math.min(effectiveBeat, self.endBeat) end
    local occurrences = self:processUntil(effectiveBeat, false)
    self.currentBeat = effectiveBeat
    self.ended = self.endBeat ~= nil and beat >= self.endBeat
    return occurrences, nil
end

function StageRuntime:getCurrentBeat()
    return self.currentBeat
end

function StageRuntime:isInputEnabled()
    return self.inputEnabled
end

function StageRuntime:hasEndEvent()
    return self.endBeat ~= nil
end

function StageRuntime:isEnded()
    return self.ended
end

function StageRuntime:getEndBeat()
    return self.endBeat
end

return StageRuntime
