# Mixtape와 Editor 재생 속성 확장 설계

## 1. 목표

Stage의 배경 음악과 박자 기준을 공통 Core 재생 시스템으로 실행하고, 에디터 Test Play에만 적용되는 디버깅 설정을 추가한다.

- `Mixtape Properties`: Music, Volume, Beat 0 Offset, BPM
- `Editor Properties`: Scale, Playback Rate, Metronome, Metronome Period
- 프로젝트 내부 음악 선택과 Test Play 재생
- 음수를 포함한 Beat 0 Offset
- 타임라인 휠 확대·축소
- 강박과 일반박이 구분되는 에디터 내장 메트로놈
- Stage JSON schemaVersion 2와 희소 기본값 저장

이번 범위에는 BPM Change 타임라인 노드, 음높이를 유지하는 타임 스트레칭, 실제 리듬 판정, 오디오 파형 표시와 독립 패키징을 포함하지 않는다.

## 2. 핵심 결정

- Core의 단일 `PlaybackTransport`가 논리 재생 시간, beat와 음악을 동기화한다.
- 실제 게임과 Editor Test Play는 같은 Core 음악·Offset·Volume 규칙을 사용한다.
- Playback Rate, Metronome과 Scale은 Editor 전용이다. 실제 게임은 Playback Rate `1.0`, 메트로놈 없음으로 실행한다.
- Stage JSON에는 기본 BPM 하나를 최상위 `bpm`으로 저장한다.
- 향후 BPM 변경은 `tempoMap` 필드가 아니라 `events` 안의 BPM Change 노드로 저장한다.
- `mixtape`와 `editorSettings`는 기본값과 다른 필드만 기록하는 희소 객체다.
- schemaVersion 1은 호환하지 않는다. 저장소의 Stage와 테스트 fixture를 버전 2로 일괄 변경한다.

## 3. Stage JSON 버전 2

### 3.1 최소 형식

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

### 3.2 설정을 포함한 형식

```json
{
  "schemaVersion": 2,
  "projectId": "sample",
  "stageId": "tutorial",
  "name": "Tutorial",
  "bpm": 120,
  "mixtape": {
    "music": "assets/audio/song.ogg",
    "volume": 0.8,
    "beat0Offset": -0.5
  },
  "editorSettings": {
    "metronome": true,
    "scale": 2.0,
    "playbackRate": 0.5
  },
  "events": []
}
```

### 3.3 기본값과 희소 저장

누락된 필드는 다음 값으로 해석한다.

| 필드 | 기본값 |
| --- | --- |
| `mixtape.music` | 음악 없음 |
| `mixtape.volume` | `1.0` |
| `mixtape.beat0Offset` | `0.0` |
| `editorSettings.metronome` | `false` |
| `editorSettings.metronomePeriod` | `4` |
| `editorSettings.scale` | `1.0` |
| `editorSettings.playbackRate` | `1.0` |

공통 Mixtape 기본값과 Editor 전용 기본값은 각각 한 모듈에서만 정의한다. UI, 검증, 재생 코드가 기본값을 중복 선언하지 않는다.

위 기본값은 schemaVersion 2 계약의 일부로 고정한다. 기존 Stage의 의미가 바뀌지 않도록 기본값 변경이 필요하면 schemaVersion을 올린다.

직렬화할 때 기본값과 같은 필드는 제거한다. 자식 필드가 모두 제거된 `mixtape` 또는 `editorSettings` 객체도 제거한다. 값을 기본값으로 되돌리면 기존 JSON 필드가 삭제된다. 해결된 값이 실제로 달라졌을 때만 Stage를 dirty로 표시한다.

### 3.4 검증

- `schemaVersion`: 정확히 `2`
- `bpm`: 유한한 양수
- `mixtape`: 생략 가능하며, 존재하면 JSON 객체
- `music`: 생략 가능. `/` 구분자를 쓰는 `assets/audio/` 아래 상대 경로이며 `..`, 절대 경로와 역슬래시를 허용하지 않는다. 확장자는 대소문자 구분 없이 `.ogg`, `.mp3`, `.wav`만 허용한다.
- `volume`: `0.0` 이상 `1.0` 이하의 유한한 수
- `beat0Offset`: 음수를 포함한 유한한 수
- `editorSettings`: 생략 가능하며, 존재하면 JSON 객체
- `metronome`: boolean
- `metronomePeriod`: `1` 이상 `32` 이하의 정수
- `scale`: `0.25` 이상 `8.0` 이하의 유한한 수
- `playbackRate`: `0.25` 이상 `4.0` 이하의 유한한 수
- `events`: 기존 Stage Event 배열 규칙 유지

