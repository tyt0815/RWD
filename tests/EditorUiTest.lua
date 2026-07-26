local function sessionState(values)
    values = values or {}
    return {
        hasStage = function() return values.hasStage == true end,
        isDirty = function() return values.dirty == true end,
        isPlaying = function() return values.playing == true end,
    }
end

local function copyColor(color)
    return { color[1], color[2], color[3], color[4] }
end

local function withGraphicsRecorder(run)
    local previousLove = _G.love
    local currentColor = { 1, 1, 1, 1 }
    local currentScissor = nil
    local recorder = {
        prints = {},
        rectangles = {},
        polygons = {},
        pushes = {},
        pops = 0,
        clears = {},
        scissors = {},
    }
    local graphics = {}

    function graphics.setColor(red, green, blue, alpha)
        currentColor = { red, green, blue, alpha }
    end

    function graphics.rectangle(mode, x, y, width, height)
        table.insert(recorder.rectangles, {
            mode = mode,
            x = x,
            y = y,
            width = width,
            height = height,
            color = copyColor(currentColor),
        })
    end

    function graphics.polygon(mode, ...)
        table.insert(recorder.polygons, {
            mode = mode,
            points = { ... },
            color = copyColor(currentColor),
        })
    end

    local function recordPrint(kind, text, x, y, limit, align)
        table.insert(recorder.prints, {
            kind = kind,
            text = tostring(text),
            x = x,
            y = y,
            limit = limit,
            align = align,
            color = copyColor(currentColor),
            scissor = currentScissor and {
                x = currentScissor.x,
                y = currentScissor.y,
                width = currentScissor.width,
                height = currentScissor.height,
            } or nil,
        })
    end

    function graphics.print(text, x, y)
        recordPrint("print", text, x, y)
    end

    function graphics.printf(text, x, y, limit, align)
        recordPrint("printf", text, x, y, limit, align)
    end

    function graphics.getFont()
        return {
            getWidth = function(_, text)
                return #text * 8
            end,
        }
    end

    function graphics.push(mode)
        table.insert(recorder.pushes, mode)
    end

    function graphics.pop()
        recorder.pops = recorder.pops + 1
    end

    function graphics.clear(red, green, blue, alpha)
        table.insert(recorder.clears, { red, green, blue, alpha })
    end

    function graphics.setScissor(x, y, width, height)
        currentScissor = x and {
            x = x,
            y = y,
            width = width,
            height = height,
        } or nil
        table.insert(recorder.scissors, currentScissor or {})
    end

    _G.love = { graphics = graphics }
    local succeeded, errorMessage = xpcall(function()
        run(recorder)
    end, debug.traceback)
    _G.love = previousLove

    if not succeeded then
        error(errorMessage, 0)
    end
end

local function countPrints(recorder, text, y)
    local count = 0
    for _, call in ipairs(recorder.prints) do
        if call.text == tostring(text) and (y == nil or call.y == y) then
            count = count + 1
        end
    end
    return count
end

local function countPrintsAtY(recorder, y)
    local count = 0
    for _, call in ipairs(recorder.prints) do
        if call.y == y then
            count = count + 1
        end
    end
    return count
end

local function findPrint(recorder, text)
    for _, call in ipairs(recorder.prints) do
        if call.text == text then
            return call
        end
    end
    return nil
end

local function findRectangle(recorder, expected)
    for _, call in ipairs(recorder.rectangles) do
        if call.mode == expected.mode
            and call.x == expected.x
            and call.y == expected.y
            and call.width == expected.width
            and call.height == expected.height then
            return call
        end
    end
    return nil
end

local function assertColor(test, call, expected)
    test.assertTrue(call ~= nil)
    for index, component in ipairs(expected) do
        test.assertEqual(call.color[index], component)
    end
end

local function assertHeading(test, recorder, label, visible)
    test.assertEqual(countPrints(recorder, label, 10), visible and 1 or 0)
end

