local EditorMenu = require("editor.menu.EditorMenu")
local TimelineEventGeometry = require("editor.timeline.TimelineEventGeometry")

local EditorLayout = {}

local PANEL_LABELS = {
    "Menu",
    "Categories",
    "Events",
    "Properties",
    "Values",
}

local PANEL_WEIGHTS = { 1, 1.5, 1.5, 1.25, 1.25 }
local TOP_EXTRA_ROW_COUNT = 8
local TOP_HEIGHT = EditorMenu.getRequiredHeight()
    + EditorMenu.getRowHeight() * TOP_EXTRA_ROW_COUNT
local BASE_BEAT_WIDTH = 32
local HEADER_HEIGHT = 32
local PROPERTY_ROW_HEIGHT = 24
local PROPERTY_ACTION_WIDTH = 48
local PROPERTY_ACTION_GAP = 4
local PLAYHEAD_HANDLE_HALF_WIDTH = 7
local PLAYHEAD_HANDLE_HEIGHT = 12
local SCROLLBAR_WIDTH = 4
local SCROLLBAR_MARGIN = 2
local SCROLLBAR_MIN_LENGTH = 16
local TIMELINE_TRACK_PADDING = 3

function EditorLayout.getLayout(width, height)
    local topHeight = TOP_HEIGHT
    local totalWeight = 0

    for _, weight in ipairs(PANEL_WEIGHTS) do
        totalWeight = totalWeight + weight
    end

    local panels = {}
    local currentX = 0

    for index, label in ipairs(PANEL_LABELS) do
        local panelWidth
        if index == #PANEL_LABELS then
            panelWidth = width - currentX
        else
            panelWidth = math.floor(width * PANEL_WEIGHTS[index] / totalWeight)
        end

        table.insert(panels, {
            label = label,
            x = currentX,
            y = 0,
            width = panelWidth,
            height = topHeight,
        })
        currentX = currentX + panelWidth
    end

    return {
        panels = panels,
        timeline = {
            x = 0,
            y = topHeight,
            width = width,
            height = math.max(0, height - topHeight),
        },
    }
end

function EditorLayout.getPreviewRect(layout)
    local properties = layout.panels[4]
    local values = layout.panels[5]
    return {
        x = properties.x,
        y = properties.y,
        width = properties.width + values.width,
        height = properties.height,
    }
end

function EditorLayout.getRowHeight()
    return PROPERTY_ROW_HEIGHT
end

function EditorLayout.getRowContentHeight(rowCount)
    return rowCount * PROPERTY_ROW_HEIGHT
end

function EditorLayout.getPanelContentRect(panel)
    return {
        x = panel.x,
        y = panel.y + HEADER_HEIGHT,
        width = panel.width,
        height = math.max(0, panel.height - HEADER_HEIGHT),
    }
end

local function getRowRect(panel, rowIndex, scrollOffset)
    return {
        x = panel.x,
        y = panel.y + HEADER_HEIGHT + (rowIndex - 1) * PROPERTY_ROW_HEIGHT
            - (scrollOffset or 0),
        width = panel.width,
        height = PROPERTY_ROW_HEIGHT,
    }
end

function EditorLayout.getCategoryRowRect(layout, rowIndex, scrollOffset)
    return getRowRect(layout.panels[2], rowIndex, scrollOffset)
end

function EditorLayout.getEventRowRect(layout, rowIndex, scrollOffset)
    return getRowRect(layout.panels[3], rowIndex, scrollOffset)
end

function EditorLayout.getPropertyValueRect(layout, rowIndex, scrollOffset)
    return getRowRect(layout.panels[5], rowIndex, scrollOffset)
end

function EditorLayout.getPropertyActionRect(layout, rowIndex, scrollOffset)
    local valueRect = EditorLayout.getPropertyValueRect(layout, rowIndex, scrollOffset)
    return {
        x = valueRect.x + valueRect.width - PROPERTY_ACTION_WIDTH,
        y = valueRect.y + 2,
        width = PROPERTY_ACTION_WIDTH - PROPERTY_ACTION_GAP,
        height = valueRect.height - 4,
    }
end

function EditorLayout.getPixelsPerBeat(scale)
    return BASE_BEAT_WIDTH * scale
end

