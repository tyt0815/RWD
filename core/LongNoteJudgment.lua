local JudgmentResult = {
    GOOD = "GOOD",
    BAD = "BAD",
    MISS = "MISS",
    EMPTY_INPUT = "EMPTY_INPUT",
}

local LongNoteJudgment = {}
LongNoteJudgment.__index = LongNoteJudgment

local function result(note, phase, judgment)
    return {
        noteId = note and note.id or nil,
        result = judgment,
        phase = phase,
        startBeat = note and note.startBeat or nil,
        endBeat = note and note.endBeat or nil,
    }
end

local function classify(delta, goodWindow, badWindow)
    delta = math.abs(delta)
    if delta <= goodWindow then return JudgmentResult.GOOD end
    if delta <= badWindow then return JudgmentResult.BAD end
    return JudgmentResult.MISS
end

function LongNoteJudgment.new(options)
    options = options or {}
    local goodWindow = options.goodWindowBeats or 0.1
    local badWindow = options.badWindowBeats or 0.25
    assert(goodWindow >= 0 and badWindow >= goodWindow,
        "Long Note windows must satisfy 0 <= good <= bad")
    return setmetatable({
        goodWindowBeats = goodWindow,
        badWindowBeats = badWindow,
        notes = {},
        activeNote = nil,
    }, LongNoteJudgment)
end

function LongNoteJudgment:addNote(noteId, startBeat, endBeat)
    assert(type(noteId) == "string" and noteId ~= "", "noteId is required")
    assert(type(startBeat) == "number" and type(endBeat) == "number"
        and endBeat > startBeat, "Long Note endBeat must follow startBeat")
    table.insert(self.notes, { id = noteId, startBeat = startBeat, endBeat = endBeat })
    table.sort(self.notes, function(left, right) return left.startBeat < right.startBeat end)
end

function LongNoteJudgment:press(beat)
    if self.activeNote then return result(nil, "PRESS", JudgmentResult.EMPTY_INPUT) end
    local note = self.notes[1]
    if not note or math.abs(beat - note.startBeat) > self.badWindowBeats then
        return result(nil, "PRESS", JudgmentResult.EMPTY_INPUT)
    end
    table.remove(self.notes, 1)
    note.pressResult = classify(
        beat - note.startBeat,
        self.goodWindowBeats,
        self.badWindowBeats
    )
    self.activeNote = note
    return result(note, "PRESS", note.pressResult)
end

function LongNoteJudgment:release(beat)
    local note = self.activeNote
    if not note then return result(nil, "RELEASE", JudgmentResult.EMPTY_INPUT) end
    self.activeNote = nil
    local releaseResult = classify(
        beat - note.endBeat,
        self.goodWindowBeats,
        self.badWindowBeats
    )
    local finalResult = releaseResult
    if releaseResult ~= JudgmentResult.MISS and note.pressResult == JudgmentResult.BAD then
        finalResult = JudgmentResult.BAD
    end
    return result(note, "RELEASE", finalResult)
end

function LongNoteJudgment:update(beat)
    local results = {}
    while self.notes[1]
        and beat > self.notes[1].startBeat + self.badWindowBeats do
        local note = table.remove(self.notes, 1)
        table.insert(results, result(note, "PRESS", JudgmentResult.MISS))
    end
    if self.activeNote
        and beat > self.activeNote.endBeat + self.badWindowBeats then
        local note = self.activeNote
        self.activeNote = nil
        table.insert(results, result(note, "RELEASE", JudgmentResult.MISS))
    end
    return results
end

return LongNoteJudgment
