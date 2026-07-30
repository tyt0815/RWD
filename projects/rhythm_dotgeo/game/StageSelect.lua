local Core = require("core")

local StageSelect = {}
StageSelect.__index = StageSelect

local BUTTON_WIDTH = 480
local BUTTON_HEIGHT = 48
local BUTTON_GAP = 12

local function buttonRect(index, width, height)
    local buttonWidth = math.min(BUTTON_WIDTH, width - 64)
    return {
        x = (width - buttonWidth) / 2,
        y = height * 0.3 + (index - 1) * (BUTTON_HEIGHT + BUTTON_GAP),
        width = buttonWidth,
        height = BUTTON_HEIGHT,
    }
end

function StageSelect.new(stageRepository, projectId)
    return setmetatable({
        stageRepository = stageRepository,
        projectId = projectId,
        button = Core.UI.Button.new(),
        entries = {},
    }, StageSelect)
end

function StageSelect:refresh()
    self.entries = {}
    if not self.stageRepository then
        return nil, "StageRepository is not configured."
    end

    local stageIds, listError = self.stageRepository:listStages(self.projectId)
    if not stageIds then return nil, listError end
    for _, stageId in ipairs(stageIds) do
        local stage, loadError = self.stageRepository:load(self.projectId, stageId)
        if not stage then return nil, loadError end
        table.insert(self.entries, {
            id = stageId,
            label = stage.name,
        })
    end
    return true, nil
end

function StageSelect:getItems(width, height)
    local items = {}
    for index, entry in ipairs(self.entries) do
        table.insert(items, {
            id = entry.id,
            label = entry.label,
            rect = buttonRect(index, width, height),
        })
    end
    return items
end

function StageSelect:hitTest(x, y, mouseButton, width, height)
    for _, item in ipairs(self:getItems(width, height)) do
        if self.button:hitTest(item.rect, x, y, mouseButton) then
            return item.id
        end
    end
    return nil
end

function StageSelect:draw(projectTitle, width, height, errorMessage)
    love.graphics.clear(0.07, 0.08, 0.1, 1)
    love.graphics.setColor(0.92, 0.93, 0.96, 1)
    love.graphics.printf(projectTitle, 0, height * 0.16, width, "center")
    love.graphics.printf("Select Stage", 0, height * 0.22, width, "center")

    local items = self:getItems(width, height)
    for _, item in ipairs(items) do
        love.graphics.setColor(0.16, 0.2, 0.27, 1)
        love.graphics.rectangle("fill", item.rect.x, item.rect.y, item.rect.width, item.rect.height)
        love.graphics.setColor(0.35, 0.7, 0.95, 1)
        love.graphics.rectangle("line", item.rect.x, item.rect.y, item.rect.width, item.rect.height)
        love.graphics.setColor(0.94, 0.95, 0.98, 1)
        love.graphics.printf(
            item.label,
            item.rect.x,
            item.rect.y + (item.rect.height - love.graphics.getFont():getHeight()) / 2,
            item.rect.width,
            "center"
        )
    end

    if #items == 0 and not errorMessage then
        love.graphics.setColor(0.65, 0.67, 0.72, 1)
        love.graphics.printf("No Stages", 0, height * 0.35, width, "center")
    end
    if errorMessage then
        love.graphics.setColor(1, 0.45, 0.45, 1)
        love.graphics.printf(errorMessage, width * 0.2, height * 0.75, width * 0.6, "center")
    end
end

return StageSelect
