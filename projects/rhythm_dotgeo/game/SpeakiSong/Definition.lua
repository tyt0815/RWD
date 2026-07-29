-- Editor도 읽는 순수 등록 데이터다. Runtime과 LÖVE 리소스를 여기서 불러오지 않는다.
return {
    id = "speakiSong",
    label = "스피키송",
    events = {
        {
            id = "speakiSong",
            label = "스피키송",
            color = { 0.34, 0.72, 0.9, 1 },
            singleton = true,
            properties = {},
            geometry = { widthBeats = 0.25 },
        },
        {
            id = "heue",
            label = "흐에",
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
                {
                    id = "longNoteLengthBeats",
                    label = "Long Note Length (Beats)",
                    kind = "number",
                    default = 1,
                    min = 0.25,
                    max = 64,
                },
            },
            geometry = {
                durationProperty = "responseDelayBeats",
                endpointWidthBeats = 1,
                connector = true,
                startColor = { 0.32, 0.68, 0.95, 1 },
                endColor = { 1, 0.67, 0.2, 1 },
            },
        },
        {
            id = "doNotNer",
            label = "네르지마세요",
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
                startColor = { 0.32, 0.68, 0.95, 1 },
                endColor = { 1, 0.67, 0.2, 1 },
            },
        },
        {
            id = "guideTurn",
            label = "좌피키",
            color = { 0.32, 0.68, 0.95, 1 },
            properties = {},
            geometry = { widthBeats = 0.5 },
        },
        {
            id = "playerTurn",
            label = "우피키",
            color = { 1, 0.67, 0.2, 1 },
            properties = {},
            geometry = { widthBeats = 0.5 },
        },
    },
}
