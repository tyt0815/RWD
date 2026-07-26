return {
    {
        name = "ProjectEvents는 Project의 Category와 Event 정의를 조회하고 기본 params를 만든다",
        run = function(test)
            local Core = require("core")
            local project = {
                eventCategories = {
                    {
                        id = "gameplay",
                        label = "Gameplay",
                        events = {
                            {
                                id = "cueResponse",
                                label = "Cue & Response",
                                properties = {
                                    {
                                        id = "responseDelayBeats",
                                        label = "Response Delay (Beats)",
                                        kind = "number",
                                        default = 4,
                                        min = 0.25,
                                    },
                                },
                            },
                        },
                    },
                },
            }

            test.assertEqual(Core.ProjectEvents.validate(project), nil)
            local definition = Core.ProjectEvents.getEvent(project, "cueResponse")
            test.assertEqual(definition.label, "Cue & Response")
            local params = Core.ProjectEvents.getDefaultParams(definition)
            test.assertEqual(params.responseDelayBeats, 4)
            test.assertEqual(
                Core.ProjectEvents.validateParams(definition, { responseDelayBeats = 0 }),
                "responseDelayBeats must be at least 0.25."
            )
        end,
    },
}
