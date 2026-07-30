local SpawnActors = {}

function SpawnActors.apply(runtime)
    runtime.background:spawn()
    runtime.guideActor:spawn()
    runtime.playerActor:spawn()
    runtime.sounds:resetTapIndex("guide")
    runtime.sounds:resetTapIndex("player")
end

return SpawnActors
