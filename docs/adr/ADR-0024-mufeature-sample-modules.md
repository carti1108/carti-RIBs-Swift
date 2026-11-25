### ADR-0024 µFeature 샘플은 피처마다 Interface·Impl·Testing·Tests를 나누고, Impl은 조립 모듈만 import한다
- 상태: 채택
- 날짜: 2026-11-23
- 배경: `LoginShared`(ADR-0008)는 RIB 5개가 한 모듈에 있다. 실제 앱은 피처를 모듈로 나눠 경계를 컴파일러로 지키고, 고친 피처만 다시 빌드하고, 피처별 Example 앱을 띄운다(Tuist µFeature). 같은 구조가 iOS·Android·Web 공유 코드에서도 되는지 보여 줄 샘플이 필요하다. 동작은 `LoginShared`와 같다.
- 결정:
  - `Samples/TodoModular/Shared`는 별도 SwiftPM 패키지다. 루트는 `.package(name: "RIBs", path: "../../..")`로 받는다(ADR-0015).
  - 공통 모듈 `TodoCore`(Todo, TodoStore, AuthService, TodoClock)와 `TodoCoreTesting`(가짜 시계·인증)을 둔다.
  - 피처(LoggedOut, LoggedIn, TodoList, TodoDetail)마다 타깃 4개를 둔다.
    - `FeatureXxxInterface`: 뷰 계약, `XxxViewFactory`, `XxxDependency`, `XxxListener`, `XxxBuildable`(부모가 쓰는 Routing 포함).
    - `FeatureXxx`: Builder(공개), Interactor·Router(내부). 자기 Interface, 자식 Interface, `TodoCore`만 import한다.
    - `FeatureXxxTesting`: 가짜 뷰·리스너·자식 Buildable.
    - `FeatureXxxTests`: 피처 단독 테스트.
  - 부모 피처는 자식 Builder를 Dependency의 팩토리 메서드(`makeTodoListBuilder(dependency:)`)로 받는다. 실제 Impl을 잇는 곳은 조립 모듈 `TodoAppRoot` 하나다.
  - 뷰 팩토리는 피처마다 쪼갠다. Builder가 `init(dependency:viewFactory:)`로 받아 Dependency에는 서비스만 남는다.
  - 경계는 `Package.swift`의 타깃 의존 선언으로 정한다. 다만 SwiftPM 6.4.2(Windows)의 `--explicit-target-dependency-import-check error`는 기본(swiftbuild)·native 빌드 시스템 모두에서 Impl → 다른 Impl import를 잡지 못했다. 같은 빌드에 그 모듈이 있으면 import가 성공한다. 자동 검사는 후속으로 남긴다.
  - Example 앱·플랫폼 UI는 플랫폼 쪽(Tuist·Gradle·Vite)에 둔다. 이 ADR은 공유 패키지만 다룬다.
- 고려했던 대안:
  (1) `LoginShared`를 그대로 두고 문서로만 규칙 설명: 경계와 증분 빌드를 보여 줄 수 없어 기각했다.
  (2) 루트 `Package.swift`에 타깃 추가: 샘플 하나에 타깃이 20개 가까이 늘어 라이브러리 매니페스트가 흐려지고, ADR-0008의 "한 패키지" 이유(Wasm·Android 명령 단순화)는 별도 패키지의 `--package-path`로도 충족되어 기각했다.
  (3) Tuist에만 피처 타깃 정의: Android·Web 빌드가 Tuist 매니페스트를 읽지 못해 기각했다.
  (4) 부모 Impl이 자식 Impl을 직접 import: 피처 하나를 고치면 부모까지 다시 컴파일되고, 피처 단독 테스트에서 자식을 가짜로 바꿀 수 없어 기각했다.
- 결과: 피처마다 `swift test --filter FeatureXxxTests`로 단독 테스트가 돈다. 공유 패키지는 Foundation 없이 빌드된다(ADR-0004). 플랫폼 앱은 후속 작업이다.
- 관련: ADR-0004, ADR-0005, ADR-0008, ADR-0015
