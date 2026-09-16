# 개발 로드맵

## Core Stage 소유권 구조 개편

- [x] Phase 1: `Core.StageSchema`, `Core.StageRepository`, `Core.ProjectManifest`로 형식·I/O·manifest 검증을 통합하고 Launcher의 Repository 하나를 Editor와 Project에 주입한다. schemaVersion 3과 `categoryId + eventId` Project Event 식별을 적용하고 정적 모듈 경계 테스트를 둔다.
- [ ] Phase 2: Editor와 Project의 `StageRuntime` 조립을 단일 실행 권위로 통합한다.
- [ ] Phase 3: Launcher의 동적 Project 메뉴를 구현하고 `EditorApp`의 화면 입력 책임과 `EditorSession`의 편집 상태 책임을 더 분리한다.
- [x] Rhythm Dotgeo Windows 독립 패키징 구현 (임의 Project 선택은 후속 작업).

## 0. Project 초기화

- [x] Core, Editor, Project 모듈 경계 설계
- [x] LÖVE2D 11.5 공통 Launcher
- [x] 에디터 UI 골격
- [x] Sample Project
- [x] SampleGameplay를 자동 발견되는 `game/SampleGameplay/` Category 경계로 이동하고 Actor 책임 재구성
- [x] 안전한 빈 Project 생성 스크립트와 템플릿 회귀 테스트
- [x] Stage JSON 버전 3, Category/Event 복합 식별자와 희소 재생 설정
- [x] 자동 테스트와 인수인계 문서

## 1. 시간·음악과 판정 Core

