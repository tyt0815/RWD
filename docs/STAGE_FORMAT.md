# Stage JSON 형식

## 버전 1 예시

```json
{
  "schemaVersion": 1,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "tempoMap": [
    {
      "startBeat": 0,
      "bpm": 120
    }
  ],
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

- `schemaVersion`: 형식 버전. 현재 지원 값은 정수 `1`이다.
- `projectId`: Stage를 해석할 프로젝트 ID다.
- `stageId`: 프로젝트 안에서 고유한 Stage ID다.
- `name`: 표시 이름이다.
- `tempoMap`: BPM 항목 배열이다. 현재는 `startBeat: 0`인 항목 하나만 허용한다.
- `events`: 타임라인 배치 항목 배열이다.

## Event 공통 필드

- `id`: Stage 안에서 고유한 문자열이다.
- `type`: `pattern`, `tapNote`, `longNote` 중 하나다.
- `startBeat`: 0 이상의 박자 위치다.

`pattern`은 프로젝트 코드에 등록된 `patternId`와 JSON 객체인 `params`를 사용한다. `params`를 생략하면 빈 객체로 취급한다. `longNote`는 0보다 큰 `durationBeats`를 사용한다.

## 변경 규칙

향후 버전 1 Stage 로더는 템포 항목을 하나만 처리해야 한다. BPM 변경을 구현할 때 `tempoMap`에 추가 항목을 허용한다. 기존 필드 의미를 깨는 변경은 `schemaVersion`을 증가시키고 이전 버전 변환 정책을 함께 문서화한다.

## 로드 오류 원칙

다음 항목은 향후 Stage 로더가 따라야 할 오류 처리 계약이다.

- 지원하지 않는 `schemaVersion`은 Stage를 적용하지 않고 거부해야 한다.
- 존재하지 않는 `patternId`는 해당 Event `id`와 함께 보고하고 테스트 플레이를 차단해야 한다.
- 잘못된 필드 값은 가능한 경우 JSON 경로를 오류에 포함해야 한다.
- 로드가 실패하면 현재 편집 중인 Stage 상태를 변경하지 않아야 한다.
