local Button = require("core").UI.Button

local EditorMenu = {}

local HEADER_HEIGHT = 32
local ROW_HEIGHT = 24
local ROW_PADDING = 4

local DEFINITIONS = {
    { action = "new", label = "New" },
    { action = "open", label = "Open" },
    { action = "save", label = "Save" },
    { action = "saveAs", label = "Save As" },
    { action = "play", label = "Play" },
    { action = "pause", label = "Pause" },
    { action = "quit", label = "Quit" },
}

function EditorMenu.getItems(session)
    local hasStage = session:hasStage()
    local playing = session:isPlaying()
    local items = {}

    for _, definition in ipairs(DEFINITIONS) do
        local enabled = true
        if definition.action == "save" or definition.action == "saveAs" then
            enabled = hasStage
        elseif definition.action == "play" then
            enabled = hasStage and not playing
        elseif definition.action == "pause" then
            enabled = hasStage and playing
        end

        local label = definition.label
        if definition.action == "save" and session:isDirty() then
            label = "Save*"
        end

        table.insert(items, Button.new({
            action = definition.action,
            label = label,
            enabled = enabled,
        }))
    end

    return items
end

function EditorMenu.getRows(panel, items)
    local rows = {}
    for index, item in ipairs(items) do
        rows[index] = {
            x = panel.x + ROW_PADDING,
            y = panel.y + HEADER_HEIGHT + (index - 1) * ROW_HEIGHT,
            width = panel.width - ROW_PADDING * 2,
            height = ROW_HEIGHT,
            item = item,
        }
    end
    return rows
end

function EditorMenu.hitTest(panel, items, x, y)
    for _, row in ipairs(EditorMenu.getRows(panel, items)) do
        if row.item:hitTest(row, x, y, 1) then
            return row.item
        end
    end
    return nil
end

function EditorMenu.draw(panel, items, hoveredAction)
    for _, row in ipairs(EditorMenu.getRows(panel, items)) do
        if row.item.action == hoveredAction and row.item.enabled then
            love.graphics.setColor(0.25, 0.27, 0.3, 1)
            love.graphics.rectangle("fill", row.x, row.y, row.width, row.height)
        end

        if row.item.enabled then
            love.graphics.setColor(0.9, 0.91, 0.93, 1)
        else
            love.graphics.setColor(0.48, 0.49, 0.52, 1)
        end
        love.graphics.print(row.item.label, row.x + 4, row.y + 3)
    end
end

return EditorMenu
