### ADR-0005 수동 Component DI
- 상태: 채택
- 날짜: 2026-11-13
- 배경: RIBs-iOS는 needle로 Component 트리를 코드 생성한다. 코드 생성기는 빌드 단계를 늘리고 플랫폼마다 지원이 다르다.
- 결정: `Component<DependencyType>`를 손으로 작성한다. 자식 Dependency 프로토콜을 부모 Component가 구현해 자식 Builder에 넘긴다. Component 안의 싱글턴은 `shared { }`(호출한 프로퍼티 이름을 키로 캐시)로 만든다. 루트는 `EmptyComponent`를 넘긴다.
- 고려했던 대안:
  (1) needle: 원본과 같지만 코드 생성기·Foundation 의존이 있어 기각했다.
  (2) 서비스 로케이터·전역 컨테이너: 숨은 전역이 생겨 테스트가 어려워 기각했다.
- 결과: 보일러플레이트가 늘지만 의존 관계가 코드에 그대로 보이고 테스트에서 가짜 Component를 넘기기 쉽다.
- 관련: carti-RIBs-KMP ADR-0003
