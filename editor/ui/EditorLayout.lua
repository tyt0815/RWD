local EditorMenu = require("editor.menu.EditorMenu")

local EditorLayout = {}

local PANEL_LABELS = {
    "Menu",
    "Categories",
    "Events",
    "Properties",
    "Values",
}

local PANEL_WEIGHTS = { 1, 1.5, 1.5, 1.25, 1.25 }
local TOP_HEIGHT_RATIO = 0.46
local TIMELINE_STEP_WIDTH = 32
local HEADER_HEIGHT = 32
local PROPERTY_ROW_HEIGHT = 24

function EditorLayout.getLayout(width, height)
    local topHeight = math.floor(height * TOP_HEIGHT_RATIO)
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
            height = height - topHeight,
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

local function getRowRect(panel, rowIndex)
    return {
        x = panel.x,
        y = panel.y + HEADER_HEIGHT + (rowIndex - 1) * PROPERTY_ROW_HEIGHT,
        width = panel.width,
        height = PROPERTY_ROW_HEIGHT,
    }
end

function EditorLayout.getEventRowRect(layout, rowIndex)
    return getRowRect(layout.panels[3], rowIndex)
end

function EditorLayout.getPropertyValueRect(layout, rowIndex)
    return getRowRect(layout.panels[5], rowIndex)
end

function EditorLayout.getVisibleBeatCount(layout)
    return math.max(1, math.floor(layout.timeline.width / TIMELINE_STEP_WIDTH))
end

local function hitTestRows(getRect, layout, rowCount, x, y)
    for rowIndex = 1, rowCount do
        local rect = getRect(layout, rowIndex)
        if x >= rect.x and x < rect.x + rect.width
            and y >= rect.y and y < rect.y + rect.height then
            return rowIndex
        end
    end
    return nil
end

function EditorLayout.hitTestEvent(layout, eventCount, x, y)
    return hitTestRows(EditorLayout.getEventRowRect, layout, eventCount, x, y)
end

function EditorLayout.hitTestPropertyValue(layout, propertyCount, x, y)
    return hitTestRows(EditorLayout.getPropertyValueRect, layout, propertyCount, x, y)
end

local function drawPanel(panel)
    love.graphics.setColor(0.15, 0.16, 0.17, 1)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.28, 0.29, 0.31, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print(panel.label, panel.x + 12, panel.y + 10)
end

local function drawPanelContent(layout, viewModel)
    if not viewModel.hasStage then
        return
    end

    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print("> Global", layout.panels[2].x + 12, HEADER_HEIGHT + 3)
    for rowIndex, event in ipairs(viewModel.propertyEvents) do
        local rect = EditorLayout.getEventRowRect(layout, rowIndex)
        local prefix = event.id == viewModel.selectedEventId and "> " or "  "
        love.graphics.print(prefix .. event.label, rect.x + 12, rect.y + 3)
    end
    if not viewModel.playing then
        for rowIndex, property in ipairs(viewModel.properties) do
            local rect = EditorLayout.getPropertyValueRect(layout, rowIndex)
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
            love.graphics.print(property.label, layout.panels[4].x + 12, rect.y + 3)

            local valueText
            local editing = viewModel.valueEdit
                and viewModel.valueEdit.groupId == viewModel.selectedEventId
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
                    rect.width - 8,
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
                    rect.width - 8,
                    rect.height - 4
                )
            end
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
            love.graphics.print(valueText, rect.x + 12, rect.y + 3)
        end
    end
end

local function drawTimeline(timeline, viewModel)
    love.graphics.setColor(0.18, 0.19, 0.21, 1)
    love.graphics.rectangle("fill", timeline.x, timeline.y, timeline.width, timeline.height)

    local visibleSteps = math.ceil(timeline.width / TIMELINE_STEP_WIDTH)
    for step = 0, visibleSteps do
        local beat = viewModel.timelineStartBeat + step
        local x = timeline.x + step * TIMELINE_STEP_WIDTH
        love.graphics.setColor(
            step % 2 == 0 and 0.23 or 0.2,
            step % 2 == 0 and 0.24 or 0.21,
            step % 2 == 0 and 0.26 or 0.23,
            1
        )
        love.graphics.rectangle("fill", x, timeline.y + 32, TIMELINE_STEP_WIDTH, timeline.height - 32)
        if beat % 4 == 0 then
            love.graphics.setColor(0.82, 0.83, 0.86, 1)
            love.graphics.print(tostring(beat), x + 4, timeline.y + 8)
        end
    end

    if viewModel.hasStage then
        local playheadX = timeline.x
            + (viewModel.beat - viewModel.timelineStartBeat) * TIMELINE_STEP_WIDTH
        love.graphics.setColor(1, 0.45, 0.2, 1)
        love.graphics.rectangle("fill", playheadX, timeline.y, 2, timeline.height)
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
