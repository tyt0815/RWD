local PlayerAction = {}
PlayerAction.__index = PlayerAction

local function isPositiveFinite(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

function PlayerAction.new(options)
    options = options or {}
    local thresholdMs = options.longHoldThresholdMs
    assert(isPositiveFinite(thresholdMs),
        "longHoldThresholdMs must be a positive finite number")
    return setmetatable({
        longHoldThresholdSeconds = thresholdMs / 1000,
        pressBeat = nil,
        heldSeconds = 0,
        longStarted = false,
    }, PlayerAction)
end

function PlayerAction:reset()
    self.pressBeat = nil
    self.heldSeconds = 0
    self.longStarted = false
end

function PlayerAction:press(beat)
    if self.pressBeat ~= nil then return false end
    self.pressBeat = beat
    self.heldSeconds = 0
    self.longStarted = false
    return true
end

function PlayerAction:isPending()
    return self.pressBeat ~= nil and not self.longStarted
end

function PlayerAction:update(deltaSeconds)
    assert(type(deltaSeconds) == "number" and deltaSeconds >= 0,
        "deltaSeconds must be non-negative")
    if self.pressBeat == nil or self.longStarted then return nil end

    self.heldSeconds = self.heldSeconds + deltaSeconds
    if self.heldSeconds < self.longHoldThresholdSeconds then return nil end

    self.longStarted = true
    return {
        type = "LONG_START",
        pressBeat = self.pressBeat,
    }
end

function PlayerAction:release(beat)
    if self.pressBeat == nil then return nil end
    local action = {
        type = self.longStarted and "LONG_RELEASE" or "TAP",
        pressBeat = self.pressBeat,
        releaseBeat = beat,
    }
    self:reset()
    return action
end

return PlayerAction
