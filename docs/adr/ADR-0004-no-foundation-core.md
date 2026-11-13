### ADR-0004 코어는 Foundation 없이 표준 라이브러리만 쓴다
- 상태: 채택
- 날짜: 2026-11-13
- 배경: 코어를 Linux·Wasm·Android에서도 빌드하려 한다. Foundation은 플랫폼마다 구현과 크기가 다르고 Wasm 지원이 제한적이다.
- 결정: `RIBs` 타깃은 Swift 표준 라이브러리와 `_Concurrency`만 쓴다. 상태 저장은 `RibValue` 열거형(문자열·Int64·유한 Double·Bool·null·리스트·중첩 `RibState`)과 직접 쓴 JSON 형식 인코더/디코더로 한다. 키는 정렬해 결정적으로 인코딩한다. CI가 `import Foundation|Dispatch|Combine`을 검사한다.
- 고려했던 대안:
  (1) Foundation `JSONEncoder`: 간단하지만 Foundation 의존이 생겨 기각했다.
  (2) `Codable` 제네릭 저장: 사용자가 인코더를 골라야 하고 Foundation 없이는 쓸 인코더가 없어 기각했다.
- 결과: 날짜·URL 같은 타입은 앱이 문자열·숫자로 바꿔 넣는다. 인코딩 형식은 KMP `RibState`와 같은 JSON 부분집합이다.
- 관련: carti-RIBs-KMP ADR-0008
