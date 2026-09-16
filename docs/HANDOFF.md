# 인수인계

## 현재 구현 상태

스피키 idle(smile)은 매 박자 0.12박 동안 높이가 최대 12% 눌리고 다음 0.48박 동안 부드럽게 복원된다. 스프라이트 하단과 가로 크기·위치는 고정하며 Tap·Long 효과에는 적용하지 않는다. Stage beat로 직접 계산해 중간 재생·되감기·일시정지에 동기화한다. Project 전용 연출이므로 기존 Core 박자와 이동 API를 유지하고 `SpeakiActor.lua`에서 처리한다.

크레페 방향 전환에는 `Core.BeatTween`을 조합한 0.25박 종이 플립을 적용한다. 중심과 높이를 유지하며 가로 scale이 기존 방향 → 0 → 반대 방향으로 변한다. 전환 중에도 연속 이동과 두 박자 걷기 애니메이션은 진행하며, 매 draw에서 기존 Turn 일정으로 보간 상태를 복원해 중간 재생·되감기에도 일치한다. 효과 길이는 `FLIP_DURATION_BEATS`로 조정한다.

Editor Properties의 `Fullscreen` boolean(기본 false)이 Preview 확대 여부를 소유한다. Tab은 정지·재생 중 이 설정을 전환하며 true이면 재생 시작부터 창 전체로 확대한다. 모니터 전체 화면 전환은 아니며 기존 Preview 종횡비를 유지하고 남는 영역을 검정색으로 채운다. Tab·Esc는 재생을 유지한 채 패널로 복귀하고 F·R·Space는 기존 동작을 유지한다. 확대 중 숨겨진 편집 화면의 마우스 입력을 막으며 재생 종료·오류 시 편집 화면으로 돌아가되 설정은 유지한다. Esc는 Fullscreen을 false로 바꾼다. Stage의 editorSettings.fullscreen에 희소 저장하며 별도 임시 확대 상태는 없다.

사용자는 Editor Properties에 true/false로 게임 화면과 소리를 영상 저장하는 녹화를 요청했다. LÖVE 내장 지원 여부를 확인하는 단계이며 녹화 백엔드는 미정이다. Record 속성과 녹화 기능은 아직 추가하지 않았다. LÖVE의 screenshot과 입력 장치 RecordingDevice만으로 완성된 게임 영상 녹화를 제공할 수 없어 인코딩·출력 소리 캡처 방식 결정이 필요하다.

크레페는 오른쪽 이동 턴(guide)에서 중심 기준으로 좌우 반전하고, 왼쪽 이동 턴(player)에서는 원본 방향으로 그린다. 12프레임 애니메이션은 두 박자 동안 한 사이클을 재생하며, 이동은 소수 beat를 사용해 연속적으로 이어진다. 방향 반전은 기존처럼 정수 박자에 적용하므로 Turn이 2.5박에 시작하면 3박에 방향을 바꾸되 위치는 끊기지 않는다. 이때 2박 주기의 프레임 전환과도 일치하며 애니메이션을 강제로 처음으로 돌리지 않는다. 중간 재생·되감기에도 같은 박자 기준으로 복원된다.

Editor 미리보기 합성 시 직전에 사용한 UI 색상·알파가 Canvas에 곱해져 흰색이 어두워지는 문제를 수정했다. `TestPlayer:draw`는 Canvas를 흰색·불투명으로 합성한 뒤 이전 색상을 복원한다. Project 배경색은 기존 순백색을 유지한다.

스피키송 소환 이후 `CrepeActor`는 Stage beat 0에서 상단 중앙에 있는 한 명만 표시한다. 가로 반복 복사본을 제거했으며 기존 12프레임의 두 박자 걷기, Turn 방향별 연속 이동과 0.25박 종이 플립은 유지한다. 화면 밖으로 완전히 나가면 반대쪽에서 다시 들어온다. 세로 중심은 화면 높이 22%, 이미지 영역 높이는 32%(너비 상한 30%)이며 Stage beat로 위치와 프레임을 복원한다.

스피키송 배경은 사용자 요청으로 `ghost_basic.png`를 다시 로드하고 표시한다. 소환 이후 이미지 비율을 유지하며 화면 전체를 채우도록 중앙에 확대해서 그린다.

스피키송 자동 Turn의 대기 액터는 완전히 퇴장하지 않고 바깥쪽 끝만 `outsidePadding`(기본 12px)만큼 화면 경계에 걸친다. 캐릭터 대부분은 화면 안에 남으며 기존 Core.BeatTween 조합과 이동 시간은 유지한다.

