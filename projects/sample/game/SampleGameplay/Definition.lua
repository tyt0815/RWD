-- 이 파일은 Editor가 Category와 노드를 발견할 때도 읽는다.
-- 따라서 Runtime, Actor, 이미지와 사운드를 require하지 않고 순수 등록 데이터만 반환한다.
return {
    id = "sampleGameplay",
    label = "Sample Gameplay",
    events = {
        {
            id = "spawnActors",
            label = "Spawn Actors",
            color = { 0.18, 0.65, 0.9, 1 },
            singleton = true,
            properties = {},
            geometry = { widthBeats = 0.25 },
        },
        {
            id = "guideTurn",
            label = "Guide Turn",
            color = { 0.25, 0.6, 0.95, 1 },
            properties = {},
            geometry = { widthBeats = 0.5 },
        },
        {
            id = "playerTurn",
            label = "Player Turn",
            color = { 1, 0.58, 0.18, 1 },
            properties = {},
            geometry = { widthBeats = 0.5 },
        },
        {
            id = "cueResponse",
            label = "Cue & Response",
            color = { 0.92, 0.94, 0.97, 1 },
            properties = {
                {
                    id = "responseDelayBeats",
                    label = "Response Delay (Beats)",
                    kind = "number",
                    default = 4,
                    min = 0.25,
                    max = 64,
                },
            },
            geometry = {
                durationProperty = "responseDelayBeats",
                endpointWidthBeats = 1,
                connector = true,
                startColor = { 0.2, 0.58, 0.95, 1 },
                endColor = { 1, 0.7, 0.16, 1 },
            },
        },
    },
}
