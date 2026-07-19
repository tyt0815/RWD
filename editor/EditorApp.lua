local EditorLayout = require("editor.ui.EditorLayout")
local TestPlayer = require("editor.playback.TestPlayer")

local EditorApp = {}
EditorApp.__index = EditorApp

function EditorApp.new()
    return setmetatable({
        testPlayer = TestPlayer.new(),
    }, EditorApp)
end

function EditorApp:update(deltaTime)
end

function EditorApp:draw()
    local width, height = love.graphics.getDimensions()
    EditorLayout.draw(width, height)
end

return EditorApp
