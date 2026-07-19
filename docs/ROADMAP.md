# 개발 로드맵

## 0. 프로젝트 초기화

- [x] Core, Editor, Project 모듈 경계 설계
- [x] LÖVE2D 11.5 공통 실행기
- [x] 에디터 UI 골격
- [x] Sample Project
- [x] Stage JSON 버전 1 문서
- [x] 자동 스모크 테스트와 인수인계 문서

## 1. 시간과 판정 코어

- [x] 고정 BPM 재생 시계
- [ ] 박자와 초 변환
- [ ] Tap Note 판정
- [ ] Long Note 판정 방식 설계 및 구현
- [ ] `GOOD`, `BAD`, `MISS`, `EMPTY_INPUT` 판정 테스트

## 2. Pattern과 Stage 런타임

- [ ] 프로젝트 Event 등록 계약
- [x] Stage JSON 검증과 로딩
- [ ] Pattern 참조와 파라미터 전개
- [ ] 존재하지 않는 Pattern 오류 처리

## 3. 에디터 편집 기능

- [ ] 프로젝트와 Stage 선택
- [x] EditorSession의 Stage 생성, 열기와 저장 상태
- [ ] Categories와 Events 목록
- [ ] Properties와 Values 편집
- [ ] 타임라인 배치, 이동, 삭제
- [ ] JSON 저장과 불러오기

## 4. TestPlayer

- [x] 프로젝트 실시간 Canvas 렌더링
- [x] 에디터 타임라인과 공통 재생 시계
- [ ] 재생, 일시정지와 위치 이동
- [ ] 프로젝트 입력 전달

## 5. 배포와 엔진 버전 관리

- [ ] 선택 Project와 Core만 포함하는 독립 패키징
- [ ] Core API 호환 버전 검사 확장
- [ ] 버전형 Core·Editor 패키지 분리 검토
