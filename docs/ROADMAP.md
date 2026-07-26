# 개발 로드맵

## 0. Project 초기화

- [x] Core, Editor, Project 모듈 경계 설계
- [x] LÖVE2D 11.5 공통 Launcher
- [x] 에디터 UI 골격
- [x] Sample Project
- [x] Stage JSON 버전 2와 희소 재생 설정
- [x] 자동 테스트와 인수인계 문서

## 1. 시간·음악과 판정 Core

- [x] 고정 BPM 재생 시계
- [x] 고정 BPM beat와 seconds 변환 `TempoMap`
- [x] Source 생성·duration·drift를 감싼 `MusicPlayback`
- [x] Offset과 Playback Rate를 조정하는 공통 `PlaybackTransport`
- [ ] Tap Note 판정
- [ ] Long Note 판정 방식 설계 및 구현
- [ ] `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 판정 테스트

## 2. Pattern과 Stage 런타임

- [ ] Project Event 등록 계약
- [x] Stage JSON 검증과 로딩, sourceRoot 입출력 경계와 JSON 종류·null 보존
- [x] 최상위 BPM, Mixtape와 Editor 설정의 schemaVersion 2 전환
- [ ] Pattern 참조와 파라미터 전개
- [ ] 존재하지 않는 Pattern 오류 처리

## 3. 에디터 편집 기능

- [x] Project와 Stage 선택
- [x] EditorSession의 Stage 생성, 열기와 저장 상태
- [x] Dialog와 Values 공통 TextInput·Project/Stage/Music 인라인 검색 ComboBox
- [x] Project Music 재귀 검색과 선택 모달
- [x] Scale 기반 Timeline과 cursor anchor wheel zoom
- [ ] Project Events와 Categories 목록
- [ ] Project Event의 Properties와 Values 편집
- [ ] Timeline Event 배치, 이동, 삭제
- [x] JSON 저장과 불러오기

## 4. TestPlayer와 Editor 재생

- [x] 기본 Project Canvas 렌더링
- [x] Core PlaybackTransport 기반 Timeline과 Music 동기화
- [x] 재생, 일시정지, 오류 rollback과 자동 playhead 추적
- [x] Editor 전용 Playback Rate와 Metronome
- [x] 고정 메모리 동적 BPM beat 클릭과 Metronome Period 강박 그룹
- [x] Music 없음, Offset, duration 종료와 희소 설정 통합 경로
- [ ] Stage Event 실행
- [ ] Project 입력 전달

## 5. 배포와 엔진 버전 관리

- [ ] 선택 Project와 Core만 포함하는 독립 패키징
- [ ] Core API 호환 버전 검사 확장
- [ ] 버전형 Core·Editor 패키지 분리 검토
