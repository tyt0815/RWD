-- 콘텐츠와 viewport 크기에 따른 스크롤 범위, offset, thumb 비율을 계산한다.
-- 색상이나 패널 배치는 알지 못하며 Editor가 계산 결과를 그린다.

local ScrollArea = {}
ScrollArea.__index = ScrollArea

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function ScrollArea.new(options)
    options = options or {}
    return setmetatable({
        contentSize = 0,
        viewportSize = 0,
        offset = 0,
        step = options.step or 24,
    }, ScrollArea)
end

function ScrollArea:getMaximumOffset()
    return math.max(0, self.contentSize - self.viewportSize)
end

function ScrollArea:setDimensions(contentSize, viewportSize)
    self.contentSize = math.max(0, contentSize or 0)
    self.viewportSize = math.max(0, viewportSize or 0)
    self.offset = clamp(self.offset, 0, self:getMaximumOffset())
end

function ScrollArea:getOffset()
    return self.offset
end

function ScrollArea:setOffset(offset)
    local nextOffset = clamp(offset or 0, 0, self:getMaximumOffset())
    local changed = nextOffset ~= self.offset
    self.offset = nextOffset
    return changed
end

function ScrollArea:isScrollable()
    return self:getMaximumOffset() > 0
end

function ScrollArea:scroll(wheelY)
    if not self:isScrollable() or wheelY == 0 then return false end
    return self:setOffset(self.offset - wheelY * self.step)
end

function ScrollArea:getThumb(trackLength, minimumLength)
    if not self:isScrollable() or trackLength <= 0 then return nil end

    local length = math.max(
        minimumLength or 0,
        trackLength * self.viewportSize / self.contentSize
    )
    length = math.min(trackLength, length)
    local travel = trackLength - length
    return {
        position = travel * self.offset / self:getMaximumOffset(),
        length = length,
    }
end

return ScrollArea
