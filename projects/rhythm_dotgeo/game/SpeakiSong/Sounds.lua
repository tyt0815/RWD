local Sounds = {}
Sounds.__index = Sounds

-- 이후 assets/audio/sfx에 파일이 추가되면 이 객체에서 한 번 로드해 Event ID별로 재생한다.
-- Actor와 Event는 Source 경로나 수명을 직접 소유하지 않는다.
function Sounds.new()
    return setmetatable({}, Sounds)
end

function Sounds:play(_)
    -- 현재 스피키송 SFX asset이 없으므로 의도만 받을 수 있게 둔다.
end

return Sounds
