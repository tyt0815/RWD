# Metronome Period 강박 주기 수정 설계

## 1. 목표

`Metronome Period`의 의미를 한 BPM beat 안에서 재생하는 subdivision 수가 아니라, BPM 박자 클릭 중 강박이 반복되는 주기로 수정한다.

- 메트로놈은 BPM 한 박마다 정확히 한 번 클릭한다.
- beat 0은 항상 강박이다.
- 이후 `metronomePeriod` beat마다 강박을 반복한다.
- 강박 사이의 클릭은 일반박이다.

예시는 다음과 같다.

| Period | 반복 패턴 |
|---|---|
| `1` | 강, 강, 강, 강, ... |
| `4` | 강, 일, 일, 일, 강, 일, 일, 일, ... |
| `5` | 강, 일, 일, 일, 일, 강, 일, 일, 일, 일, ... |

## 2. 설정과 호환성

- UI 이름 `Metronome Period`와 JSON 키 `editorSettings.metronomePeriod`를 유지한다.
- 기본값은 `4`, 유효 범위는 정수 `1~32`를 유지한다.
- `schemaVersion`은 `2`를 유지한다.
- 이번 변경은 배포 전 잘못 구현된 설정 의미를 바로잡는 버그 수정으로 취급한다.
- Stage JSON의 저장 구조와 희소 기본값 규칙은 바뀌지 않는다.

문서에서는 `Metronome Period`를 "강박이 반복되는 BPM 박자 수"로 정의한다. 더 이상 "한 beat 안의 subdivision 수"라는 표현을 사용하지 않는다.

## 3. 오디오 생성

기존 `MetronomePlayback`의 정적 `SoundData`와 looping Source 구조를 유지한다. 한 BPM beat가 아니라 Period 전체를 하나의 루프로 만든다.

```text
beatDuration = 60 / bpm
loopDuration = beatDuration * period
clickTime(beatIndex) = beatDuration * beatIndex
```

`beatIndex`는 `0`부터 `period - 1`까지 순회한다.

- `beatIndex == 0`: 1760Hz 강박
- 나머지 beat: 880Hz 일반박
- 각 클릭의 길이, 감쇠 envelope와 진폭은 기존 값을 유지한다.
- SoundData sample index는 전체 루프 sample 범위를 넘지 않도록 제한한다.

따라서 Period 값은 클릭 간격을 바꾸지 않는다. 클릭 간격은 항상 `60 / bpm`초다.

## 4. 재생, 재개와 Playback Rate

Play와 Pause API는 변경하지 않는다. 현재 beat에서 루프 내 위치는 다음과 같이 계산한다.

```text
loopBeat = beat % period
seekSeconds = loopBeat * (60 / bpm)
```

- beat 0에서 시작하면 첫 강박을 즉시 재생한다.
- Period 4에서 beat 4, 8, 12는 다시 강박 위치다.
- Period 4에서 beat 2.5에 재개하면 beat 2 일반박 이후 절반 위치에서 재개하며, 다음 클릭은 beat 3의 일반박이다.
- Playback Rate는 기존처럼 Source pitch에 적용한다. Transport, 음악, TestPlayer와 메트로놈의 상대 동기화 규칙은 바뀌지 않는다.

## 5. 구성 요소 변경 범위

### `editor/playback/MetronomePlayback.lua`

- SoundData 길이를 `period` beat로 확장한다.
- 각 BPM beat 시작점에 클릭을 하나씩 배치한다.
- 첫 beat만 강박 주파수를 사용한다.
- 재개 seek를 Period modulo 기준으로 계산한다.

### 테스트

- Period 1은 BPM beat마다 강박을 재생한다.
- Period 4는 `강-일-일-일`과 정확한 4-beat loop 길이를 만든다.
- Period 5는 `강-일-일-일-일`을 만든다.
- Period 4의 beat 0과 beat 4가 같은 강박 위치로 seek된다.
- Period 4의 fractional beat 재개 위치가 modulo 계산과 일치한다.
- Playback Rate pitch, pause, stop과 Source 오류 정리는 기존 동작을 유지한다.
- EditorSession은 Stage의 `metronomePeriod`를 변경 없이 MetronomePlayback에 전달한다.

### 문서

다음 문서의 subdivision 설명을 강박 주기 설명으로 교체한다.

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/STAGE_FORMAT.md`
- `docs/WORKFLOW.md`
- `docs/ROADMAP.md`
- `docs/HANDOFF.md`

기존 대형 구현 계획과 설계 문서는 당시 결정 기록이므로 수정하지 않는다. 새 설계 문서가 메트로놈 Period 의미에 한해 이전 기록을 대체한다.

## 6. 오류 처리

- BPM, Period와 Playback Rate 검증 범위는 기존 설정과 MetronomePlayback 계약을 유지한다.
- SoundData 또는 Source 생성 실패는 기존처럼 오류 값으로 반환한다.
- Source 메서드 실패 시 생성된 Source를 정리하고 EditorSession의 기존 rollback 경로를 사용한다.
- 오류 처리 때문에 Core, Project 또는 Stage JSON에 새 필드를 추가하지 않는다.

## 7. 완료 기준

- BPM 120, Period 1과 Period 4의 클릭 간격은 모두 0.5초다.
- Period 4의 강박은 beat 0, 4, 8, 12에서 난다.
- Period 5의 강박은 beat 0, 5, 10, 15에서 난다.
- 중간 beat에서 재개해도 절대 beat 기준 강박 순서가 유지된다.
- 기본값 4와 schemaVersion 2의 희소 저장 형식이 유지된다.
- 전체 자동 테스트와 LÖVE 기동 smoke가 통과한다.
- 사람이 Period 4에서 `강-일-일-일` 반복을 청취하는 검증은 별도 수동 확인 항목으로 기록한다.
