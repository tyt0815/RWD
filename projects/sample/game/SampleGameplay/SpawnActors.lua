-- Spawn Event를 두 Actor의 등장 상태 변경으로 연결하는 얇은 handler.

local SpawnActors = {}

-- Event는 생성 방법을 직접 알지 않고 Category Runtime에 의도를 전달한다.
function SpawnActors.apply(runtime)
    runtime:spawnActors()
end

return SpawnActors