버전 1과 `tempoMap`이 있는 Stage는 지원하지 않는 버전 또는 허용되지 않는 필드 오류로 거부한다.

## 4. 구성 요소와 경계

### 4.1 Core TempoMap

beat와 논리 타임라인 초 사이의 변환을 담당하는 순수 모듈이다. 이번 구현에서는 최상위 `bpm`으로 단일 구간만 만든다. 향후 BPM Change Event가 추가되면 Stage의 기본 BPM과 해당 Event 목록으로 구간을 파생한다. JSON에는 런타임 `TempoMap`을 저장하지 않는다.

### 4.2 Core MusicPlayback

LÖVE 오디오 Source를 감싸며 다음 책임만 가진다.

- Project가 해석한 실제 리소스 경로로 stream Source 생성
- seek, play, pause와 stop
- Volume과 pitch 적용
- 현재 음악 위치와 길이 조회
- 오디오 오류를 값으로 반환

Core가 `projects/<projectId>/` 경로를 직접 조합하지 않는다. Editor와 실제 게임 런타임이 Project 기준 상대 경로를 해석해 Source factory를 주입한다. 테스트에서는 가짜 Source factory를 사용한다.

### 4.3 Core PlaybackTransport

논리 타임라인 초, 현재 beat와 재생 상태의 단일 소유자다. `TempoMap`과 `MusicPlayback`을 조립하고 Play, Pause, update와 현재 위치 조회를 제공한다.

음악이 없어도 같은 논리 시계가 진행된다. 실제 게임은 기본 재생 배율 `1.0`으로 이 Transport를 사용한다. Editor는 Test Play 동안만 재생 배율을 전달한다.

### 4.4 Editor StageDocument와 기본값

StageDocument는 버전 2 JSON 검증, 희소 필드의 기본값 해결, 변경 적용, dirty 상태와 희소 직렬화를 담당한다. 공통 Mixtape 설정은 Core Transport에 해결된 값으로 전달하고, `editorSettings`는 Editor 안에서만 소비한다.

### 4.5 Editor 재생 제어

EditorSession은 Core PlaybackTransport, TestPlayer와 Editor 전용 MetronomePlayback을 조립한다.

- Play: 세 구성 요소를 전부 준비한 뒤 함께 시작
- update: Transport, Metronome과 `TestPlayer:update(deltaTime * playbackRate)` 진행
- Pause: 세 구성 요소를 모두 중지하고 현재 beat 보존
- 시작 중 하나라도 실패: 이미 준비된 구성 요소를 정리하고 재생 전 상태 유지

### 4.6 Editor 속성 UI

기존 BPM 전용 UI를 선택 Event와 속성 정의 목록을 그리는 구조로 일반화한다. 속성 정의는 ID, 표시 이름, 값 종류, 범위와 편집 방식을 가진다. 숫자 인라인 편집, boolean 전환과 Music 선택 모달은 이 정의를 통해 분기한다.

### 4.7 입력 전달

`love.wheelmoved`를 Main, Launcher와 EditorApp 순서로 전달한다. EditorApp은 현재 마우스 위치가 타임라인 안에 있을 때만 Scale을 변경한다. 다른 화면에서는 기존 입력 동작을 유지한다.

## 5. Events와 Properties UI

### 5.1 Events 순서와 선택

```text
Events
> Editor Properties
  Mixtape Properties
```

Stage를 생성하거나 열면 `Editor Properties`를 기본 선택한다. Event 선택 자체는 Stage 데이터가 아니며 dirty 상태를 만들지 않는다.

### 5.2 Editor Properties

```text
Properties          Values
Scale               1.0
Playback Rate       1.0
Metronome           false
Metronome Period    4
```

- 숫자 값은 Values 셀에서 직접 편집한다.
- `Metronome`은 Values 클릭 즉시 true와 false를 전환한다.
- Metronome이 false여도 Period를 미리 편집할 수 있다.
- `Scale`, `Playback Rate`, `Metronome`, `Metronome Period` 변경은 Stage를 dirty로 표시한다.

### 5.3 Mixtape Properties

```text
Properties          Values
Music               None
Volume              1.0
Beat 0 Offset       0.0
BPM                 120
```