function EditorLayout.getTimelineHeaderRect(timeline)
    return {
        x = timeline.x,
        y = timeline.y,
        width = timeline.width,
        height = HEADER_HEIGHT,
    }
end

function EditorLayout.hitTestTimelineHeader(timeline, x, y)
    local header = EditorLayout.getTimelineHeaderRect(timeline)
    return x >= header.x and x < header.x + header.width
        and y >= header.y and y < header.y + header.height
end

function EditorLayout.getTimelineBeatOriginX(timeline, scale)
    return timeline.x + EditorLayout.getPixelsPerBeat(scale)
end

function EditorLayout.getTimelineTrackCenterY(timeline, track, trackCount)
    local bodyY = timeline.y + HEADER_HEIGHT
    local bodyHeight = math.max(0, timeline.height - HEADER_HEIGHT)
    return bodyY + (track - 0.5) * bodyHeight / trackCount
end

function EditorLayout.getTimelineTrackAtY(timeline, y, trackCount)
    local bodyY = timeline.y + HEADER_HEIGHT
    local bodyHeight = math.max(0, timeline.height - HEADER_HEIGHT)
    if bodyHeight <= 0 or y < bodyY or y >= bodyY + bodyHeight then return nil end
    return math.min(trackCount, math.floor((y - bodyY) / bodyHeight * trackCount) + 1)
end

function EditorLayout.getTimelineEventRect(timeline, event, viewModel)
    local pixelsPerBeat = EditorLayout.getPixelsPerBeat(viewModel.scale)
    local trackCount = viewModel.trackCount or 10
    local bodyHeight = math.max(0, timeline.height - HEADER_HEIGHT)
    local trackHeight = bodyHeight / trackCount
    local eventX = EditorLayout.getTimelineBeatOriginX(timeline, viewModel.scale)
        + (event.startBeat - viewModel.timelineStartBeat) * pixelsPerBeat
    return {
        x = eventX,
        y = timeline.y + HEADER_HEIGHT + (event.track - 1) * trackHeight
            + TIMELINE_TRACK_PADDING,
        width = pixelsPerBeat
            * TimelineEventGeometry.getWidthBeats(event),
        height = math.max(1, trackHeight - TIMELINE_TRACK_PADDING * 2),
    }
end

function EditorLayout.hitTestTimelineEvent(timeline, events, viewModel, x, y)
    for index = #events, 1, -1 do
        local event = events[index]
        local rect = EditorLayout.getTimelineEventRect(timeline, event, viewModel)
        if x >= rect.x and x < rect.x + rect.width
            and y >= rect.y and y < rect.y + rect.height then
            return event
        end
    end
    return nil
end

function EditorLayout.getVisibleBeatCount(layout, scale)
    local pixelsPerBeat = EditorLayout.getPixelsPerBeat(scale)
    return math.max(1, math.floor(
        math.max(0, layout.timeline.width - pixelsPerBeat) / pixelsPerBeat
    ))
end

function EditorLayout.getPlayheadHandle(timeline, viewModel)
    local pixelsPerBeat = EditorLayout.getPixelsPerBeat(viewModel.scale)
    local anchorBeat = viewModel.anchorBeat or viewModel.beat
    return {
        x = EditorLayout.getTimelineBeatOriginX(timeline, viewModel.scale)
            + (anchorBeat - viewModel.timelineStartBeat) * pixelsPerBeat,
        y = timeline.y,
        halfWidth = PLAYHEAD_HANDLE_HALF_WIDTH,
        height = PLAYHEAD_HANDLE_HEIGHT,
    }
end

function EditorLayout.hitTestPlayheadHandle(timeline, viewModel, x, y)
    local handle = EditorLayout.getPlayheadHandle(timeline, viewModel)
    local localY = y - handle.y
    if localY < 0 or localY > handle.height then return false end
    local halfWidth = handle.halfWidth * (1 - localY / handle.height)
    return math.abs(x - handle.x) <= halfWidth
end

local function hitTestRows(getRect, panel, layout, rowCount, x, y, scrollOffset)
    local content = EditorLayout.getPanelContentRect(panel)
    if x < content.x or x >= content.x + content.width
        or y < content.y or y >= content.y + content.height then
        return nil
    end
    for rowIndex = 1, rowCount do
        local rect = getRect(layout, rowIndex, scrollOffset)
        if x >= rect.x and x < rect.x + rect.width
            and y >= rect.y and y < rect.y + rect.height then
            return rowIndex
        end
    end
    return nil
