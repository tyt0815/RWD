-- 앱 공용 한글 지원 폰트를 설치하는 초기화 모듈. Launcher와 Editor, Project가 같은 기본 폰트를 사용한다.

local AppFont = {}

local FONT_PATH = "assets/fonts/D2Coding-Ver1.3.3-20260725-all.ttc"
local FONT_SIZE = 14

-- Launcher가 조립하는 Editor와 모든 Project 화면이 같은 한글 지원 기본 폰트를 쓴다.
function AppFont.apply(graphics)
    graphics = graphics or love.graphics
    local font = graphics.newFont(FONT_PATH, FONT_SIZE)
    graphics.setFont(font)
    return font
end

return AppFont