- `Music` 클릭은 에디터 내부 선택 모달을 연다.
- 모달은 `None`과 `projects/<projectId>/assets/audio/`의 지원 파일을 이름순으로 표시한다.
- 확인은 선택을 적용하고 취소는 기존 값을 유지한다.
- `None`은 `mixtape.music` 필드를 제거한다.
- 나머지 숫자 값은 Values 셀에서 직접 편집한다.

### 5.4 인라인 편집

숫자 셀을 클릭하면 현재 값을 셀 안에서 편집한다. 첫 문자 입력은 기존 값을 대체하고 Backspace로 수정한다. Enter 또는 셀 밖 클릭은 확정하며 Escape는 취소한다. 유효하지 않은 값은 적용하지 않고 빨간 테두리로 표시한다. 잘못된 활성 값이 있으면 다른 Menu 동작을 실행하지 않는다.

같은 값을 확정하면 dirty 상태를 새로 만들지 않는다. 기본값을 확정하면 대응하는 희소 JSON 필드를 제거한다.

Play 중 Properties와 Values는 TestPlayer Canvas로 대체되므로 값을 편집할 수 없다. 타임라인 휠 Scale은 Play 중에도 사용할 수 있다.

## 6. 타임라인 Scale

한 박의 기본 너비는 32px이며 실제 너비는 `32 * scale`이다.

- 기본값: `1.0`
- 범위: `0.25~8.0`
- 휠 위: 기존 값 `* 1.25`
- 휠 아래: 기존 값 `/ 1.25`
- 범위를 넘으면 경계값으로 고정

휠 확대·축소에서는 다음 계산으로 커서 아래 beat를 유지한다.

```text
cursorBeat = timelineStartBeat + cursorOffsetX / oldPixelsPerBeat
newTimelineStartBeat = cursorBeat - cursorOffsetX / newPixelsPerBeat
```

`newTimelineStartBeat`는 0보다 작아질 수 없다. 정확한 고정을 위해 소수 beat를 허용한다. Values에서 Scale을 직접 입력할 때는 기존 왼쪽 `timelineStartBeat`를 유지한다. 타임라인 시작 위치 자체는 저장하지 않는다.

재생 자동 추적은 현재 playhead가 보이는 범위를 벗어날 때 새 Scale로 계산한 가시 beat 수를 사용한다.

## 7. 음악과 Transport 동작

### 7.1 위치 계산

```text
timelineSeconds = TempoMap.beatToSeconds(currentBeat)
musicSeconds = timelineSeconds + beat0Offset
```

- `musicSeconds`가 0 이상이고 음악 길이보다 작으면 해당 위치로 seek한 뒤 재생한다.
- `musicSeconds`가 음수면 Transport와 TestPlayer만 먼저 진행하고, 0을 통과한 update에서 초과분 위치로 seek한 뒤 음악을 시작한다.
- 이미 음악 길이를 넘었거나 재생 중 음악이 끝나면 음악만 멈추고 Transport와 TestPlayer는 계속 진행한다.
- Pause는 현재 논리 시간과 beat를 보존한다. 다음 Play는 보존 위치에서 위 계산을 다시 수행한다.

Beat 0 Offset `0.5`는 beat 0에서 음악 파일 0.5초부터 시작한다. `-0.5`는 beat 0 이후 논리 타임라인 0.5초 동안 무음으로 진행한 뒤 음악 파일 0초부터 시작한다.

### 7.2 Playback Rate

Editor Test Play에서만 다음 항목에 같은 Playback Rate를 적용한다.

- Transport 논리 시간 증가량
- Music Source pitch
- TestPlayer update deltaTime
- 메트로놈 재생 속도

LÖVE 기본 pitch 방식을 사용하므로 음악 속도와 음높이가 함께 변한다. 실제 게임은 `editorSettings.playbackRate`를 읽지 않고 항상 `1.0`을 사용한다.

### 7.3 동기화 보정

Transport의 논리 시간이 기준이다. 음악이 재생 중일 때 1초마다 기대 음악 위치와 Source 위치를 비교한다. 차이가 0.05초를 초과하면 기대 위치로 seek한다. 시작, 재개와 음수 Offset의 음악 시작 시에는 항상 정확한 위치로 seek한다.

## 8. Editor Metronome

MetronomePlayback은 프로젝트 리소스가 아닌 에디터 내장 소리를 사용한다. 현재 BPM과 Metronome Period로 한 BPM beat 길이의 짧은 루프 SoundData를 생성한다.

- 루프의 첫 틱: 높은 음의 강박
- 나머지 틱: 낮은 음의 일반박
- 틱 간격: `60 / (bpm * metronomePeriod)`초
- Period 4: 한 BPM beat 안에 강박 1회와 일반박 3회
- Playback Rate: 루프 Source pitch에 적용