Editor 오류 모달에 `Copy (Ctrl+C)` 버튼과 Ctrl+C 단축키를 추가했다. 오류 메시지 전문을 OS 클립보드로 복사하고 버튼을 `Copied`로 바꾸며 모달은 유지한다. Enter·Esc·OK는 기존처럼 닫는다.

Windows에서 한글이 포함된 sourceRoot로 Stage를 열 때 `io.open`이 `Invalid argument`를 반환하던 오류를 수정했다. `NativeFileSystem`은 Windows의 비 ASCII 경로에 한해 `WindowsFileSystem`의 UTF-8 → UTF-16 변환과 wide CRT 파일 함수를 사용한다. 존재 확인·읽기·쓰기·복사·이름 변경·삭제 모두 같은 경로 처리를 사용하며, 기존 source 파일 접근과 packaged 읽기 전용 계약을 유지한다.

Core Stage 소유권 구조 개편 Phase 1이 완료되었다. `require("core")`는 API version 2와 함께 `StageSchema`, `StageRepository`, `ProjectManifest`를 공개한다. Stage 형식·정규화는 `StageSchema`, 경로·JSON decode/encode·원자 저장은 `StageRepository`, Project 매니페스트 구조와 Core API 호환 검증은 `ProjectManifest`가 담당한다.

코드 분석용 주석 작업은 첫 단계로 `main.lua`에만 적용했다. 동작을 바꾸지 않고 LÖVE 생명주기, 앱 위임 구조와 Lua의 local·nil·table·ipairs·require·다중 반환·xpcall·논리 연산·콜론 호출 문법을 설명한다.

루트 `README.md`는 채용 포트폴리오 랜딩 페이지로 재구성했다. Editor 스크린샷, Core·Editor·Project 구조와 제작 Workflow, 현재 동작 범위, 사용자와 AI Agent의 역할 구분, 알려진 한계를 앞에서부터 빠르게 확인할 수 있으며 세부 계약은 기존 `docs/` 문서로 연결한다.

Launcher는 `NativeFileSystem`, `STAGE_PATHS`, `vendor.dkjson`으로 StageRepository 인스턴스 하나를 만들고 Editor, Editor preview Project와 독립 Project에 주입한다. Editor의 `StageDocument`는 schemaVersion 3 편집 snapshot, dirty 상태와 mutation만 소유한다. Project는 `require("core")` 공개 API와 주입된 Repository를 사용하며 Editor Stage 내부 모듈, JSON codec이나 Stage 경로 계산을 직접 사용하지 않는다.

Project Event는 `categoryId + eventId` 조합으로 저장·조회·dispatch한다. Category ID는 Project 범위에서 고유하고 Event ID는 Category 범위에서 고유하므로 서로 다른 Category가 같은 Event ID를 사용할 수 있다. 정적 `ModuleBoundaryTest`가 Core·Editor·Launcher·Project의 금지 require를 실제 소스 트리에서 검사한다.

최종 리뷰 보완으로 `StageRepository:listStages`는 Stage 후보의 `isFile` 확인이 `(nil, error)`를 반환하면 기존 `READ_FAILED` 계약으로 오류를 전달한다. `StageDocument:addEvents`는 ID를 부여할 top-level Event 컨테이너를 항상 새로 만들어 JSON null/custom sentinel을 변이하지 않으며, 정규화된 반환 Event 구성을 끝낸 뒤에만 document와 dirty 상태를 commit한다. 모듈 경계 합성 테스트는 정렬한 7개 path→module 위반 문자열을 정확히 비교한다.

## 알려진 실패

현재 알려진 자동 테스트 실패는 없다.

## 최신 검증

- 2026-09-16 크레페 한 명 표시 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 표시 개수 기대 1, 실제 9로 신규 요구사항 실패 확인.
- GREEN: 같은 명령 → `PASS: 351 tests`. 두 화면 크기에서 단일 표시, 중앙 시작, 이동·화면 경계 순환, 프레임·턴·플립·되감기를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 실제 플레이 화면 육안 확인은 수행하지 않았다.
- `git diff --check` → 오류 없음.


- 2026-09-16 배경 이미지 복원: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → `PASS: 351 tests`. 이미지 로딩과 중앙 배치·화면 채움 배율을 검증했다. 실제 플레이 화면 육안 확인은 수행하지 않았다.

