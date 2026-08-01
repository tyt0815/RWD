# 인수인계

## 현재 구현 상태

Core Stage 소유권 구조 개편 Phase 1이 완료되었다. `require("core")`는 API version 2와 함께 `StageSchema`, `StageRepository`, `ProjectManifest`를 공개한다. Stage 형식·정규화는 `StageSchema`, 경로·JSON decode/encode·원자 저장은 `StageRepository`, Project 매니페스트 구조와 Core API 호환 검증은 `ProjectManifest`가 담당한다.

Launcher는 `NativeFileSystem`, `STAGE_PATHS`, `vendor.dkjson`으로 StageRepository 인스턴스 하나를 만들고 Editor, Editor preview Project와 독립 Project에 주입한다. Editor의 `StageDocument`는 schemaVersion 3 편집 snapshot, dirty 상태와 mutation만 소유한다. Project는 `require("core")` 공개 API와 주입된 Repository를 사용하며 Editor Stage 내부 모듈, JSON codec이나 Stage 경로 계산을 직접 사용하지 않는다.

Project Event는 `categoryId + eventId` 조합으로 저장·조회·dispatch한다. Category ID는 Project 범위에서 고유하고 Event ID는 Category 범위에서 고유하므로 서로 다른 Category가 같은 Event ID를 사용할 수 있다. 정적 `ModuleBoundaryTest`가 Core·Editor·Launcher·Project의 금지 require를 실제 소스 트리에서 검사한다.

최종 리뷰 보완으로 `StageRepository:listStages`는 Stage 후보의 `isFile` 확인이 `(nil, error)`를 반환하면 기존 `READ_FAILED` 계약으로 오류를 전달한다. `StageDocument:addEvents`는 ID를 부여할 top-level Event 컨테이너를 항상 새로 만들어 JSON null/custom sentinel을 변이하지 않으며, 정규화된 반환 Event 구성을 끝낸 뒤에만 document와 dirty 상태를 commit한다. 모듈 경계 합성 테스트는 정렬한 7개 path→module 위반 문자열을 정확히 비교한다.

## 알려진 실패

전체 LÖVE suite의 기존 Metronome 6건은 구현의 amplitude·강박 선택과 `tests/MetronomePlaybackTest.lua` 기대값 불일치로 계속 실패하며 이번 Stage 소유권 작업 범위 밖이다.

## 최신 검증

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

Phase 2에서 Editor와 Project가 각각 조립하는 `StageRuntime`을 단일 실행 권위로 통합한다. Phase 3의 동적 Launcher Project 메뉴와 EditorApp/EditorSession 책임 분리, Project별 packaging은 아직 현재 구현이 아니다.
