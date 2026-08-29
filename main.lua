-- 이 파일은 LÖVE가 가장 먼저 읽는 애플리케이션 진입점이다.
--
-- LÖVE 프로그램에는 일반 Lua 프로그램의 main() 함수 대신 love.load,
-- love.update, love.draw 같은 이름이 정해진 콜백(callback)이 있다. 엔진은 앱을
-- 시작하거나 frame을 그려야 할 때 해당 함수를 자동으로 찾아 호출한다.
-- 이 파일은 실제 Launcher나 Editor 기능을 직접 구현하지 않고, LÖVE가 전달한
-- 생명주기와 입력 이벤트를 현재 실행 중인 앱 객체에 넘기는 얇은 연결 계층이다.

-- local로 선언한 값은 이 파일 안에서만 보인다. 초기값 nil은 아직 실행할 앱이
-- 만들어지지 않았다는 뜻이다. 이후 love.load에서 Launcher 객체가 대입된다.
-- Launcher는 상황에 따라 메뉴, Editor 또는 Project에 다시 호출을 전달한다.
local activeApp = nil

-- 명령행 인자 목록에 expected 문자열이 있는지 찾는다.
-- local function 역시 이 파일 밖에서는 접근할 수 없는 보조 함수다.
local function containsArgument(arguments, expected)
    -- Lua의 "arguments or {}"는 arguments가 nil 또는 false이면 빈 table을 사용한다.
    -- 따라서 LÖVE가 인자 목록을 주지 않더라도 ipairs(nil) 오류가 발생하지 않는다.
    --
    -- ipairs는 배열처럼 1, 2, 3... 정수 key를 가진 table을 순서대로 순회한다.
    -- 첫 번째 반환값은 index지만 여기서는 필요하지 않으므로 관례상 _로 받는다.
    for _, argument in ipairs(arguments or {}) do
        if argument == expected then
            return true
        end
    end

    return false
end

-- "love . --test"로 실행했을 때 게임 대신 자동 테스트를 실행한다.
local function runTests()
    -- xpcall은 첫 번째 함수 내부에서 발생한 Lua 오류를 잡아 프로그램 전체가 즉시
    -- 중단되는 것을 막는다. 두 번째 인자인 debug.traceback은 오류 메시지에 호출
    -- 경로를 붙인다. 성공하면 succeeded가 true이고, 실패하면 false와 가공된 오류
    -- 문자열이 반환된다. Lua 함수는 이처럼 여러 값을 동시에 반환할 수 있다.
    local succeeded, errorMessage = xpcall(function()
        -- require는 모듈 파일을 한 번 실행하고 그 파일이 return한 값을 가져온다.
        -- "tests.TestRunner"는 관례에 따라 tests/TestRunner.lua를 가리킨다.
        local TestRunner = require("tests.TestRunner")
        TestRunner.run()
    end, debug.traceback)

    if not succeeded then
        -- .. 연산자는 문자열을 이어 붙인다. stderr를 사용하면 테스트 실패가 일반
        -- 게임 출력과 구분되며, 마지막 개행으로 콘솔 출력도 온전히 마무리된다.
        io.stderr:write(errorMessage .. "\n")
    end

    -- Lua에는 별도의 삼항 연산자가 없어서 "조건 and 참값 or 거짓값" 관용구를
    -- 자주 사용한다. 테스트 성공 시 process exit code 0, 실패 시 1로 종료한다.
    love.event.quit(succeeded and 0 or 1)
end

-- 앱 시작 시 LÖVE가 한 번 호출한다. arguments에는 실행 시 전달한 인자가 들어온다.
function love.load(arguments)
    -- 테스트 모드에서는 Launcher를 만들지 않는다. runTests가 종료 이벤트를 요청한
    -- 뒤 return하여 아래의 일반 앱 초기화가 이어서 실행되지 않게 한다.
    if containsArgument(arguments, "--test") then
        runTests()
        return
    end

    -- 일반 실행에만 필요한 모듈은 여기서 불러온다. 테스트 모드가 Launcher와 그래픽
    -- 리소스를 불필요하게 초기화하지 않도록 파일 맨 위가 아닌 이 위치에 둔 것이다.
    local AppFont = require("launcher.AppFont")
    local Launcher = require("launcher.Launcher")
    AppFont.apply()
    activeApp = Launcher.new()
