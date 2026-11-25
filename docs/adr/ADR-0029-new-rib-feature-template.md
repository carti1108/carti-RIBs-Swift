### ADR-0029 `new-rib`에 µFeature 피처 모드를 두고, 템플릿을 ViewState/ViewAction과 순수 뷰·어댑터 모양으로 바꾼다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - `new-rib` 플러그인은 한 모듈 안에 RIB 하나를 만들었다. µFeature 샘플(ADR-0024)은 피처마다 Interface·Impl·Testing·Tests를 같은 모양으로 반복하는데, 이를 만드는 수단이 없었다.
  - 템플릿의 뷰 계약은 `showTitle(_:)`/`didTapClose()`였다. 샘플은 `render(state)`/`handle(action)`으로 통일됐다(ADR-0025). ADR-0025의 결정 절은 "`new-rib` 템플릿도 메서드 없는 빈 계약을 그대로 만든다"고 적었는데 사실이 아니다. 템플릿을 읽지 않고 쓴 문장이다.
  - `--swiftui`가 만드는 화면은 뷰 계약 구현과 그리는 코드가 한 파일에 있었다. 샘플은 순수 뷰와 어댑터로 나뉘었다(ADR-0027).
  - 플러그인이 만든 결과가 빌드되는지 확인하는 테스트가 없었다.
- 결정:
  - 모드를 둘 둔다.
    - 한 모듈 모드(`--name`): 지금과 같은 인자. 파일 배치도 같다.
    - 피처 모드(`--feature <이름> [--root Features] [--prefix Feature] [--swiftui <디렉터리>]`): `<root>/<이름>/Interface`, `Sources`, `Testing`, `Tests`에 파일 하나씩을 만든다. 모듈 이름은 `<prefix><이름>Interface`, `<prefix><이름>`, `<prefix><이름>Testing`이다.
  - 두 모드 모두 뷰 계약을 `XxxViewState`(struct), `XxxViewAction`(enum), `render(_:)`, `handle(_:)`로 만든다.
  - 피처 모드의 내용은 TodoModular의 피처와 같다. Interface에는 뷰 계약, `XxxViewFactory`, `XxxDependency`, `XxxListener`, `XxxBuildable`을 두고, Sources에는 공개 Builder(`init(dependency:viewFactory:)`)와 내부 Interactor·Router를 둔다. Testing에는 가짜 뷰·팩토리·리스너·Dependency·Buildable을 둔다. Tests에는 활성화하면 초기 상태를 그리는지, 입력이 리스너로 가는지, Builder가 뷰를 하나 만드는지 확인하는 테스트를 둔다.
  - 생성되는 코드는 `RIBs`만 import한다. 샘플의 `TodoCore`·`TodoCoreTesting`에 기대지 않는다.
  - `--swiftui`는 파일 둘을 만든다. 순수 뷰 `XxxView`(SwiftUI만 import, `#Preview` 포함)와 어댑터 `XxxScreen`(뷰 계약 구현, `@Observable` 모델)이다. 피처 모드에서는 `<디렉터리>/UI`와 `<디렉터리>/Adapter`에 두고, 어댑터가 `<prefix><이름>UI`를 import하며 `XxxScreenFactory`를 함께 만든다.
  - `Package.swift`와 플랫폼 프로젝트 파일(Tuist, Gradle, Vite)은 고치지 않는다. 피처 모드는 넣을 줄(`feature("<이름>")`)과 다음 할 일을 출력한다.
  - 테스트 타깃 `NewRibTests`를 둔다. 임시 패키지를 만들어 `swift package new-rib`을 두 모드로 돌리고, 그 패키지에서 `swift test`가 통과하는지 확인한다. macOS와 Linux에서만 돈다.
- 고려했던 대안:
  (1) 템플릿의 계약은 메서드 방식으로 두기: 원본 RIBs-iOS 템플릿에 가깝다. 샘플과 템플릿이 서로 다른 모양을 권하게 되고, 만든 직후 손으로 바꿔야 한다. 기각했다. 라이브러리가 모양을 강제하지 않는다는 ADR-0019는 그대로다. 템플릿은 시작점일 뿐이다.
  (2) `Package.swift`에 타깃 선언을 자동으로 넣기: 매니페스트는 Swift 코드라 패키지마다 모양이 다르다. 텍스트로 고치면 깨뜨릴 수 있다. 넣을 줄을 출력하는 데서 멈췄다.
  (3) Android(Kotlin)·Web(TypeScript) 쪽 순수 뷰와 어댑터도 생성: 모듈 배치, 패키지 이름, 브리지 층(swift-java, BridgeJS)이 프로젝트마다 다르다. SwiftPM 플러그인이 Gradle·npm 프로젝트 구조를 알아야 한다. 이번에는 SwiftUI만 둔다.
  (4) 템플릿 문자열을 라이브러리 타깃으로 빼서 단위 테스트: 플러그인 타깃은 라이브러리 타깃에 의존할 수 없다. 템플릿 문자열만 비교하는 테스트는 생성물이 빌드되는지 알려 주지 않는다. 기각했다.
  (5) 생성물 검증을 스크립트로: 테스트 타깃에 두면 `swift test`에 함께 돈다. 기각했다.
- 결과:
  - 피처 모드로 만든 네 디렉터리는 타깃을 선언하면 그대로 빌드되고 생성된 테스트 3개가 통과한다. 한 모듈 모드는 테스트 2개가 통과한다.
  - `swift test`가 20초쯤 길어진다. 임시 패키지가 이 저장소를 경로 의존으로 받아 다시 빌드하기 때문이다.
  - `NewRibTests`는 `Foundation`의 `Process`를 쓴다. `Sources/RIBs`의 Foundation 금지(ADR-0004)는 테스트 타깃에 적용되지 않는다.
  - Windows에서는 플러그인 테스트가 돌지 않는다. `--feature` 모드가 Windows에서 동작하는지는 확인하지 않았다.
  - 한 모듈 모드의 출력이 바뀐다. 이전에 만든 RIB은 영향이 없지만, 새로 만드는 RIB의 계약 이름(`showTitle` → `render`, `didTapClose` → `handle(.closeTapped)`)과 SwiftUI 파일 수(1 → 2)가 달라진다.
  - 피처 모드의 `feature("<이름>")` 안내는 TodoModular의 매니페스트 헬퍼를 전제로 한다. 다른 패키지에서는 타깃 네 개를 직접 선언해야 한다.
  - 자식 피처가 있는 피처(부모 Dependency가 자식 Buildable을 만드는 경우)의 뼈대는 만들지 않는다. 손으로 더한다.
- 관련: ADR-0004, ADR-0019, ADR-0024, ADR-0025, ADR-0027
