-- LÖVE 실행 환경과 창 설정. 게임 상태가 아니라 엔진 초기 설정만 정의한다.

function love.conf(config)
    config.identity = "rwd"
    config.version = "11.5"
    config.console = true
    config.window.title = "RWD"
    config.window.width = 1920
    config.window.height = 1080
    config.window.minwidth = 1280
    config.window.minheight = 720
    config.window.resizable = true
end