- 2026-09-16 스피키 idle RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 눌림 높이 테스트 1건 실패.
- GREEN: 같은 명령 → `PASS: 351 tests`. 두 화면 크기·양쪽 액터의 하단 고정, 매 박자 반복·복원, 동일 beat·되감기와 Tap/Long 제외·idle 복귀를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 성공. 임시 LÖVE 하네스에서 실제 스프라이트의 0·0.12·0.36·0.6박 렌더링을 비교해 하단 고정과 눌림·복원을 확인했다. 곡 재생 중 육안 확인은 수행하지 않았다. 하네스는 제거했다. `git diff --check` → 오류 없음.

- 2026-09-16 크레페 종이 플립 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 기존 즉시 반전으로 신규 플립 시작 scale 기대 1건 실패.
- GREEN: 같은 명령 → `PASS: 350 tests`. 양방향 전환의 시작·¼·중간·¾·완료 지점 가로 scale, 높이·중심·행 간격, 진행 중 프레임·연속 위치와 되감기를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 하네스에서 3~3.25박의 실제 5단계 렌더링으로 가로 축소·반대 방향 펼침을 확인했고 하네스는 제거했다. `git diff --check` → 오류 없음(기존 ROADMAP 줄바꿈 경고).

- 2026-09-16 크레페 두 박자·연속 이동 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 소수 beat 이동량(-1.5 기대, -1 실제)과 두 박자 프레임 순서 테스트 2건 실패.
- GREEN: 같은 명령 → `PASS: 350 tests`. 12프레임의 두 박자 재생·1/6박 경계·2박 반복, 소수 beat 이동·턴 경계 직전/직후 위치 연속성, 중간 재생·되감기를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 하네스의 2.75·3·3.25박 실제 렌더링으로 방향 전환 전후 배치를 확인했고 하네스는 제거했다. `git diff --check` → 오류 없음(기존 ROADMAP 줄바꿈 경고).

- 2026-09-16 크레페 12프레임 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 기존 이미지 경로 부재와 12프레임 기대 테스트로 14건 실패.
- GREEN: 같은 명령 → `PASS: 350 tests`. 0~11 숫자순 로딩, 각 프레임의 박자 내 재생, 1/12박 경계, 다음 박자의 0번 복귀, 중간 재생·되감기·방향 전환·기존 이동 및 반복 배치를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 하네스로 실제 12프레임의 행 렌더링을 확인했으며 하네스는 제거했다. `git diff --check` → 오류 없음(기존 ROADMAP CRLF→LF 경고).

- 2026-09-16 Fullscreen 설정 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 Schema·Tab 설정 테스트 2건 실패.
- GREEN: 같은 명령 → `PASS: 350 tests`. boolean 검증, false 희소 저장, true 저장·다시 열기, 정지 중 Tab 설정, 시작부터 확대, 정지 후 설정 유지, 재생 중 Tab, 속성 셀 클릭을 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .`, `git diff --check` → 성공. 실제 화면의 육안 조작 확인은 수행하지 않았다.

- 2026-09-16 Tab 확대 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 확대 상태·전환 부재로 신규 테스트 1건 실패.
- GREEN: 같은 명령 → `PASS: 348 tests`. 재생 상태·beat 유지, 키 반복 무시, Esc 복귀, 숨겨진 마우스 입력 차단, F 종료 후 복귀, 1600×900·1600×1000의 비율 유지와 draw 오류 복귀를 검증했다.
- `git diff --check` → 성공. 실제 창에서 Tab 전환의 육안 검증은 수행하지 않았다.

- 2026-09-16 크레페 전환 동기화 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 2.5박 Turn에서 프레임보다 먼저 반전되어 신규 기대 1건 실패.
- GREEN: 같은 명령 → `PASS: 346 tests`. 2·2.499·2.5·2.999박의 방향·프레임·위치 유지와 3박의 동시 전환, 동일 beat 반복 및 되감기를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .`, `git diff --check` → 성공. 실제 화면 육안 확인은 하지 않았으며 렌더링 인자 회귀 테스트로 동시 전환을 검증했다.

