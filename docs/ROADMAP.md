# 개발 로드맵

## 0. Project 초기화

- [x] Core, Editor, Project 모듈 경계 설계
- [x] LÖVE2D 11.5 공통 Launcher
- [x] 에디터 UI 골격
- [x] Sample Project
- [x] SampleGameplay를 자동 발견되는 `game/SampleGameplay/` Category 경계로 이동하고 Actor 책임 재구성
- [x] 안전한 빈 Project 생성 스크립트와 템플릿 회귀 테스트
- [x] Stage JSON 버전 2와 희소 재생 설정
- [x] 자동 테스트와 인수인계 문서

## 1. 시간·음악과 판정 Core

- [x] 고정 BPM 재생 시계
- [x] 고정 BPM beat와 seconds 변환 `TempoMap`
- [x] Source 생성·duration·active seek·drift를 감싼 `MusicPlayback`
- [x] Offset과 Playback Rate를 조정하는 공통 `PlaybackTransport`
- [x] beat 판정창 기반 Tap Note GOOD/BAD/MISS/EMPTY_INPUT 판정
- [x] beat 기반 Long Note 누름·뗌 GOOD/BAD/MISS 판정
- [x] `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 판정 테스트

## 2. Pattern과 Stage 런타임

- [x] Project Event Category·number Property 등록 계약
- [x] Stage JSON 검증과 로딩, sourceRoot 입출력 경계와 JSON 종류·null 보존
- [x] 최상위 BPM, Mixtape와 Editor 설정의 schemaVersion 2 전환
- [ ] Pattern 참조와 파라미터 전개
- [ ] 존재하지 않는 Pattern 오류 처리

## 3. 에디터 편집 기능

- [x] Project와 Stage 선택
- [x] EditorSession의 Stage 생성, 열기와 저장 상태
- [x] Core.UI Button·TextInput·ComboBox·ScrollArea와 Editor 스타일 조합
- [x] D2Coding 기본 폰트로 Launcher·Editor·Project 한글 렌더링 통일
- [x] 콘텐츠 15행 높이의 고정 상단 패널과 Categories·Events 독립/Properties·Values 연동 조건부 스크롤
- [x] `assets/audio/music/` Project Music 재귀 검색과 SFX를 제외한 선택 모달
- [x] 권장 Threshold 기본값 `0.01`의 Music 첫 소리 검출과 Beat 0 Offset 자동·수동 설정
- [x] Scale 기반 Timeline, 빈 첫 칸과 Period 경계 눈금, 공통 Snap, 상단 click·adaptive edge-scroll drag, cursor anchor wheel zoom, 중간 버튼 pan과 F·R 재생 단축키
- [x] 내장 Game Manager Category와 End·Set Input Enabled 목록
- [x] Project Events와 Categories 등록 목록
- [x] Set Input Enabled 노드별 Properties 편집 모달
- [x] Project Event number Properties 기본값과 노드별 편집, Cue & Response 중립색 연결 영역
- [x] Timeline Event 충돌 방지 우클릭 배치·error toast와 셀 기반 공통 Snap·Track 이동
- [x] Timeline Event 클릭·marquee 다중 선택, 충돌 preview 그룹 이동과 Delete 삭제
- [x] Timeline Event 박스 내부 1px 윤곽선 이름과 hover 전체 이름 표시
- [x] JSON 저장과 불러오기

## 4. TestPlayer와 Editor 재생

- [x] 기본 Project Canvas 렌더링과 Stage별 Preview 종횡비 설정
- [x] Core PlaybackTransport 기반 Timeline과 Music 동기화
- [x] 기준 바와 재생 위치 바 분리, 기준 beat 재시작, 오류 rollback과 자동 playhead 추적
- [x] Editor 전용 Playback Rate와 Metronome
- [x] None·Good·Bad·Miss Project 판정 Auto Play
- [x] 고정 메모리 동적 BPM beat 클릭과 Metronome Period 강박 그룹
- [x] Music 없음, Offset, duration 종료와 희소 설정 통합 경로
- [x] Core StageRuntime 기반 Game Manager End·Set Input Enabled와 Project Event 공통 전개
- [x] End 없는 Music 자동 종료
- [ ] Project Pattern Event 실행
- [x] 입력 활성 상태를 반영한 Space와 현재 beat 전달
- [x] Sample Sprite 상태 피드백과 Core BeatTween 기반 0.5박 Turn 이동
- [x] Rhythm Dotgeo 독립 실행 Stage 목록과 클릭 시 Music·beat 시작
- [x] Rhythm Dotgeo 스피키송 Category의 배경·액터 소환, Tap/Long 큐 응답과 턴

## 5. 배포와 엔진 버전 관리

- [ ] 선택 Project와 Core만 포함하는 독립 패키징
- [ ] Core API 호환 버전 검사 확장
- [ ] 버전형 Core·Editor 패키지 분리 검토