beat 0에서 Play하면 강박을 즉시 재생한다. 중간 beat에서 재개하면 현재 beat의 세부 위치에 맞게 루프를 seek하고 다음 틱부터 들리게 한다. Pause하면 재생 중인 메트로놈 Source를 정지한다.

현재 범위에서는 재생 중 Properties가 숨겨지므로 BPM, Period와 Playback Rate를 재생 도중 변경하지 않는다. Pause 후 값을 바꾸고 다시 Play하면 새 설정으로 루프를 다시 만든다.

## 9. 오류 처리

- Music 없음: 무음으로 정상 Test Play
- 선택한 Music 파일 없음, 경로 이탈, 지원하지 않는 확장자 또는 디코딩 실패: Play를 시작하지 않고 오류 모달
- 재생 중 오디오 오류: Transport, Metronome과 TestPlayer를 Pause하고 Properties/Values 복원 후 오류 모달
- 숫자 또는 boolean 검증 실패: Stage에 적용하지 않고 해당 셀에서 인라인 오류 표시
- Music 선택 모달 취소: 기존 선택과 dirty 상태 유지
- Core Transport, Music, Metronome 또는 TestPlayer 준비 실패: 생성된 임시 Source와 게임 인스턴스를 정리하고 beat와 기존 편집 상태 유지

## 10. 테스트와 검증

### 10.1 Stage와 저장

- 버전 2 최소 Stage와 선택 객체 검증
- 버전 1과 `tempoMap` 거부
- 모든 숫자 범위, boolean과 Music 상대 경로 검증
- 누락 필드의 기본값 해결
- 기본값과 같은 필드 및 빈 부모 객체 생략
- 기본값으로 복귀할 때 필드 제거와 dirty 상태
- Sample Stage와 모든 fixture의 버전 2 JSON 문법 검증

### 10.2 Core 재생

- base BPM의 beat·seconds 왕복 변환
- 음악 없음과 음악 Source 생성 실패
- 양수·음수 Beat 0 Offset
- 0이 아닌 beat에서 Play, Pause와 재개 seek
- 음악 끝 이후 Transport 계속 진행
- Volume, pitch와 0.05초 초과 드리프트 보정
- 시작 실패 시 부분 재생 상태가 남지 않음

Core 오디오 테스트에는 Source factory와 시간을 주입해 실제 장치 없이 결정적으로 검증한다.

### 10.3 Editor

- Events 순서와 Editor Properties 기본 선택
- 각 선택의 Properties와 Values 순서
- 숫자 인라인 편집, boolean 전환과 오류 표시
- Music 모달 목록, 정렬, None, 확인과 취소
- 설정 변경 dirty와 희소 저장
- Playback Rate가 Transport, Music, Metronome과 TestPlayer deltaTime에만 적용됨
- 실제 게임 경로는 Playback Rate `1.0`을 사용함
- 메트로놈 Period 4의 강박·일반박과 중간 beat 재개 위상
- 휠 전달, Scale 경계, 배율과 커서 beat 고정
- Values 직접 Scale 편집의 왼쪽 시작 beat 고정
- Test Play 중 휠 Scale 허용

### 10.4 수동 검증

- `love . --test` 전체 통과
- PowerShell `ConvertFrom-Json`으로 모든 Stage JSON 확인
- 실제 Project 음악 파일을 선택하고 Volume·양수/음수 Offset·Playback Rate 확인
- Metronome Period 4에서 강박과 일반박 구분 확인
- Pause와 현재 beat 재개, 음악 종료 후 타임라인 계속 진행 확인
- 편집 화면과 TestPlayer 화면에서 타임라인 휠 Scale 확인

## 11. 완료 기준

- Events에 Editor Properties가 Mixtape Properties보다 먼저 표시되고 기본 선택된다.
- 모든 요청 속성이 정해진 순서와 편집 방식으로 동작한다.
- Project 음악을 선택해 현재 beat와 Beat 0 Offset에 맞춰 Test Play할 수 있다.
- 실제 게임과 Editor가 Core 음악 Transport 규칙을 공유한다.
- Playback Rate, Metronome과 Scale은 Editor 전용으로 유지된다.
- Stage는 schemaVersion 2의 최상위 BPM과 희소 설정 형식으로 저장된다.
- 자동 테스트, JSON 검증과 실제 LÖVE 실행 검증이 통과한다.