end

function EditorLayout.hitTestCategory(layout, categoryCount, x, y, scrollOffset)
    return hitTestRows(
        EditorLayout.getCategoryRowRect,
        layout.panels[2],
        layout,
        categoryCount,
        x,
        y,
        scrollOffset
    )
end

function EditorLayout.hitTestEvent(layout, eventCount, x, y, scrollOffset)
    return hitTestRows(
        EditorLayout.getEventRowRect,
        layout.panels[3],
        layout,
        eventCount,
        x,
        y,
        scrollOffset
    )
end

function EditorLayout.hitTestPropertyValue(layout, propertyCount, x, y, scrollOffset)
    return hitTestRows(
        EditorLayout.getPropertyValueRect,
        layout.panels[5],
        layout,
        propertyCount,
        x,
        y,
        scrollOffset
    )
end

function EditorLayout.getScrollbarRect(panel, scrollArea)
    if not scrollArea then return nil end
    local content = EditorLayout.getPanelContentRect(panel)
    local trackLength = math.max(0, content.height - SCROLLBAR_MARGIN * 2)
    local thumb = scrollArea:getThumb(trackLength, SCROLLBAR_MIN_LENGTH)
    if not thumb then return nil end
    return {
        x = panel.x + panel.width - SCROLLBAR_WIDTH - SCROLLBAR_MARGIN,
        y = content.y + SCROLLBAR_MARGIN + thumb.position,
        width = SCROLLBAR_WIDTH,
        height = thumb.length,
    }
end

local function drawPanel(panel)
    love.graphics.setColor(0.15, 0.16, 0.17, 1)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.28, 0.29, 0.31, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print(panel.label, panel.x + 12, panel.y + 10)
end

local function setContentScissor(panel, combinedWidth)
    local content = EditorLayout.getPanelContentRect(panel)
    love.graphics.setScissor(
        content.x,
        content.y,
        combinedWidth or content.width,
        content.height
    )
end

local function drawScrollbar(panel, scrollArea)
    local rect = EditorLayout.getScrollbarRect(panel, scrollArea)
    if not rect then return end
    love.graphics.setColor(0.5, 0.52, 0.56, 0.9)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
end

