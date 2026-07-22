local EditorApp = require("editor.EditorApp")

local Editor = {}

function Editor.createApp(options)
    return EditorApp.new(options)
end

return Editor
