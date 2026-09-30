-- Category 배경과 두 스피키 Actor의 등장 상태를 설정하는 Event handler.

local SpawnActors = {}

function SpawnActors.apply(runtime)
    runtime.background:spawn()
    runtime.guideActor:spawn()
    runtime.playerActor:spawn()
    runtime.sounds:resetTapIndex("guide")
    runtime.sounds:resetTapIndex("player")
end

return SpawnActors
