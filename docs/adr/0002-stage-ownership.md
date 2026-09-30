# Stage 형식과 저장 책임의 단일 소유

Status: Accepted

Decision: Stage 형식과 정규화는 `Core.StageSchema`, 경로 계산·JSON 변환·원자 저장은 `Core.StageRepository`, 실행 순서와 중간 시작 상태 복원은 `Core.StageRuntime`이 소유한다. Launcher는 `StageRepository` 인스턴스 하나를 조립해 Editor와 Project에 주입한다. Project는 Stage JSON을 직접 해석하거나 경로를 계산하지 않는다.

Reason: Editor와 Project가 같은 Stage 규칙을 따르게 하고, 저장과 실행 규칙의 중복 구현으로 생기는 차이를 막기 위해서다.
