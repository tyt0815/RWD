local EditorApp = require("editor.EditorApp")

local Editor = {}

function Editor.createApp()
    return EditorApp.new()
end

return Editor