local function assertPlayhead(test, recorder, layout, expectedCenterX)
    local playhead = findRectangle(recorder, {
        mode = "fill",
        x = expectedCenterX - 1,
        y = layout.timeline.y,
        width = 2,
        height = layout.timeline.height,
    })
    assertColor(test, playhead, { 1, 0.45, 0.2, 1 })
end

local function assertPlaybackHead(test, recorder, layout, expectedCenterX, visible)
    local playbackHead = findRectangle(recorder, {
        mode = "fill",
        x = expectedCenterX - 1,
        y = layout.timeline.y,
        width = 2,
        height = layout.timeline.height,
    })
    test.assertEqual(playbackHead ~= nil, visible)
    if visible then
        assertColor(test, playbackHead, { 0.35, 0.8, 1, 1 })
    end
end

local function assertTimelineLabels(test, recorder, timeline, labels)
    local labelY = timeline.y + 8
    test.assertEqual(countPrintsAtY(recorder, labelY), #labels)
    for _, label in ipairs(labels) do
        test.assertEqual(countPrints(recorder, label, labelY), 1)
    end
end

return {
    {
        name = "PropertyCatalog는 Events와 속성을 정해진 순서로 복사해 제공한다",
        run = function(test)
            local PropertyCatalog = require("editor.properties.PropertyCatalog")
            local events = PropertyCatalog.getEvents()

            test.assertEqual(#events, 2)
            test.assertEqual(events[1].id, "editorProperties")
            test.assertEqual(events[1].label, "Editor Properties")
            test.assertEqual(events[2].id, "mixtapeProperties")
            test.assertEqual(events[2].label, "Mixtape Properties")

            local editorLabels = {
                "Snap",
                "Scale",
                "Playback Rate",
                "Auto Play",
                "Metronome",
                "Metronome Period",
                "Track",
                "Preview Aspect Width",
                "Preview Aspect Height",
            }
            local mixtapeLabels = {
                "Music",
                "Volume",
                "Beat 0 Offset",
                "Onset Threshold",
                "BPM",
            }
            for index, label in ipairs(editorLabels) do
                test.assertEqual(events[1].properties[index].label, label)
            end
            for index, label in ipairs(mixtapeLabels) do
                test.assertEqual(events[2].properties[index].label, label)
            end
            test.assertEqual(events[1].properties[4].kind, "choice")
            test.assertEqual(events[1].properties[5].kind, "boolean")
            test.assertEqual(events[2].properties[4].groupId, "editorProperties")
            test.assertEqual(events[2].properties[1].kind, "music")
            test.assertEqual(events[2].properties[3].kind, "number")

            events[1].label = "Changed"
            events[1].properties[1].label = "Changed"
            local editorEvent = PropertyCatalog.getEvent("editorProperties")
            test.assertEqual(editorEvent.label, "Editor Properties")
            test.assertEqual(editorEvent.properties[1].label, "Snap")
            test.assertEqual(PropertyCatalog.getEvent("missing"), nil)
        end,
    },
    {
        name = "Menu는 요청한 일곱 항목만 순서대로 제공한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            local labels = { "New", "Open", "Save", "Save As", "Play", "Pause", "Quit" }
            test.assertEqual(#items, #labels)
            for index, label in ipairs(labels) do
                test.assertEqual(items[index].label, label)
            end

            withGraphicsRecorder(function(recorder)
                local panel = { x = 0, y = 0, width = 180, height = 360 }
                EditorMenu.draw(panel, items, "new")

                assertColor(test, findPrint(recorder, "New"), { 0.9, 0.91, 0.93, 1 })
                assertColor(test, findPrint(recorder, "Save"), { 0.48, 0.49, 0.52, 1 })
                local hover = findRectangle(recorder, {
                    mode = "fill",
                    x = 4,
                    y = 32,
                    width = 172,
                    height = 24,
                })
                assertColor(test, hover, { 0.25, 0.27, 0.3, 1 })
            end)
        end,
    },
    {
        name = "Stage가 없으면 저장과 재생 항목이 비활성화된다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local items = EditorMenu.getItems(sessionState())
            test.assertEqual(items[3].enabled, false)
            test.assertEqual(items[4].enabled, false)
            test.assertEqual(items[5].enabled, false)
            test.assertEqual(items[6].enabled, false)

            withGraphicsRecorder(function(recorder)
                local panel = { x = 0, y = 0, width = 180, height = 360 }
                EditorMenu.draw(panel, items, "save")
                test.assertEqual(#recorder.rectangles, 0)
            end)
        end,
    },
    {
        name = "dirty Stage는 Save 별표를 표시한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local EditorLayout = require("editor.ui.EditorLayout")
            local items = EditorMenu.getItems(sessionState({ hasStage = true, dirty = true }))
            test.assertEqual(items[3].label, "Save*")

            withGraphicsRecorder(function(recorder)
                local previewCount = 0
                local layout = EditorLayout.draw(288, 200, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {
                        { id = "editorProperties", label = "Editor Properties" },
                        { id = "mixtapeProperties", label = "Mixtape Properties" },
                    },
                    selectedEventId = "editorProperties",
                    properties = {
                        { id = "snap", label = "Snap", kind = "number", value = 1 },
                        { id = "scale", label = "Scale", kind = "number", value = 1 },
                        { id = "playbackRate", label = "Playback Rate", kind = "number", value = 1 },
                        { id = "metronome", label = "Metronome", kind = "boolean", value = false },
                        { id = "metronomePeriod", label = "Metronome Period", kind = "number", value = 4 },
                    },
                    valueEdit = nil,
                    beat = 2.5,
                    timelineStartBeat = 0,
                    scale = 1,
                    menuItems = items,
                    hoveredAction = nil,
                }, function()
                    previewCount = previewCount + 1
                end)

                for _, label in ipairs({ "Menu", "Categories", "Events", "Properties", "Values" }) do
                    assertHeading(test, recorder, label, true)
                end
                test.assertEqual(countPrints(recorder, "> Global"), 1)
                test.assertEqual(countPrints(recorder, "> Editor Properties"), 1)
                test.assertEqual(countPrints(recorder, "  Mixtape Properties"), 1)
                test.assertEqual(countPrints(recorder, "Scale"), 1)
                test.assertEqual(countPrints(recorder, "Playback Rate"), 1)
                test.assertEqual(countPrints(recorder, "Metronome"), 1)
                test.assertEqual(countPrints(recorder, "Metronome Period"), 1)
                test.assertEqual(countPrints(recorder, "Snap"), 1)
                test.assertEqual(countPrints(recorder, "Onset Threshold"), 0)
                test.assertEqual(countPrints(recorder, "false"), 1)
                local periodRect = EditorLayout.getPropertyValueRect(layout, 5)
                test.assertEqual(countPrints(recorder, "4", periodRect.y + 3), 1)
                test.assertEqual(previewCount, 0)
                test.assertEqual(#recorder.pushes, 1)
                test.assertEqual(recorder.pushes[1], "all")
                test.assertEqual(recorder.pops, 1)
                test.assertEqual(#recorder.clears, 1)
                assertTimelineLabels(test, recorder, layout.timeline, { "0", "4" })
                assertPlayhead(test, recorder, layout, 112)
            end)
        end,
    },
    {
        name = "Play와 Pause 활성 상태는 재생 여부에 따라 교대한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local EditorLayout = require("editor.ui.EditorLayout")
            local stopped = EditorMenu.getItems(sessionState({ hasStage = true }))
            local playing = EditorMenu.getItems(sessionState({ hasStage = true, playing = true }))
            test.assertEqual(stopped[5].enabled, true)
            test.assertEqual(stopped[6].enabled, false)
            test.assertEqual(playing[5].enabled, false)
            test.assertEqual(playing[6].enabled, true)

            withGraphicsRecorder(function(recorder)
                local previewCalls = {}
                local layout = EditorLayout.draw(288, 200, {
                    hasStage = true,
                    playing = true,
                    propertyEvents = {
                        { id = "editorProperties", label = "Editor Properties" },
                        { id = "mixtapeProperties", label = "Mixtape Properties" },
                    },
                    selectedEventId = "editorProperties",
                    properties = {},
                    valueEdit = nil,
                    beat = 6,
                    anchorBeat = 5,
                    playbackBeat = 6,
                    timelineStartBeat = 4,
                    scale = 1,
                    menuItems = playing,
                    hoveredAction = nil,
                }, function(rect)
                    table.insert(previewCalls, rect)
                end)

                assertHeading(test, recorder, "Menu", true)
                assertHeading(test, recorder, "Categories", true)
                assertHeading(test, recorder, "Events", true)
                assertHeading(test, recorder, "Properties", false)
                assertHeading(test, recorder, "Values", false)
                test.assertEqual(countPrints(recorder, "> Global"), 1)
                test.assertEqual(countPrints(recorder, "> Editor Properties"), 1)
                test.assertEqual(countPrints(recorder, "  Mixtape Properties"), 1)
                test.assertEqual(countPrints(recorder, "BPM"), 0)
                test.assertEqual(countPrints(recorder, "123"), 0)
                test.assertEqual(#previewCalls, 1)
                local expectedPreview = EditorLayout.getPreviewRect(layout)
                test.assertEqual(previewCalls[1].x, expectedPreview.x)
                test.assertEqual(previewCalls[1].y, expectedPreview.y)
                test.assertEqual(previewCalls[1].width, expectedPreview.width)
                test.assertEqual(previewCalls[1].height, expectedPreview.height)
                assertTimelineLabels(test, recorder, layout.timeline, { "4", "8" })
                assertPlayhead(test, recorder, layout, 64)
                assertPlaybackHead(test, recorder, layout, 96, true)
            end)
        end,
    },
    {
        name = "Menu hit test는 클릭한 활성 항목을 반환한다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local panel = { x = 0, y = 0, width = 180, height = 360 }
            local items = EditorMenu.getItems(sessionState())
            local item = EditorMenu.hitTest(panel, items, 20, 44)
            test.assertEqual(item.action, "new")
        end,
    },
    {
        name = "Events와 Property Values 동적 행 영역을 계산한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)
            local preview = EditorLayout.getPreviewRect(layout)
            local event = EditorLayout.getEventRowRect(layout, 2)
            local value = EditorLayout.getPropertyValueRect(layout, 4)
            test.assertEqual(layout.panels[1].height, 392)
            test.assertEqual(layout.timeline.x, 0)
            test.assertEqual(layout.timeline.y, 392)
            test.assertEqual(layout.timeline.width, 1200)
            test.assertEqual(layout.timeline.height, 408)
            test.assertEqual(preview.x, layout.panels[4].x)
            test.assertEqual(preview.y, layout.panels[4].y)
            test.assertEqual(preview.width, layout.panels[4].width + layout.panels[5].width)
            test.assertEqual(preview.height, layout.panels[4].height)
            test.assertEqual(event.x, layout.panels[3].x)
            test.assertEqual(event.y, 56)
            test.assertEqual(event.width, layout.panels[3].width)
            test.assertEqual(event.height, 24)
            test.assertEqual(value.x, layout.panels[5].x)
            test.assertEqual(value.y, 104)
            test.assertEqual(value.width, layout.panels[5].width)
            test.assertEqual(value.height, 24)
            test.assertEqual(EditorLayout.getPixelsPerBeat(0.25), 8)
            test.assertEqual(EditorLayout.getPixelsPerBeat(1), 32)
            test.assertEqual(EditorLayout.getPixelsPerBeat(8), 256)
            local timelineEvent = EditorLayout.getTimelineEventRect(
                layout.timeline,
                { type = "end", startBeat = 4, track = 1 },
                { scale = 2, timelineStartBeat = 0, trackCount = 10 }
            )
            test.assertEqual(timelineEvent.x, 320)
            test.assertEqual(timelineEvent.width, 16)
            test.assertEqual(EditorLayout.getVisibleBeatCount(layout, 1), 36)
            test.assertEqual(EditorLayout.getVisibleBeatCount(layout, 2), 17)
            test.assertEqual(EditorLayout.getVisibleBeatCount(layout, 0.25), 149)
            test.assertEqual(EditorLayout.hitTestEvent(layout, 2, event.x, event.y), 2)
            test.assertEqual(EditorLayout.hitTestEvent(layout, 1, event.x, event.y), nil)
            test.assertEqual(EditorLayout.hitTestEvent(layout, 2, event.x + event.width, event.y), nil)
            test.assertEqual(EditorLayout.hitTestPropertyValue(layout, 4, value.x, value.y), 4)
            test.assertEqual(EditorLayout.hitTestPropertyValue(layout, 3, value.x, value.y), nil)
            test.assertEqual(EditorLayout.hitTestPropertyValue(
                layout,
                4,
                value.x,
                value.y + value.height
            ), nil)
        end,
    },
    {
        name = "패널 행은 스크롤 offset을 적용하고 내용이 넘칠 때만 스크롤바를 제공한다",
        run = function(test)
            local ScrollArea = require("core").UI.ScrollArea
            local EditorLayout = require("editor.ui.EditorLayout")
            local layout = EditorLayout.getLayout(1200, 800)
            local area = ScrollArea.new({ step = 24 })
            local contentHeight = layout.panels[3].height - 32

            area:setDimensions(contentHeight, contentHeight)
            test.assertEqual(EditorLayout.getScrollbarRect(layout.panels[3], area), nil)

            area:setDimensions(contentHeight + 24, contentHeight)
            area:scroll(-1)
            local event = EditorLayout.getEventRowRect(layout, 2, area:getOffset())
            local value = EditorLayout.getPropertyValueRect(layout, 2, area:getOffset())
            test.assertEqual(event.y, 32)
            test.assertEqual(value.y, 32)
            test.assertEqual(EditorLayout.hitTestEvent(
                layout,
                8,
                event.x + 8,
                event.y + 8,
                area:getOffset()
            ), 2)
            test.assertEqual(EditorLayout.hitTestPropertyValue(
                layout,
                8,
                value.x + 8,
                value.y + 8,
                area:getOffset()
            ), 2)

            local scrollbar = EditorLayout.getScrollbarRect(layout.panels[3], area)
            test.assertTrue(scrollbar ~= nil)
            test.assertEqual(scrollbar.x, layout.panels[3].x + layout.panels[3].width - 6)
            test.assertTrue(scrollbar.y > 32)
            test.assertTrue(scrollbar.height < contentHeight)

            withGraphicsRecorder(function(recorder)
                local properties = {}
                for index = 1, 8 do
                    properties[index] = {
                        id = "property" .. index,
                        label = "Property " .. index,
                        kind = "number",
                        value = index,
                    }
                end
                local drawnLayout = EditorLayout.draw(1200, 800, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {},
                    selectedEventId = "test",
                    properties = properties,
                    valueEdit = nil,
                    beat = 0,
                    timelineStartBeat = 0,
                    scale = 1,
                    menuItems = {},
                    scrollAreas = { properties = area },
                }, function() end)
                local drawnScrollbar = EditorLayout.getScrollbarRect(
                    drawnLayout.panels[5],
                    area
                )
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = drawnScrollbar.x,
                    y = drawnScrollbar.y,
                    width = drawnScrollbar.width,
                    height = drawnScrollbar.height,
                }), { 0.5, 0.52, 0.56, 0.9 })
            end)
        end,
    },
    {
        name = "타임라인은 Scale과 fractional 시작 beat로 label stripe playhead를 그린다",
        run = function(test)
            local EditorMenu = require("editor.menu.EditorMenu")
            local EditorLayout = require("editor.ui.EditorLayout")
            local items = EditorMenu.getItems(sessionState({ hasStage = true }))

            withGraphicsRecorder(function(recorder)
                local layout = EditorLayout.draw(288, 200, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {},
                    selectedEventId = "editorProperties",
                    properties = {},
                    valueEdit = nil,
                    beat = 2.5,
                    timelineStartBeat = 0.5,
                    scale = 2,
                    metronomePeriod = 3,
                    menuItems = items,
                    hoveredAction = nil,
                }, function() end)

                local firstStripe = findRectangle(recorder, {
                    mode = "fill",
                    x = 64,
                    y = layout.timeline.y + 32,
                    width = 32,
                    height = layout.timeline.height - 32,
                })
                assertColor(test, firstStripe, { 0.23, 0.24, 0.26, 1 })
                test.assertEqual(
                    countPrints(recorder, "3", layout.timeline.y + 8),
                    1
                )
                test.assertEqual(
                    countPrints(recorder, "4", layout.timeline.y + 8),
                    0
                )
                local timelineLabel
                for _, call in ipairs(recorder.prints) do
                    if call.text == "3" and call.y == layout.timeline.y + 8 then
                        timelineLabel = call
                    end
                end
                test.assertEqual(timelineLabel.x, 220)
                assertPlayhead(test, recorder, layout, 192)
                test.assertEqual(#recorder.polygons, 1)
                local handle = recorder.polygons[1]
                test.assertEqual(handle.mode, "fill")
                test.assertEqual(handle.points[1], 185)
                test.assertEqual(handle.points[2], layout.timeline.y)
                test.assertEqual(handle.points[3], 199)
                test.assertEqual(handle.points[4], layout.timeline.y)
                test.assertEqual(handle.points[5], 192)
                test.assertEqual(handle.points[6], layout.timeline.y + 12)
                assertColor(test, handle, { 1, 0.45, 0.2, 1 })
                test.assertEqual(EditorLayout.hitTestPlayheadHandle(
                    layout.timeline,
                    {
                        beat = 2.5,
                        timelineStartBeat = 0.5,
                        scale = 2,
                    },
                    192,
                    layout.timeline.y + 6
                ), true)
                test.assertEqual(EditorLayout.hitTestPlayheadHandle(
                    layout.timeline,
                    {
                        beat = 2.5,
                        timelineStartBeat = 0.5,
                        scale = 2,
                    },
                    204,
                    layout.timeline.y + 6
                ), false)
            end)
        end,
    },
    {
        name = "Timeline Event 노드 이름은 박스 안에서 잘리고 hover하면 전체를 보인다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            withGraphicsRecorder(function(recorder)
                local layout = EditorLayout.draw(1200, 800, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {},
                    selectedEventId = "end",
                    properties = {},
                    timelineEvents = {
                        {
                            id = "end-1",
                            type = "end",
                            label = "End",
                            startBeat = 4,
                            track = 2,
                            color = { 0.68, 0.32, 0.9, 1 },
                        },
                        {
                            id = "input-1",
                            type = "setInputEnabled",
                            label = "Set Input Enabled",
                            startBeat = 6,
                            track = 3,
                            color = { 0.12, 0.72, 0.62, 1 },
                        },
                        {
                            id = "selected-1",
                            type = "end",
                            label = "End",
                            startBeat = 8,
                            track = 4,
                            color = { 0.68, 0.32, 0.9, 1 },
                        },
                        {
                            id = "collision-1",
                            type = "end",
                            label = "End",
                            startBeat = 10,
                            track = 5,
                            color = { 0.68, 0.32, 0.9, 1 },
                        },
                    },
                    selectedTimelineEventIds = { ["selected-1"] = true },
                    draggingTimelineEventIds = { ["selected-1"] = true },
                    collisionTimelineEventIds = { ["collision-1"] = true },
                    hoveredTimelineEventId = "input-1",
                    trackCount = 10,
                    beat = 0,
                    anchorBeat = 0,
                    timelineStartBeat = 0,
                    scale = 1,
                    metronomePeriod = 4,
                    menuItems = {},
                }, function() end)

                local endRect = EditorLayout.getTimelineEventRect(
                    layout.timeline,
                    { type = "end", startBeat = 4, track = 2 },
                    { scale = 1, timelineStartBeat = 0, trackCount = 10 }
                )
                local inputRect = EditorLayout.getTimelineEventRect(
                    layout.timeline,
                    { type = "setInputEnabled", startBeat = 6, track = 3 },
                    { scale = 1, timelineStartBeat = 0, trackCount = 10 }
                )
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = endRect.x,
                    y = endRect.y,
                    width = endRect.width,
                    height = endRect.height,
                }), { 0.68, 0.32, 0.9, 1 })
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = inputRect.x,
                    y = inputRect.y,
                    width = inputRect.width,
                    height = inputRect.height,
                }), { 0.12, 0.72, 0.62, 1 })
                local selectedRect = EditorLayout.getTimelineEventRect(
                    layout.timeline,
                    { type = "end", startBeat = 8, track = 4 },
                    { scale = 1, timelineStartBeat = 0, trackCount = 10 }
                )
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = selectedRect.x,
                    y = selectedRect.y,
                    width = selectedRect.width,
                    height = selectedRect.height,
                }), { 1, 1, 1, 0.55 })
                local collisionRect = EditorLayout.getTimelineEventRect(
                    layout.timeline,
                    { type = "end", startBeat = 10, track = 5 },
                    { scale = 1, timelineStartBeat = 0, trackCount = 10 }
                )
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = collisionRect.x,
                    y = collisionRect.y,
                    width = collisionRect.width,
                    height = collisionRect.height,
                }), { 1, 0.12, 0.12, 1 })
                local hoveredMain
                local hoveredOutlineCount = 0
                local defaultMain
                local defaultOutlineCount = 0
                for _, call in ipairs(recorder.prints) do
                    if call.text == "Set Input Enabled" then
                        if call.x == inputRect.x + 4 and call.y == inputRect.y then
                            hoveredMain = call
                        else
                            hoveredOutlineCount = hoveredOutlineCount + 1
                            assertColor(test, call, { 0.05, 0.05, 0.06, 0.9 })
                        end
                        test.assertEqual(call.scissor, nil)
                    elseif call.text == "End" and call.scissor
                        and call.scissor.x == endRect.x then
                        if call.x == endRect.x + 4 and call.y == endRect.y then
                            defaultMain = call
                        else
                            defaultOutlineCount = defaultOutlineCount + 1
                            assertColor(test, call, { 0.05, 0.05, 0.06, 0.9 })
                        end
                        test.assertEqual(call.scissor.width, endRect.width)
                    end
                end
                assertColor(test, hoveredMain, { 0.95, 0.95, 0.97, 1 })
                assertColor(test, defaultMain, { 0.95, 0.95, 0.97, 1 })
                test.assertEqual(hoveredOutlineCount, 8)
                test.assertEqual(defaultOutlineCount, 8)
            end)
        end,
    },
    {
        name = "error toast는 화면 우상단에 메시지를 렌더링한다",
        run = function(test)
            local EditorLayout = require("editor.ui.EditorLayout")
            withGraphicsRecorder(function(recorder)
                EditorLayout.draw(1200, 800, {
                    hasStage = false,
                    playing = false,
                    categories = {},
                    propertyEvents = {},
                    properties = {},
                    timelineEvents = {},
                    beat = 0,
                    anchorBeat = 0,
                    timelineStartBeat = 0,
                    scale = 1,
                    metronomePeriod = 4,
                    menuItems = {},
                    toasts = {
                        {
                            kind = "error",
                            message = "Timeline Events overlap.",
                        },
                        {
                            kind = "error",
                            message = "Older error.",
                        },
                    },
                }, function() end)
                local message = findPrint(recorder, "Timeline Events overlap.")
                test.assertTrue(message ~= nil)
                test.assertTrue(message.x > 600)
                test.assertTrue(message.y < 100)
                local older = findPrint(recorder, "Older error.")
                test.assertTrue(older ~= nil)
                test.assertTrue(older.y > message.y)
            end)
        end,
    },
    {
        name = "숫자 인라인 편집 상태와 invalid를 해당 Values 셀에 표시한다",
        run = function(test)
            local Button = require("core").UI.Button
            local EditorMenu = require("editor.menu.EditorMenu")
            local EditorLayout = require("editor.ui.EditorLayout")
            local items = EditorMenu.getItems(sessionState({ hasStage = true }))

            withGraphicsRecorder(function(recorder)
                local layout = EditorLayout.draw(1200, 800, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {
                        { id = "editorProperties", label = "Editor Properties" },
                        { id = "mixtapeProperties", label = "Mixtape Properties" },
                    },
                    selectedEventId = "mixtapeProperties",
                    properties = {
                        { id = "music", label = "Music", kind = "music", value = nil },
                        { id = "volume", label = "Volume", kind = "number", value = 1 },
                        {
                            id = "beat0Offset",
                            label = "Beat 0 Offset",
                            kind = "number",
                            value = 0,
                            actionButton = Button.new({
                                id = "detectBeat0Offset",
                                label = "Auto",
                            }),
                        },
                        {
                            id = "onsetThreshold",
                            label = "Onset Threshold",
                            kind = "number",
                            groupId = "editorProperties",
                            value = 0,
                        },
                        { id = "bpm", label = "BPM", kind = "number", value = 120 },
                    },
                    valueEdit = {
                        groupId = "mixtapeProperties",
                        propertyId = "bpm",
                        text = "135",
                        cursorPosition = 3,
                        invalid = false,
                    },
                    beat = 0,
                    timelineStartBeat = 0,
                    scale = 1,
                    menuItems = items,
                    hoveredAction = nil,
                }, function() end)
                local bpm = EditorLayout.getPropertyValueRect(layout, 5)
                local outline = findRectangle(recorder, {
                    mode = "line",
                    x = bpm.x + 4,
                    y = bpm.y + 2,
                    width = bpm.width - 8,
                    height = bpm.height - 4,
                })

                test.assertEqual(countPrints(recorder, "135"), 1)
                test.assertEqual(countPrints(recorder, "120"), 0)
                test.assertEqual(countPrints(recorder, "None"), 1)
                test.assertEqual(countPrints(recorder, "Auto"), 1)
                local autoRect = EditorLayout.getPropertyActionRect(layout, 3)
                assertColor(test, findRectangle(recorder, {
                    mode = "fill",
                    x = autoRect.x,
                    y = autoRect.y,
                    width = autoRect.width,
                    height = autoRect.height,
                }), { 0.24, 0.25, 0.29, 1 })
                assertColor(test, outline, { 1, 0.45, 0.2, 1 })
                test.assertTrue(findRectangle(recorder, {
                    mode = "fill",
                    x = bpm.x + 36,
                    y = bpm.y + 4,
                    width = 1,
                    height = bpm.height - 8,
                }) ~= nil)
            end)

            withGraphicsRecorder(function(recorder)
                local layout = EditorLayout.draw(1200, 800, {
                    hasStage = true,
                    playing = false,
                    propertyEvents = {
                        { id = "editorProperties", label = "Editor Properties" },
                        { id = "mixtapeProperties", label = "Mixtape Properties" },
                    },
                    selectedEventId = "mixtapeProperties",
                    properties = {
                        { id = "music", label = "Music", kind = "music", value = nil },
                        { id = "volume", label = "Volume", kind = "number", value = 1 },
                    },
                    valueEdit = {
                        groupId = "mixtapeProperties",
                        propertyId = "volume",
                        text = "2",
                        cursorPosition = 1,
                        cursorVisible = false,
                        invalid = true,
                    },
                    beat = 0,
                    timelineStartBeat = 0,
                    scale = 1,
                    menuItems = items,
                    hoveredAction = nil,
                }, function() end)
                local volume = EditorLayout.getPropertyValueRect(layout, 2)
                local outline = findRectangle(recorder, {
                    mode = "line",
                    x = volume.x + 4,
                    y = volume.y + 2,
                    width = volume.width - 8,
                    height = volume.height - 4,
                })

                test.assertEqual(countPrints(recorder, "2"), 1)
                test.assertEqual(countPrints(recorder, "1"), 0)
                assertColor(test, outline, { 0.92, 0.3, 0.3, 1 })
                test.assertEqual(findRectangle(recorder, {
                    mode = "fill",
                    x = volume.x + 20,
                    y = volume.y + 4,
                    width = 1,
                    height = volume.height - 8,
                }), nil)
            end)
        end,
    },
}
