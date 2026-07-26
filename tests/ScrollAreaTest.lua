return {
    {
        name = "ScrollArea는 넘치는 내용만 휠로 스크롤하고 범위를 제한한다",
        run = function(test)
            local ScrollArea = require("core").UI.ScrollArea
            local area = ScrollArea.new({ step = 24 })

            area:setDimensions(240, 168)
            test.assertEqual(area:isScrollable(), true)
            test.assertEqual(area:getOffset(), 0)
            test.assertEqual(area:scroll(-1), true)
            test.assertEqual(area:getOffset(), 24)
            area:scroll(-10)
            test.assertEqual(area:getOffset(), 72)
            area:scroll(10)
            test.assertEqual(area:getOffset(), 0)

            area:setDimensions(120, 168)
            test.assertEqual(area:isScrollable(), false)
            test.assertEqual(area:getOffset(), 0)
            test.assertEqual(area:scroll(-1), false)
        end,
    },
    {
        name = "ScrollArea는 필요한 경우에만 스크롤바 thumb 위치를 제공한다",
        run = function(test)
            local ScrollArea = require("core").UI.ScrollArea
            local area = ScrollArea.new()

            area:setDimensions(336, 168)
            local thumb = area:getThumb(168, 16)
            test.assertEqual(thumb.position, 0)
            test.assertEqual(thumb.length, 84)

            area:setOffset(84)
            thumb = area:getThumb(168, 16)
            test.assertEqual(thumb.position, 42)
            test.assertEqual(thumb.length, 84)

            area:setDimensions(168, 168)
            test.assertEqual(area:getThumb(168, 16), nil)
        end,
    },
}
