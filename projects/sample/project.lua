return {
    id = "sample",
    title = "Sample Project",
    coreApiVersion = 1,
    entryModule = "projects.sample.game.SampleGame",

    -- 이 선언은 Editor가 Sample 전용 노드를 표시하기 위한 등록 계약이다.
    -- 새 Project에서는 아래 Category/Event를 복사한 뒤 id, property와 연출만 바꿀 수 있다.
    eventCategories = {
        {
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
                -- Turn 노드는 0.5 beat Core 보간을 사용하는 Sample 전용 연출이다.
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
                    -- connector는 가운데 영역을 시각화하되 양 끝만 충돌시킨다.
                    geometry = {
                        durationProperty = "responseDelayBeats",
                        endpointWidthBeats = 1,
                        connector = true,
                        startColor = { 0.2, 0.58, 0.95, 1 },
                        endColor = { 1, 0.7, 0.16, 1 },
                    },
                },
            },
        },
    },
}
