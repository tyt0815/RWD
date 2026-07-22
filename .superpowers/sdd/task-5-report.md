# Task 5 보고서: Core PlaybackTransport

## RED 증거

- `& 'C:\Program Files\LOVE\lovec.exe' . --test`
- `PlaybackTransport` export가 없어 9개 transport 테스트가 `attempt to index field 'PlaybackTransport' (a nil value)`로 실패했다.
- self-review 중 추가한 음수 Offset 시작 틱 보정 테스트는 기존 구현에서 `expected: nil`, `actual: 1`로 실패했다.
- 독립 검토 후 추가한 재생 중 BPM 변경 동기화 테스트는 기존 구현에서 `expected: 2`, `actual: 1`로 실패했다.

## GREEN 증거

- `& 'C:\Program Files\LOVE\lovec.exe' . --test` → `PASS: 126 tests` (exit code 0)
- `git diff --check` → 출력 없음

## 구현

- `PlaybackTransport`가 TempoMap, 논리 timeline seconds, beat, rate, 재생 상태와 음악 시작 상태를 단일 소유한다.
- 양수/음수 Beat 0 Offset, Pause/재개, BPM 변경, 0.25~4 rate, prepare/play/update 오류 시 pause와 위치 보존을 처리한다.
- 음수 Offset을 통과해 막 음악을 시작한 update 틱에는 drift 보정을 호출하지 않는다.
- 재생 중 BPM 변경은 즉시 새 논리 음악 위치를 seek/play로 동기화하며, 음수 음악 위치에서는 Source를 pause한다.

## 변경 파일

- `core/PlaybackTransport.lua`
- `core/init.lua`
- `tests/PlaybackTransportTest.lua`
- `tests/TestRunner.lua`

## Self-review

- 요구 API와 기존 `PlaybackClock` export 공존을 확인했다.
- 외부 오디오만 주입 더블로 격리하고, transport의 상태와 계산 결과를 검증했다.
- 독립 검토에서 지적된 재생 중 BPM 변경의 음악 동기화 결함을 RED/GREEN으로 보정했다.
- 현재 범위의 우려사항 없음.
