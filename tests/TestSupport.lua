local TestSupport = {}

function TestSupport.assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format(
            "%s\nexpected: %s\nactual: %s",
            message or "값이 일치하지 않습니다.",
            tostring(expected),
            tostring(actual)
        ), 2)
    end
end

function TestSupport.assertTrue(value, message)
    if not value then
        error(message or "참이어야 합니다.", 2)
    end
end

function TestSupport.assertContains(text, expected, message)
    if type(text) ~= "string" or not string.find(text, expected, 1, true) then
        error(message or string.format("문자열에 '%s'가 없습니다.", expected), 2)
    end
end

return TestSupport
