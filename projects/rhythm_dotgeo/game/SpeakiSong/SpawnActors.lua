local SpawnActors = {}

function SpawnActors.apply(runtime)
    runtime.background:spawn()
    runtime.guideActor:spawn()
    runtime.playerActor:spawn()
end

return SpawnActors