- [x] 고정 BPM 재생 시계
- [x] 고정 BPM beat와 seconds 변환 `TempoMap`
- [x] Source 생성·duration·active seek·drift를 감싼 `MusicPlayback`
- [x] Offset과 Playback Rate를 조정하는 공통 `PlaybackTransport`
- [x] beat 판정창 기반 Tap Note GOOD/BAD/MISS/EMPTY_INPUT 판정
- [x] beat 기반 Long Note 누름·뗌 GOOD/BAD/MISS 판정
- [x] 실제 ms 누름 시간 기반 Tap·Long Start·Long Release 플레이어 액션 분류
- [x] `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 판정 테스트

## 2. Pattern과 Stage 런타임

- [x] Project Event Category·number Property 등록 계약
- [x] Stage JSON 검증과 로딩, sourceRoot 입출력 경계와 JSON 종류·null 보존
- [x] 최상위 BPM, Mixtape와 Editor 설정의 schemaVersion 3 전환
- [ ] Pattern 참조와 파라미터 전개
- [ ] 존재하지 않는 Pattern 오류 처리

## 3. 에디터 편집 기능

- [x] 스피키송 자동 Turn 대기 위치를 화면 가장자리에 12px만 걸치도록 조정

- [x] Project와 Stage 선택
- [x] EditorSession의 Stage 생성, 열기와 저장 상태
- [x] 오류 모달 전문 클립보드 복사 버튼과 Ctrl+C 단축키
- [x] Windows 한글 프로젝트 경로의 Stage 파일 확인·열기·저장 오류 수정 및 실제 파일 회귀 검증
- [x] Core.UI Button·TextInput·ComboBox·ScrollArea와 Editor 스타일 조합, Values 바깥 클릭 확정·Escape 취소
- [x] D2Coding 기본 폰트로 Launcher·Editor·Project 한글 렌더링 통일
- [x] 콘텐츠 15행 높이의 고정 상단 패널과 Categories·Events 독립/Properties·Values 연동 조건부 스크롤
- [x] `assets/audio/music/` Project Music 재귀 검색과 SFX를 제외한 선택 모달
- [x] 권장 Threshold 기본값 `0.01`의 Music 첫 소리 검출과 Beat 0 Offset 자동·수동 설정
- [x] Scale 기반 Timeline, 빈 첫 칸과 Period 경계 눈금, 공통 Snap, 상단 click·adaptive edge-scroll drag, cursor anchor wheel zoom, 중간 버튼 pan과 F·R 재생 단축키
- [x] 내장 Game Manager Category와 End·Set Input Enabled 목록
- [x] Project Events와 Categories 등록 목록
- [x] Set Input Enabled 노드별 Properties 편집 모달
- [x] Project Event number Properties 기본값과 노드별 편집, Cue & Response 중립색 연결 영역
- [x] Long Note Property를 연결형 가이드·응답 블록 표시·충돌 폭에 반영
- [x] Timeline Event 충돌 방지 우클릭 배치·error toast와 셀 기반 공통 Snap·Track 이동
- [x] Timeline Event 클릭·marquee 다중 선택, 충돌 preview 그룹 이동과 Delete 삭제
- [x] 전체 프로퍼티·상대 위치를 보존하는 Timeline Ctrl+C/X/V와 Ctrl+Z·Ctrl+Shift+Z 편집 이력
- [x] Timeline Event 박스 내부 1px 윤곽선 이름과 hover 전체 이름 표시
- [x] JSON 저장과 불러오기

## 4. TestPlayer와 Editor 재생

- [x] Editor Properties Fullscreen 저장 설정과 Tab 토글, 재생 시작부터 설정 적용, Esc 복귀, 종횡비 유지와 숨겨진 편집 입력 차단
- [ ] Editor Properties의 Record boolean과 화면·게임 소리 영상 저장: 녹화 백엔드 방식 결정 필요

- [x] 미리보기 Canvas 합성에 UI 색상·알파가 곱해지는 문제 수정 및 실제 흰색 픽셀 회귀 검증
- [x] 기본 Project Canvas 렌더링과 Stage별 Preview 종횡비 설정
- [x] Core PlaybackTransport 기반 Timeline과 Music 동기화
- [x] 기준 바와 재생 위치 바 분리, 기준 beat 재시작, 오류 rollback과 자동 playhead 추적
- [x] Editor 전용 Playback Rate와 Metronome
- [x] None·Good·Bad·Miss Project 판정 Auto Play
- [x] 고정 메모리 동적 BPM beat 클릭, Metronome Period 강박 그룹과 amplitude 1.0 회귀 테스트 동기화
- [x] Music 없음, Offset, duration 종료와 희소 설정 통합 경로
- [x] Core StageRuntime 기반 Game Manager End·Set Input Enabled와 Project Event 공통 전개
- [x] End 없는 Music 자동 종료
- [ ] Project Pattern Event 실행
- [x] 입력 활성 상태를 반영한 Space와 현재 beat 전달
- [x] Sample Sprite 상태 피드백과 Core BeatTween 기반 0.5박 Turn 이동
- [x] Rhythm Dotgeo 독립 실행 Stage 목록과 클릭 시 Music·beat 시작
- [x] Rhythm Dotgeo 스피키송 Category의 배경·액터 소환, Tap/Long 큐 응답과 Cue/Response 0.5박 전 자동 Turn
- [x] 스피키송 배경을 흰색으로 변경한 뒤 사용자 요청으로 기존 배경 이미지 복원
- [x] 스피키 idle에 하단 고정 매 박자 눌림·복원 적용, Tap/Long 제외와 재생 위치 동기화 검증
- [x] 스피키송 상단 중앙 크레페 이미지 2장의 매 박자 교대 애니메이션
- [x] 크레페의 매 박자 왼쪽 이동과 화면 밖 오른쪽 재등장, 중간 재생 위치 동기화
- [x] 크레페를 상단 중앙에서 시작하는 한 명으로 변경하고 기존 걷기·턴·플립 유지 (가로 반복 표시 대체)
- [x] 크레페 이동을 8박 주기 왕복으로 변경하고 이동 거리·스프라이트 크기에 따른 좌우 여백 균등 배분 (랜덤·경계 반사 대체)
- [x] 오른쪽 이동 턴에서 크레페 스프라이트 좌우 반전, 왼쪽 이동 턴에서 원본 방향 복원
- [x] 크레페 방향 반전·프레임 교대·이동을 같은 정수 박자로 동기화
- [x] 크레페 이미지를 0~11의 12프레임으로 교체하고 한 박자에 한 사이클 반복, 방향 반전은 사이클 시작에 적용
- [x] 크레페 애니메이션 주기를 두 박자로 조정하고 소수 beat 기반 연속 이동으로 전환, 턴 경계 위치 연속성 유지
- [x] 크레페 방향 전환에 0.25박 종이 플립 적용, 이동·걷기 애니메이션과 중간 재생 동기화 유지
- [x] 스피키송 배치·반응·SFX Project JSON Play 자동 재로드와 QueueableSource 기반 Long start→loop 연속 재생·end SFX·설정 개수 기반 역할별 Tap SFX 순환
- [x] 스피키송의 노트 종류 독립 Tap/Long 선택과 Project 전역 ms 임계값

## 5. 배포와 엔진 버전 관리

- [x] Rhythm Dotgeo와 Core만 포함하는 Windows EXE·ZIP 빌드 및 결합 EXE 검증
- [ ] 임의 Project를 선택하는 범용 패키징
- [ ] Core API 호환 버전 검사 확장
- [ ] 버전형 Core·Editor 패키지 분리 검토

## 코드 분석용 주석

- [x] `main.lua`의 LÖVE 생명주기와 Lua 입문 주석
- [ ] Launcher와 Project 로딩 흐름
- [ ] Sample Project와 Core StageRuntime 실행 흐름
- [ ] Core 시간·음악과 판정 흐름
- [ ] Stage 데이터와 Editor 흐름

## 포트폴리오 문서

- [x] Editor 화면, Architecture, 제작 Workflow, 역할 구분과 현재 한계를 중심으로 README 랜딩 페이지 재구성·압축
- [ ] README에 데모 플레이 영상 추가

- [x] 크레페 걷기 이미지를 24프레임·30fps(0.8초 반복)로 적용하고 Stage 재생 시간에 동기화

- [x] 소수 Snap 입력·저장·노드 배치 허용 및 소수 셀 경계 오차 보정

- [x] 스피키송 `스피키 위치 복귀` 이벤트: 두 스피키의 초기 위치로 0.5박 복귀, 중간 시작과 자동 Turn 재개

- [x] 크레페 중앙 idle 대기·첫 스피키 이동 동기 출발·4/8박 왕복 및 idle 40프레임 자동 인식

- [x] 스피키 위치 복귀 시 크레페 현재 위치 정지·idle 전환, 다음 자동 Turn에서 왕복 진행도 유지 재개

- [x] 크레페에 하단 고정 박자 바운스 적용 및 위치 복귀 시 스피키·크레페 바운스 정지
