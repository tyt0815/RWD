return {
    {
        name = "ComboBox는 입력으로 목록을 필터링하고 선택한다",
        run = function(test)
            local ComboBox = require("editor.ui.ComboBox")
            local comboBox = ComboBox.new({
                { value = "alpha", label = "Alpha" },
                { value = "sample", label = "Sample Project" },
                { value = "other", label = "Other" },
            })

            test.assertEqual(comboBox:getValue(), "alpha")
            comboBox:open()
            comboBox:textinput("amp")

            local visibleOptions = comboBox:getVisibleOptions(6)
            test.assertEqual(#visibleOptions, 1)
            test.assertEqual(visibleOptions[1].label, "Sample Project")
            test.assertEqual(comboBox:keypressed("return"), "selected")
            test.assertEqual(comboBox:getValue(), "sample")
            test.assertEqual(comboBox:isOpen(), false)
        end,
    },
    {
        name = "ComboBox는 키보드 이동과 Escape 닫기를 지원한다",
        run = function(test)
            local ComboBox = require("editor.ui.ComboBox")
            local comboBox = ComboBox.new({
                { value = "one", label = "One" },
                { value = "two", label = "Two" },
                { value = "three", label = "Three" },
            })

            comboBox:open()
            comboBox:keypressed("down")
            test.assertEqual(comboBox:keypressed("return"), "selected")
            test.assertEqual(comboBox:getValue(), "two")

            comboBox:open()
            test.assertEqual(comboBox:keypressed("escape"), "closed")
            test.assertEqual(comboBox:isOpen(), false)
        end,
    },
}
