# Project Category 자동 발견

Status: Accepted

Decision: Project 기능은 `projects/<projectId>/game/<CategoryName>/`에 Category 단위로 둔다. 순수 등록 데이터는 `Definition.lua`, 실행 조립은 `Runtime.lua`가 소유한다. `Core.ProjectCategories`가 두 파일을 발견하므로 새 Category를 추가할 때 기존 Project 진입 모듈이나 다른 Category를 수정하지 않는다. Event는 `categoryId + eventId`로 식별한다.

Reason: 게임별 기능을 Category 경계 안에 모으고, 새 기능 추가가 중앙 Registry 수정으로 번지지 않게 하기 위해서다.
