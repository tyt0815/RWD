local SpawnActors = {}

-- Event는 생성 방법을 직접 알지 않고 Category Runtime에 의도를 전달한다.
function SpawnActors.apply(runtime)
    runtime:spawnActors()
end

return SpawnActors
