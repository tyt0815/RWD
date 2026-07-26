# Stage JSON 형식

## schemaVersion 2 최소 예시

```json
{
  "schemaVersion": 2,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "bpm": 120,
  "events": []
}
```

Mixtape와 Editor 설정이 모두 기본값이면 `mixtape`와 `editorSettings` 객체 자체를 저장하지 않는다.

## 확장 예시

```json
{
  "schemaVersion": 2,
  "projectId": "sample",
  "stageId": "tutorial-remix",
  "name": "Tutorial Remix",
  "bpm": 128,
  "mixtape": {
    "music": "assets/audio/tutorial.ogg",
    "volume": 0.8,
    "beat0Offset": -0.5
  },
  "editorSettings": {
    "metronome": true,
    "metronomePeriod": 3,
    "snap": 4,
    "onsetThreshold": 0.02,
    "scale": 2,
    "playbackRate": 0.5
  },
  "events": [
    {
      "id": "event-001",
      "type": "pattern",
      "patternId": "fourTapResponse",
      "startBeat": 8,
      "params": {}
    },
    {
      "id": "event-002",
      "type": "tapNote",
      "startBeat": 24
    },
    {
      "id": "event-003",
      "type": "longNote",
      "startBeat": 28,
      "durationBeats": 2
    }
  ]
}
```

## 상위 필드

- `schemaVersion`: 정수 `2`만 지원한다.
- `projectId`: Stage를 해석할 Project의 안전한 ID다.
- `stageId`: Project 안에서 고유한 안전한 ID다.
- `name`: 비어 있지 않은 표시 이름이다.
- `bpm`: 0보다 큰 유한 수다.
- `mixtape`: 선택적 공통 음악 설정 객체다.
- `editorSettings`: 선택적 Editor 디버깅 설정 객체다. 실제 게임 규칙에는 전달하지 않는다.
- `events`: 타임라인 배치 항목 배열이다.

## Mixtape 설정

| 필드 | 기본값 | 검증 |
| --- | ---: | --- |
| `music` | 없음 | `assets/audio/` 아래 Project 상대 `.ogg`, `.mp3`, `.wav` 경로 |
| `volume` | `1.0` | `0.0~1.0` 유한 수 |
| `beat0Offset` | `0.0` | 유한 seconds 값 |

`beat0Offset`은 논리 beat 0에 대응하는 음악 위치다. 음수이면 Transport가 해당 시간이 0에 도달할 때까지 음악을 시작하지 않고, 양수이면 그 음악 위치에서 시작한다.

## Editor 설정

| 필드 | 기본값 | 검증 |
| --- | ---: | --- |
| `metronome` | `false` | boolean |
| `metronomePeriod` | `4` | 강박 반복 BPM 박자 수, `1~32` 정수 |
| `snap` | `1` | Timeline 편집 박자 간격, `1~32` 정수 |
| `onsetThreshold` | `0.01` | Music onset 검출 RMS 기준, `0.0~1.0` 유한 수 |
| `scale` | `1.0` | `0.25~8.0` 유한 수 |
| `playbackRate` | `1.0` | `0.25~4.0` 유한 수 |

`metronomePeriod`는 강박을 반복하는 BPM 박자 수다. 값 4는 beat 0, 4, 8, 12에서 강박이 울리고 BPM 클릭 간격 자체는 바뀌지 않는다.

`snap`은 Timeline에서 재생 바와 향후 Event 노드를 배치할 공통 박자 간격이다. 값 1은 한 박, 값 4는 4박 단위의 가장 가까운 위치에 맞춘다.

`onsetThreshold`는 Beat 0 Offset Auto 분석에서 10ms RMS가 이 값보다 큰 연속 구간을 소리로 판정한다. 기본값 `0.01`은 작은 압축 노이즈를 제외하는 일반 권장값이며, `0`을 명시하면 완전한 무음만 제외한다.

기본값과 같은 선택 필드는 저장할 때 제거한다. 그 결과 비어 있는 `mixtape` 또는 `editorSettings`도 제거된다. 예를 들어 wheel zoom으로 Scale만 `1.25`가 되면 `editorSettings`에는 `scale` 하나만 남는다. 이 기본값은 schemaVersion 2 계약이므로 의미를 바꾸려면 새 schemaVersion과 변환 정책이 필요하다.

`mixtape`와 `editorSettings` 안의 정의되지 않은 필드는 거부한다.

## Event 필드

모든 Event는 Stage 안에서 고유한 비어 있지 않은 `id`, `type`, 0 이상의 유한 `startBeat`를 사용한다.

- `pattern`: 비어 있지 않은 `patternId`와 선택적 JSON 객체 `params`를 사용한다. `params`를 생략하면 빈 객체로 취급하며 내부 JSON null은 저장 왕복에서 보존한다. `params` 자체의 null이나 배열은 허용하지 않는다.
- `tapNote`: 공통 필드만 사용한다.
- `longNote`: 0보다 큰 유한 `durationBeats`를 추가한다.

Project Event 등록 계약이 아직 없으므로 로더는 `patternId`가 실제로 등록되었는지는 확인하지 않는다.

## 파일 경계와 검증

Stage 파일 이름은 `<stageId>.json`이며 경로는 `projects/<projectId>/stages/<stageId>.json`이다. ID는 소문자 영숫자로 시작하고 이후 소문자 영숫자, `_`, `-`만 사용할 수 있으며 Windows 예약 이름은 거부한다.

로더는 다음을 검증한다.

- schemaVersion, Project·Stage ID, Name, BPM과 Event 구조
- JSON 객체와 배열 종류
- Mixtape·Editor 설정의 종류, 범위와 허용 필드
- Event ID 중복, type별 필수 필드와 수치 범위
- JSON의 `projectId`와 선택 Project, `stageId`와 파일 이름의 일치

지원하지 않는 schemaVersion과 잘못된 필드는 가능한 JSON 경로를 포함한 오류로 거부한다. 로드 실패는 현재 편집 중인 Stage와 재생 상태를 바꾸지 않는다.

## 버전 호환 정책

현재 로더는 버전 1 Stage를 자동 변환하지 않고 거부한다. 기존 파일은 schemaVersion 2의 최상위 `bpm`, 선택적 희소 설정과 `events` 구조로 명시적으로 변환해야 한다. 이후 호환되지 않는 필드 의미 변경도 schemaVersion을 증가시키고 별도 변환 정책과 함께 도입한다.
