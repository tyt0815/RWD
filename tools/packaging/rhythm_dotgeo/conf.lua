-- Rhythm Dotgeo 독립 배포 패키지의 LÖVE 창과 엔진 설정.

function love.conf(config)
    config.identity = "rhythm_dotgeo"
    config.version = "11.5"
    config.console = false
    config.window.title = "Rhythm Dotgeo"
    config.window.width = 1280
    config.window.height = 720
    config.window.minwidth = 640
    config.window.minheight = 360
    config.window.resizable = true
end
