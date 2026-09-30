-- 게임 전체의 실제 hold 시간 임계값을 ProjectConfig로 읽고 검증한다.
-- 연출 설정과 분리된 longHoldThresholdMs를 Core.PlayerAction 생성에 전달한다.

local Core = require("core")

local GameplayConfig = {}
GameplayConfig.__index = GameplayConfig

local CONFIG_PATH = "projects/rhythm_dotgeo/config/gameplay.json"

local function isPositiveFinite(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

function GameplayConfig.new(loader)
    return setmetatable({
        loader = loader or Core.ProjectConfig.new(),
    }, GameplayConfig)
end

function GameplayConfig:load()
    local data, loadError = self.loader:load(CONFIG_PATH)
    if not data then return nil, loadError end
    if not isPositiveFinite(data.longHoldThresholdMs) then
        return nil, "Rhythm Dotgeo gameplay config longHoldThresholdMs must be a positive number."
    end
    return {
        longHoldThresholdMs = data.longHoldThresholdMs,
    }, nil
end

return GameplayConfig