end

-- 매 frame마다 화면을 그리기 전에 호출된다. deltaTime은 직전 frame 이후 실제로
-- 흐른 초 단위 시간이며, frame rate와 무관한 이동 및 애니메이션에 사용한다.
function love.update(deltaTime)
    -- Lua의 and는 왼쪽부터 평가하고 false/nil을 만나면 뒤를 평가하지 않는다.
    -- 따라서 activeApp이 아직 nil이거나 update 메서드가 없는 객체여도 안전하다.
    if activeApp and activeApp.update then
        -- object:method(value)는 object.method(object, value)의 축약형이다.
        -- 즉 콜론 호출은 activeApp을 메서드의 첫 인자 self로 자동 전달한다.
        activeApp:update(deltaTime)
    end
end

-- 매 frame의 렌더링 시점에 호출된다. 실제 메뉴·Editor·Project 그림은 activeApp이
-- 담당하므로 이 진입점은 draw 호출만 전달한다.
function love.draw()
    if activeApp and activeApp.draw then
        activeApp:draw()
    end
end

-- 키를 누른 순간 호출된다. key는 "space" 같은 논리 key 이름, scanCode는 물리적
-- 키 위치, isRepeat는 키를 계속 누를 때 OS의 반복 입력으로 발생했는지를 나타낸다.
function love.keypressed(key, scanCode, isRepeat)
    if activeApp and activeApp.keypressed then
        activeApp:keypressed(key, scanCode, isRepeat)
    end
end

-- 키에서 손을 뗀 순간 호출된다. Long Note처럼 누른 시간과 해제 시점이 모두 필요한
-- Project가 있으므로 keypressed와 별도로 전달한다.
function love.keyreleased(key, scanCode)
    if activeApp and activeApp.keyreleased then
        activeApp:keyreleased(key, scanCode)
    end
end

-- 마우스가 움직일 때 호출된다. x/y는 현재 좌표이고 deltaX/deltaY는 직전 위치에서의
-- 이동량이다. isTouch는 touch 입력이 마우스 이벤트로 변환된 경우를 구분한다.
function love.mousemoved(x, y, deltaX, deltaY, isTouch)
    if activeApp and activeApp.mousemoved then
        activeApp:mousemoved(x, y, deltaX, deltaY, isTouch)
    end
end

-- 마우스 wheel 입력이다. 보통 deltaY를 세로 스크롤이나 Timeline 확대에 사용한다.
function love.wheelmoved(deltaX, deltaY)
    if activeApp and activeApp.wheelmoved then
        activeApp:wheelmoved(deltaX, deltaY)
    end
end

-- 마우스 button을 누른 순간 호출된다. LÖVE에서 button 1은 왼쪽, 2는 오른쪽,
-- 3은 가운데 button이다. presses에는 double click 같은 연속 click 횟수가 들어온다.
function love.mousepressed(x, y, button, isTouch, presses)
    if activeApp and activeApp.mousepressed then
        activeApp:mousepressed(x, y, button, isTouch, presses)
    end
end

-- drag 종료나 button 해제 처리를 위해 누름과 별도로 release 이벤트도 전달한다.
function love.mousereleased(x, y, button, isTouch, presses)
    if activeApp and activeApp.mousereleased then
        activeApp:mousereleased(x, y, button, isTouch, presses)
    end
end

-- 사용자가 실제 문자를 입력했을 때 호출된다. keypressed와 달리 keyboard layout과
-- 한글 입력기 등을 거친 UTF-8 text를 받으므로 Editor의 text field는 이를 사용한다.
function love.textinput(text)
    if activeApp and activeApp.textinput then
        activeApp:textinput(text)
    end
end
