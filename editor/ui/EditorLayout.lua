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

local function drawPanel(panel)
    love.graphics.setColor(0.15, 0.16, 0.17, 1)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.28, 0.29, 0.31, 1)
    love.graphics.rectangle("line", panel.x, panel.y, panel.width, panel.height)
    love.graphics.setColor(0.9, 0.91, 0.93, 1)
    love.graphics.print(panel.label, panel.x + 12, panel.y + 10)
end

local function drawTimeline(timeline)
    love.graphics.setColor(0.18, 0.19, 0.21, 1)
    love.graphics.rectangle("fill", timeline.x, timeline.y, timeline.width, timeline.height)

    local stepIndex = 0
    for x = timeline.x, timeline.x + timeline.width, TIMELINE_STEP_WIDTH do
        if stepIndex % 2 == 0 then
            love.graphics.setColor(0.23, 0.24, 0.26, 1)
        else
            love.graphics.setColor(0.2, 0.21, 0.23, 1)
        end

        love.graphics.rectangle("fill", x, timeline.y + 32, TIMELINE_STEP_WIDTH, timeline.height - 32)

        if stepIndex % 4 == 0 then
            love.graphics.setColor(0.82, 0.83, 0.86, 1)
            love.graphics.print(tostring(stepIndex), x + 4, timeline.y + 8)
        end

        stepIndex = stepIndex + 1
    end
end

function EditorLayout.draw(width, height)
    local layout = EditorLayout.getLayout(width, height)

    love.graphics.push("all")
    love.graphics.clear(0.08, 0.08, 0.09, 1)

    for _, panel in ipairs(layout.panels) do
        drawPanel(panel)
    end

    drawTimeline(layout.timeline)
    love.graphics.pop()
end

return EditorLayout
