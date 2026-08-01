# 인수인계

## 현재 구현 상태

Core Stage 소유권 구조 개편 Phase 1이 완료되었다. `require("core")`는 API version 2와 함께 `StageSchema`, `StageRepository`, `ProjectManifest`를 공개한다. Stage 형식·정규화는 `StageSchema`, 경로·JSON decode/encode·원자 저장은 `StageRepository`, Project 매니페스트 구조와 Core API 호환 검증은 `ProjectManifest`가 담당한다.

Launcher는 `NativeFileSystem`, `STAGE_PATHS`, `vendor.dkjson`으로 StageRepository 인스턴스 하나를 만들고 Editor, Editor preview Project와 독립 Project에 주입한다. Editor의 `StageDocument`는 schemaVersion 3 편집 snapshot, dirty 상태와 mutation만 소유한다. Project는 `require("core")` 공개 API와 주입된 Repository를 사용하며 Editor Stage 내부 모듈, JSON codec이나 Stage 경로 계산을 직접 사용하지 않는다.

Project Event는 `categoryId + eventId` 조합으로 저장·조회·dispatch한다. Category ID는 Project 범위에서 고유하고 Event ID는 Category 범위에서 고유하므로 서로 다른 Category가 같은 Event ID를 사용할 수 있다. 정적 `ModuleBoundaryTest`가 Core·Editor·Launcher·Project의 금지 require를 실제 소스 트리에서 검사한다.

## 알려진 실패

전체 LÖVE suite의 기존 Metronome 6건은 구현의 amplitude·강박 선택과 `tests/MetronomePlaybackTest.lua` 기대값 불일치로 계속 실패하며 이번 Stage 소유권 작업 범위 밖이다.

## 최신 검증

- TDD RED: 합성 Project→Editor Stage 내부 의존 위반 테스트를 등록한 뒤 `love . --test`에서 기존 6건 외 신규 1건이 `expected: 1`, `actual: 0`으로 실패했다.
- TDD GREEN: scanner 최소 구현 뒤 신규 경계 실패가 사라지고 기존 Metronome 6건만 남았다. 모든 경계와 두 quote 형식 합성 테스트도 `expected: 7`, `actual: 0` RED 후 구현했으며 실제 source tree 검사까지 통과한다.
- `python -m unittest tests_python.test_create_project` → sandbox 안에서는 시스템 TEMP 쓰기 거부로 `PermissionError` 5건이 발생했다. 같은 명령을 정상 TEMP 권한으로 다시 실행해 `Ran 5 tests`, `OK`를 확인했다.
- `Get-Content -Raw projects/sample/stages/test.json | ConvertFrom-Json | Out-Null` → 성공.
- `Get-Content -Raw projects/rhythm_dotgeo/stages/speaki_song.json | ConvertFrom-Json | Out-Null` → 성공.
- `love . --test` → Stage 소유권·모듈 경계 관련 신규 실패 0, 기존 Metronome 6건만 실패.
- 브리프의 exact stale 검색은 12개 false positive를 출력한다. 합성 위반 fixture 2줄, v2 거부 동작을 검증하는 negative fixture 3줄, params 검증 API를 더 짧은 이전 API 이름으로 접두사 매치한 7줄이다. 현재 human docs와 production source를 대상으로 의미를 보존한 정밀 검색은 stale 소유권·schema 표현 0건이다.
- `git diff --check` → 출력 없음.
- GUI smoke 첫 시도는 PowerShell 함수인 `love`를 `Start-Process` 실행 파일로 찾지 못해 실패했다. 실제 경로 `C:\Program Files\LOVE\lovec.exe .`를 숨김 실행한 재시도는 3초 뒤 `HasExited=False`, `Responding=True`였고 확인 후 시작한 프로세스만 종료했다.
- 이 도구 환경은 네이티브 창에 키·마우스 입력을 보내고 화면 결과를 객관적으로 판정할 수 없어 Editor 열기, Sample Stage Open, Event 배치·drag·Property·Undo/Redo·clipboard, Save As overwrite Dialog, Play/Pause preview, Rhythm Dotgeo Stage 선택을 사람이 직접 확인하지 못했다. 대응 자동 테스트는 Property/Event 순서, Stage Open, 배치·drag, clipboard·Undo/Redo, Save As 충돌 overwrite, Play/Pause, Launcher Repository 동일성, `2` 키 진입과 Rhythm Stage 목록·클릭 실행을 포함하며 이번 suite에서 신규 실패가 없다.

## 다음 작업

Phase 2에서 Editor와 Project가 각각 조립하는 `StageRuntime`을 단일 실행 권위로 통합한다. Phase 3의 동적 Launcher Project 메뉴와 EditorApp/EditorSession 책임 분리, Project별 packaging은 아직 현재 구현이 아니다.
