-- Editor 공개 진입점. Launcher가 createApp(options)으로 EditorApp을 생성한다.

local EditorApp = require("editor.EditorApp")

local Editor = {}

function Editor.createApp(options)
    return EditorApp.new(options)
end

return Editor
