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

현재 버전 1 로더는 `tempoMap` 항목을 정확히 하나만 허용한다. BPM 변경을 구현할 때 새 `schemaVersion` 또는 명시적인 호환 정책과 함께 추가 항목 허용 여부를 정한다. 기존 필드 의미를 깨는 변경은 `schemaVersion`을 증가시키고 이전 버전 변환 정책을 함께 문서화한다.

## 파일 경계와 현재 검증

Stage 파일 이름은 `<stageId>.json`이며 실제 경로는 `projects/<projectId>/stages/<stageId>.json`이다. `projectId`와 `stageId`는 소문자 영숫자로 시작하고 이후 소문자 영숫자, `_`, `-`만 사용하는 안전한 ID여야 하며 Windows 예약 이름은 사용할 수 없다.

버전 1 로더는 현재 다음을 검증한다.

- `schemaVersion`이 정수 `1`이고 Project·Stage ID와 Name이 유효하다.
- `tempoMap`이 `startBeat: 0`과 0보다 큰 유한 BPM을 가진 단일 항목이다.
- `events`가 배열이고 각 Event ID가 비어 있지 않으며 Stage 안에서 고유하다.
- 모든 Event의 `startBeat`가 0 이상의 유한 수이고 type별 필수 필드가 유효하다.
- `pattern`의 `patternId`와 선택적 객체 `params`, `longNote`의 양수 `durationBeats`가 유효하다.
- JSON의 `projectId`가 선택한 Project와 같고 `stageId`가 파일 이름과 같다.

Project Event 등록 계약이 아직 없으므로 로더는 `patternId`가 실제로 등록되어 있는지는 확인하지 않는다.

## 로드 오류 원칙

현재 Stage 로더는 다음 오류 처리 계약을 따른다.

- 지원하지 않는 `schemaVersion`과 잘못된 필드는 JSON 경로를 포함한 오류로 거부한다.
- Project·파일 ID가 JSON과 일치하지 않으면 로드를 거부한다.
- 로드가 실패하면 현재 편집 중인 Stage와 재생 상태를 변경하지 않는다.

존재하지 않는 `patternId`를 Event ID와 함께 보고하고 테스트 플레이를 차단하는 처리는 Project Event 등록 계약과 함께 추가할 후속 범위다.