local function drawPanelContent(layout, viewModel)
    if not viewModel.hasStage then return end

    local scrollAreas = viewModel.scrollAreas or {}
    local categoryOffset = scrollAreas.categories
        and scrollAreas.categories:getOffset() or 0
    local eventOffset = scrollAreas.events
        and scrollAreas.events:getOffset() or 0
    local propertyOffset = scrollAreas.properties
        and scrollAreas.properties:getOffset() or 0

    setContentScissor(layout.panels[2])
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    local categories = viewModel.categories or {
        { id = "global", label = "Global" },
    }
    for rowIndex, category in ipairs(categories) do
        local rect = EditorLayout.getCategoryRowRect(
            layout,
            rowIndex,
            categoryOffset
        )
        local selectedCategoryId = viewModel.selectedCategoryId or "global"
        local prefix = category.id == selectedCategoryId and "> " or "  "
        love.graphics.print(prefix .. category.label, rect.x + 12, rect.y + 3)
    end
    love.graphics.setScissor()

    setContentScissor(layout.panels[3])
    for rowIndex, event in ipairs(viewModel.propertyEvents) do
        local rect = EditorLayout.getEventRowRect(layout, rowIndex, eventOffset)
        local prefix = event.id == viewModel.selectedEventId and "> " or "  "
        love.graphics.print(prefix .. event.label, rect.x + 12, rect.y + 3)
    end
    love.graphics.setScissor()

    if not viewModel.playing then
        setContentScissor(
            layout.panels[4],
            layout.panels[4].width + layout.panels[5].width
        )
        for rowIndex, property in ipairs(viewModel.properties) do
            local rect = EditorLayout.getPropertyValueRect(
                layout,
                rowIndex,
                propertyOffset
            )
            local valueWidth = rect.width
            local actionRect
            if property.actionButton then
                actionRect = EditorLayout.getPropertyActionRect(
                    layout,
                    rowIndex,
                    propertyOffset
                )
                valueWidth = actionRect.x - rect.x - PROPERTY_ACTION_GAP
            end
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
            love.graphics.print(property.label, layout.panels[4].x + 12, rect.y + 3)

            local valueText
            local editing = viewModel.valueEdit
                and viewModel.valueEdit.groupId
                    == (property.groupId or viewModel.selectedEventId)
                and viewModel.valueEdit.propertyId == property.id
            if editing then
                valueText = viewModel.valueEdit.text
            elseif property.kind == "music" and property.value == nil then
                valueText = "None"
            else
                valueText = tostring(property.value)
            end

            if editing then
                love.graphics.setColor(0.1, 0.11, 0.12, 1)
                love.graphics.rectangle(
                    "fill",
                    rect.x + 4,
                    rect.y + 2,
                    valueWidth - 8,
                    rect.height - 4
                )
                if viewModel.valueEdit.invalid then
                    love.graphics.setColor(0.92, 0.3, 0.3, 1)
                else
                    love.graphics.setColor(1, 0.45, 0.2, 1)
                end
                love.graphics.rectangle(
                    "line",
                    rect.x + 4,
                    rect.y + 2,
                    valueWidth - 8,
                    rect.height - 4
                )
            end
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
            love.graphics.print(valueText, rect.x + 12, rect.y + 3)
            if editing and viewModel.valueEdit.cursorVisible ~= false then
                local cursorPosition = viewModel.valueEdit.cursorPosition or #valueText
                local textBeforeCursor = valueText:sub(1, cursorPosition)
                local cursorX = rect.x + 12
                    + love.graphics.getFont():getWidth(textBeforeCursor)
                love.graphics.rectangle("fill", cursorX, rect.y + 4, 1, rect.height - 8)
            end
            if actionRect then
                if property.actionButton.enabled then
                    love.graphics.setColor(0.24, 0.25, 0.29, 1)
                else
                    love.graphics.setColor(0.18, 0.19, 0.21, 1)
                end
                love.graphics.rectangle(
                    "fill",
                    actionRect.x,
                    actionRect.y,
                    actionRect.width,
                    actionRect.height
                )
                if property.actionButton.enabled then
                    love.graphics.setColor(0.92, 0.93, 0.96, 1)
                else
                    love.graphics.setColor(0.48, 0.49, 0.52, 1)
                end
                love.graphics.printf(
                    property.actionButton.label,
                    actionRect.x,
                    actionRect.y + 3,
                    actionRect.width,
                    "center"
                )
            end
        end
        love.graphics.setScissor()
    end

    drawScrollbar(layout.panels[2], scrollAreas.categories)
    drawScrollbar(layout.panels[3], scrollAreas.events)
    if not viewModel.playing then
        drawScrollbar(layout.panels[5], scrollAreas.properties)
    end
end

