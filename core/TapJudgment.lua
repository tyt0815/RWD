local TapJudgment = {}
TapJudgment.__index = TapJudgment

local JudgmentResult = {
    GOOD = "GOOD",
    BAD = "BAD",
    MISS = "MISS",
    EMPTY_INPUT = "EMPTY_INPUT",
}

local function isPositiveFinite(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

function TapJudgment.new(options)
    options = options or {}
    local goodWindow = options.goodWindowBeats or 0.1
    local badWindow = options.badWindowBeats or 0.25
    assert(isPositiveFinite(goodWindow), "goodWindowBeats must be positive")
    assert(isPositiveFinite(badWindow) and badWindow >= goodWindow,
        "badWindowBeats must be at least goodWindowBeats")
    return setmetatable({
        goodWindowBeats = goodWindow,
        badWindowBeats = badWindow,
        notes = {},
    }, TapJudgment)
end

function TapJudgment:addNote(noteId, targetBeat)
    assert(type(noteId) == "string" and noteId ~= "", "noteId is required")
    assert(type(targetBeat) == "number" and targetBeat >= 0,
        "targetBeat must be non-negative")
    table.insert(self.notes, {
        id = noteId,
        targetBeat = targetBeat,
        judged = false,
    })
end

function TapJudgment:input(beat)
    local nearest
    local nearestDistance = math.huge
    for _, note in ipairs(self.notes) do
        if not note.judged then
            local distance = math.abs(beat - note.targetBeat)
            if distance <= self.badWindowBeats and distance < nearestDistance then
                nearest = note
                nearestDistance = distance
            end
        end
    end
    if not nearest then
        return { result = JudgmentResult.EMPTY_INPUT, beat = beat }
    end

    nearest.judged = true
    return {
        result = nearestDistance <= self.goodWindowBeats
            and JudgmentResult.GOOD or JudgmentResult.BAD,
        noteId = nearest.id,
        beat = beat,
        targetBeat = nearest.targetBeat,
        errorBeats = beat - nearest.targetBeat,
    }
end

function TapJudgment:update(beat)
    local results = {}
    for _, note in ipairs(self.notes) do
        if not note.judged and beat > note.targetBeat + self.badWindowBeats then
            note.judged = true
            table.insert(results, {
                result = JudgmentResult.MISS,
                noteId = note.id,
                beat = beat,
                targetBeat = note.targetBeat,
            })
        end
    end
    return results
end

return TapJudgment