- 2026-09-16 크레페 반전 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 오른쪽 턴의 X scale 기대값 -0.4608, 실제 +0.4608로 1건 실패.
- GREEN: 같은 명령 → `PASS: 346 tests`. 오른쪽 턴의 음수 X scale, 왼쪽 턴의 원본 scale, 반 박자 Turn 경계, 중간 재생·되감기와 중심 원점 유지를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .`, `git diff --check` → 성공. 실제 플레이 화면의 육안 확인은 하지 않았으며 draw 인자의 좌우 반전과 기존 이동 회귀 테스트로 검증했다.

- 2026-09-16 크레페 턴 방향 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 회귀 테스트가 방향별 이동량 계산 부재로 1건 실패.
- GREEN: 같은 명령 → `PASS: 346 tests`. 실제 Runtime Turn 일정의 guide→player→guide 이동량, 반 박자 전환 시 위치 유지, 정수 박자 전환, beat 0 이전 Turn, 중간 재생·되감기·재시작·새 Stage 일정 초기화를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 앱 실행. 임시 LÖVE 하네스의 실제 이미지 렌더링으로 오른쪽 한 걸음 후 왼쪽 한 걸음을 확인했다. 실제 음악 청취는 하지 않았다. 임시 하네스는 제거했다. `git diff --check` → 성공.

- 2026-09-16 크레페 행 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 복수 크레페 draw와 행 렌더링 순서 기대가 기존 단일 draw로 2건 실패.
- GREEN: 같은 명령 → `PASS: 345 tests`. 1280×720·480×270의 양끝 표시, 일정 간격, 프레임 동기화, 큰 beat 점프·되감기와 화면 크기에 제한된 draw 개수 및 이미지 2개 공유를 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 하네스에서 beat 0·1의 실제 이미지 행을 렌더링해 배치와 양끝 순환을 확인했다. 하네스는 확인 후 제거했다. `git diff --check` → 성공.

- 2026-09-16 크레페 이동 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → beat 1의 X 기대값 576, 실제 640으로 이동 회귀 테스트 실패.
- GREEN: 같은 명령 → `PASS: 345 tests`. 박자별 이미지·위치, 경계 순환, 여러 바퀴를 건너뛴 중간 재생, 일시정지·되감기를 1280×720과 480×270에서 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 하네스에서 실제 이미지를 beat 0·1·11·14로 렌더링해 왼쪽 이동과 오른쪽 재등장 배치를 확인했다. 음악 청취 검증은 하지 않았다. 하네스는 확인 후 제거했다.
- `git diff --check` → 성공.

- 2026-09-16 미리보기 색상 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 실제 LÖVE Canvas 픽셀 테스트에서 흰색의 R 기대값 1이 0.4로 출력되어 신규 1건 실패.
- GREEN: 같은 명령 → `PASS: 345 tests`. 색상·알파가 지정된 UI 상태에서도 최종 픽셀 RGBA가 모두 1이고 호출 전 UI 색상이 복원되는 것을 검증했다.
- `& 'C:/Program Files/LOVE/love.exe' .`, `git diff --check` → 성공. 실제 에디터 육안 비교는 하지 않았으며 색상은 GPU Canvas 픽셀 읽기로 검증했다.

- 2026-09-16 크레페 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 테스트가 `CrepeActor` 부재로 1건 실패.
- GREEN: 같은 명령 → `PASS: 344 tests`. 정수 박자 경계, 동일 beat 유지, 중간 beat·되감기, 1280×720·480×270 배치와 이미지 재로딩 없음을 검증했다. 기존 렌더링 테스트는 추가된 크레페를 포함한 3개 draw 순서로 갱신했다.
- `& 'C:/Program Files/LOVE/love.exe' .` → 실행 명령 정상 종료. 임시 LÖVE 렌더링 하네스로 실제 액터를 1280×720 Canvas에 그려 상단 중앙 크레페와 하단 두 스피키가 겹치지 않는 것을 이미지로 확인했다. 실제 음악 청취 검증은 하지 않았다. 임시 하네스는 확인 후 제거했다.
- `git diff --check` → 성공.

- 2026-09-16 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 흰색 배경 회귀 테스트가 기존 `sprites` 이미지 접근으로 1건 실패.
- GREEN: 배경 이미지 로딩·렌더링 제거 후 `PASS: 343 tests`.
- `git diff --check` → 성공.
- `& 'C:/Program Files/LOVE/love.exe' .` → 앱 실행 명령 정상 종료. 자동 테스트에서 1280×720 전체 흰색 채움, 배경 이미지 draw 미호출, `ghost_basic.png` 미로딩을 검증했다.
- `python -m unittest discover -s tests_python -v` → sandbox의 기본 임시 폴더 쓰기 거부로 기존 `PermissionError` 5건 발생. 이번 Lua 변경과 무관하다.

- 2026-09-13 턴 위치 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 회귀 1건 실패(왼쪽 경계 기대 -12, 실제 약 -379.06).
- GREEN: 같은 명령 → `PASS: 342 tests`. 1280×720 및 480×270에서 좌우 대기 위치와 화면 안 복귀를 확인했다.
- `Get-Content -Raw -Encoding utf8 projects/rhythm_dotgeo/config/speaki_song.json | ConvertFrom-Json | Out-Null`, `git diff --check` → 성공.
- `& 'C:/Program Files/LOVE/love.exe' .` 실행 및 실제 Editor Play 화면에서 우측 캐릭터 대부분이 보이고 끝만 걸친 것을 확인했다. 다음 화면 확인은 사용자가 물리 Escape로 Computer Use를 중단했다.

- 오류 복사 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 신규 테스트가 Copy 버튼 부재로 1건 실패.
- 오류 복사 GREEN: 같은 명령 → `PASS: 341 tests`. 버튼 클릭, 좌·우 Ctrl+C, 한글·줄바꿈·긴 메시지 전문, 복사 후 모달 유지, Enter·Esc 닫기와 다른 모달에 영향 없음을 검증했다.
- 오류 복사 `git diff --check` → 출력 없음.
- `& 'C:/Program Files/LOVE/love.exe' .` 실행 후 에디터 화면을 확인했다. 사용자가 물리 Escape로 Computer Use를 중단해 오류창 버튼의 실제 클릭·시각 확인은 완료하지 못했다.

- 2026-09-12 RED: `& 'C:/Program Files/LOVE/lovec.exe' . --test` → 한글 sourceRoot의 실제 Stage 확인에서 사진과 같은 `Invalid argument` 재현. 신규 NativeFileSystem 회귀 테스트와 기존 실제 Speaki Song 열기 테스트 총 2건 실패.
- 2026-09-12 GREEN: 같은 명령 → `PASS: 340 tests`. 실제 Stage 읽기, 한글 파일명·공백·NUL 포함 다중 청크 데이터의 저장·복사·이름 변경·빈 파일 덮어쓰기·삭제를 검증했다.
- `Get-Content -Raw -Encoding utf8 projects/rhythm_dotgeo/stages/speaki_song.json | ConvertFrom-Json | Out-Null` → 성공.
- `git diff --check` → 출력 없음. 화면 레이아웃 변경은 없으며, 에디터의 실제 클릭 조작은 이번 검증에 포함하지 않았다.

- 포트폴리오 README에서 제품 상태와 설계 효과를 분리하고 최신 테스트 결과를 반영한 뒤 목차·링크·사실 표현 검사 → 성공.
- RED: `C:\Program Files\LOVE\lovec.exe . --test` → Metronome fixture가 이전 amplitude `0.35`를 가정해 6건 실패 재현.
- GREEN: fixture amplitude를 제품 정책 `1.0`에 맞춘 뒤 `C:\Program Files\LOVE\lovec.exe . --test` → `PASS: 339 tests`.
- `python -m unittest discover -s tests_python -v` → `Ran 5 tests`, `OK`.
- `git diff --check` → 출력 없음.
- 코드 분석용 `main.lua` 주석 추가 후 `C:\Program Files\LOVE\lovec.exe . --test` → 신규 실패 없이 기존 Metronome 6건만 실패.
- `git diff --check` → 출력 없음.
- TDD RED 1: `isFile`이 `(nil, "stat denied")`를 반환하는 목록 테스트를 추가하자 `love . --test`가 기존 6건 외 신규 1건을 `expected: nil`, `actual: table`로 실패했다.
- TDD GREEN 1: `listStages`가 해당 오류를 `READ_FAILED`로 전달하도록 수정한 뒤 신규 실패가 사라지고 기존 Metronome 6건만 남았다.
- TDD RED 2: `addEvents({ json.null })` 회귀 테스트를 추가하자 sentinel ID가 `nil` 대신 `event-001`로 변이되어 기존 6건 외 신규 1건이 실패했다. 실패 뒤 테스트가 sentinel을 원복해 전역 fixture 오염은 남기지 않았다.
- TDD GREEN 2 및 refactor: top-level Event 컨테이너 복제 뒤 sentinel·document·dirty 원자성 테스트가 통과했고, 반환 Event lookup을 commit 앞으로 옮긴 뒤에도 기존 Metronome 6건만 남았다.
- `tests/ModuleBoundaryTest.lua`의 종합 합성 사례는 정렬한 7개 exact path→module 위반 문자열을 모두 비교하며 실제 source tree의 위반 0건 검사도 유지한다.
- `python -m unittest tests_python.test_create_project` → sandbox에서는 워크트리 내부 전용 TEMP도 하위 디렉터리 생성을 거부해 `PermissionError` 5건이 발생했다. 정상 TEMP 권한으로 재실행해 `Ran 5 tests`, `OK`를 확인했다.
- `Get-Content -Raw -Encoding utf8 projects/sample/stages/test.json | ConvertFrom-Json | Out-Null` → 성공.
- `Get-Content -Raw -Encoding utf8 projects/rhythm_dotgeo/stages/speaki_song.json | ConvertFrom-Json | Out-Null` → 성공.
- `C:\Program Files\LOVE\lovec.exe . --test` → 이번 StageRepository·StageDocument·모듈 경계 신규 실패 0, 기존 Metronome 6건만 실패.
- 브리프의 exact stale 검색은 의도된 12줄만 출력했다. 정밀 검색은 현재 human docs와 production source에서 stale 소유권·schema 표현 각각 0건이었다.
- `git diff --check` → 출력 없음. `git diff 68fd12a -- editor/playback/MetronomePlayback.lua tests/MetronomePlaybackTest.lua`와 `.references` diff도 출력 없음.

## 다음 작업

크레페 한 명 표시 변경은 완료했다. 앱 재시작 후 스피키송에서 중앙의 한 명으로 시작하는 것을 확인할 수 있다.


스피키 idle 눌림 구현은 완료했다. 강도와 누름·복원 시간은 `SpeakiActor.lua`의 `IDLE_SQUASH`, `IDLE_PRESS_BEATS`, `IDLE_RECOVER_BEATS`에서 조정한다.

크레페 종이 플립 구현은 완료했다. 현재 전환 길이는 0.25박이다.

크레페 두 박자 애니메이션과 연속 이동 구현은 완료했다. 애니메이션 주기는 `ANIMATION_BEATS`, 이동 속도는 `STEP_WIDTH_RATIO`로 조정한다.

크레페 12프레임의 한 박자 반복 구현은 완료했다. 기존 정수 박자 이동 및 턴 방향 전환은 유지한다.

녹화 백엔드와 배포 의존성을 정한 뒤 Record 속성, Play/Pause·Stage 종료 연동과 영상·소리 저장을 구현한다. Tab 확대는 구현·자동 테스트 완료이며 실제 플레이 화면에서 수동 전환을 확인한다.

크레페 방향·프레임·이동의 정수 박자 동기화 수정에 남은 코드 작업은 없다.

크레페 이동 방향별 좌우 반전의 남은 코드 작업은 없다.

크레페 턴 방향 연동의 남은 코드 작업은 없다. 기존 Runtime의 Turn 일정을 `CrepeActor`에 전달하므로 Stage의 큐·응답 배치를 바꾸면 이동 방향 일정도 함께 바뀐다.

미리보기 색상 보정의 남은 코드 작업은 없다. 앱 재시작 후 Editor Play에서 순백색 배경을 확인할 수 있다.

크레페 애니메이션 구현의 남은 작업은 없다. 실제 곡 재생 중 크기·위치의 취향에 따른 추가 조정은 `game/SpeakiSong/CrepeActor.lua`에서 한다.

스피키송 배경 이미지 복원에는 후속 코드 작업이 없다. 실행 중인 앱은 재시작하면 복원된 배경을 확인할 수 있다.

대기 위치의 잘림 정도를 추가 조정하려면 `config/speaki_song.json`의 `actorLayout.outsidePadding`을 조정한다. 현재 기본값은 12px이다.

오류 모달에서 `Copy (Ctrl+C)`와 복사 후 `Copied` 표시를 실제 화면에서 확인한다. 자동 회귀 테스트는 통과했다.

실행 중이던 LÖVE 앱을 재시작한 뒤 Editor에서 Rhythm Dotgeo / Speaki Song Stage Open을 다시 확인한다.

코드 분석용 주석의 다음 순서는 `launcher/Launcher.lua`, `launcher/ProjectLoader.lua`의 Launcher와 Project 로딩 흐름이다. 사용자가 현재 `main.lua`를 읽고 이해한 뒤 다음 단계로 진행한다.

기능 개발은 Phase 2에서 Editor와 Project가 각각 조립하는 `StageRuntime`을 단일 실행 권위로 통합한다. Phase 3의 동적 Launcher Project 메뉴와 EditorApp/EditorSession 책임 분리, Project별 packaging은 아직 현재 구현이 아니다.