local function drawTimeline(timeline, viewModel)
    love.graphics.setColor(0.18, 0.19, 0.21, 1)
    love.graphics.rectangle("fill", timeline.x, timeline.y, timeline.width, timeline.height)

    local pixelsPerBeat = EditorLayout.getPixelsPerBeat(viewModel.scale)
    local labelPeriod = viewModel.metronomePeriod or 4
    local timelineRight = timeline.x + timeline.width
    local beatOriginX = EditorLayout.getTimelineBeatOriginX(
        timeline,
        viewModel.scale
    )
    local firstBeat = math.floor(viewModel.timelineStartBeat)
    local lastBeat = math.ceil(
        viewModel.timelineStartBeat
            + math.max(0, timelineRight - beatOriginX) / pixelsPerBeat
    )
    for beat = firstBeat, lastBeat do
        local x = beatOriginX
            + (beat - viewModel.timelineStartBeat) * pixelsPerBeat
        love.graphics.setColor(
            beat % 2 == 0 and 0.23 or 0.2,
            beat % 2 == 0 and 0.24 or 0.21,
            beat % 2 == 0 and 0.26 or 0.23,
            1
        )
        local stripeX = math.max(beatOriginX, x)
        local stripeRight = math.min(timelineRight, x + pixelsPerBeat)
        if stripeRight > stripeX then
            love.graphics.rectangle(
                "fill",
                stripeX,
                timeline.y + 32,
                stripeRight - stripeX,
                timeline.height - 32
            )
        end
        if beat % labelPeriod == 0 and x >= beatOriginX and x < timelineRight then
            local label = tostring(beat)
            local labelWidth = love.graphics.getFont():getWidth(label)
            love.graphics.setColor(0.82, 0.83, 0.86, 1)
            love.graphics.print(label, x - labelWidth / 2, timeline.y + 8)
        end
    end

    if viewModel.hasStage then
        local trackCount = viewModel.trackCount or 10
        local bodyHeight = math.max(0, timeline.height - HEADER_HEIGHT)
        love.graphics.setColor(0.28, 0.29, 0.31, 1)
        for track = 1, trackCount - 1 do
            local y = timeline.y + HEADER_HEIGHT + bodyHeight * track / trackCount
            love.graphics.rectangle("fill", timeline.x, y, timeline.width, 1)
        end

        for _, event in ipairs(viewModel.timelineEvents or {}) do
            local rect = EditorLayout.getTimelineEventRect(timeline, event, viewModel)
            local selectedIds = viewModel.selectedTimelineEventIds or {}
            local draggingIds = viewModel.draggingTimelineEventIds or {}
            local collisionIds = viewModel.collisionTimelineEventIds or {}
            local color
            if collisionIds[event.id] then
                color = { 1, 0.12, 0.12, 1 }
            elseif selectedIds[event.id] then
                color = { 1, 1, 1, draggingIds[event.id] and 0.55 or 1 }
            else
                color = event.color or { 0.8, 0.8, 0.8, 1 }
            end
            love.graphics.setColor(color[1], color[2], color[3], color[4])
            love.graphics.rectangle("fill", rect.x, rect.y, rect.width, rect.height)
            if event.id == viewModel.hoveredTimelineEventId then
                love.graphics.setColor(0.95, 0.95, 0.97, 1)
                love.graphics.print(event.label, rect.x + rect.width + 4, rect.y)
            end
        end

        if viewModel.timelineSelectionBox then
            local selection = viewModel.timelineSelectionBox
            love.graphics.setColor(0.35, 0.8, 1, 0.18)
            love.graphics.rectangle(
                "fill",
                selection.x,
                selection.y,
                selection.width,
                selection.height
            )
            love.graphics.setColor(0.35, 0.8, 1, 0.9)
            love.graphics.rectangle(
                "line",
                selection.x,
                selection.y,
                selection.width,
                selection.height
            )
        end

        local handle = EditorLayout.getPlayheadHandle(timeline, viewModel)
        local playheadX = handle.x
        love.graphics.setColor(1, 0.45, 0.2, 1)
        love.graphics.rectangle("fill", playheadX - 1, timeline.y, 2, timeline.height)
        love.graphics.polygon(
            "fill",
            handle.x - handle.halfWidth,
            handle.y,
            handle.x + handle.halfWidth,
            handle.y,
            handle.x,
            handle.y + handle.height
        )

        if viewModel.playing and viewModel.playbackBeat ~= nil then
            local playbackX = beatOriginX
                + (viewModel.playbackBeat - viewModel.timelineStartBeat)
                    * pixelsPerBeat
            love.graphics.setColor(0.35, 0.8, 1, 1)
            love.graphics.rectangle(
                "fill",
                playbackX - 1,
                timeline.y,
                2,
                timeline.height
            )
        end
    end
end

function EditorLayout.draw(width, height, viewModel, drawPreview)
    local layout = EditorLayout.getLayout(width, height)

    love.graphics.push("all")
    love.graphics.clear(0.08, 0.08, 0.09, 1)

    for index, panel in ipairs(layout.panels) do
        if not (viewModel.playing and (index == 4 or index == 5)) then
            drawPanel(panel)
        end
    end

    EditorMenu.draw(layout.panels[1], viewModel.menuItems, viewModel.hoveredAction)
    drawPanelContent(layout, viewModel)
    if viewModel.playing then
        drawPreview(EditorLayout.getPreviewRect(layout))
    end
    drawTimeline(layout.timeline, viewModel)
    love.graphics.pop()
    return layout
end

return EditorLayout
