### ADR-0031 플랫폼 연결 코드는 빌드 때 생성하지 않고 `new-rib` 템플릿으로 한 번 만든다
- 상태: 채택
- 날짜: 2026-11-25
- 배경:
  - `TodoModular`에서 피처 하나를 Android와 Web에 붙이려면 그리는 코드 말고도 Swift 연결 코드를 손으로 쓴다. Android는 화면(`XxxAndroidScreen`)과 swift-java 핸들(`XxxScreenHandle`, `XxxViewBridge`), Web은 화면(`XxxWebScreen`)과 BridgeJS 브리지(`XxxViewBridge`, `XxxScreenHandle`, 둘을 잇는 코드)다. 피처 네 개에 약 650줄이다.
  - 연결 코드가 있는 이유는 상태 타입이 공유 패키지에 있어 도구가 내보내지 못한다는 것이었다(ADR-0020, ADR-0023). 이 제약이 최신 버전에서도 남아 있는지 확인했다. 쓰는 버전(swift-java 0.7.0, JavaScriptKit 0.63.0)이 각 저장소의 최신 릴리스다.
    - BridgeJS: 다른 모듈의 `@JS` 타입을 쓰는 기능(swiftwasm/JavaScriptKit#730)은 같은 패키지 안에서만 된다. PR 본문이 다른 패키지는 지원하지 않는다고 적었다. 타입에 `@JS`를 붙여야 하므로 공유 Interface 모듈이 JavaScriptKit을 import하게 된다.
    - swift-java: 의존 모듈에 `swift-java.config`를 두면 다른 모듈의 타입을 찾는다(swiftlang/swift-java#766). 공유 `TodoCore`에 설정 파일만 두고 브리지에서 `[Todo]`를 반환해 봤다. Java 시그니처는 만들어졌지만 `Todo`의 Java 클래스가 없어 컴파일이 실패했다. 클래스를 만들려면 `TodoCore`가 swift-java 플러그인을 돌려야 한다.
  - 두 도구 모두 공유 패키지가 도구에 의존해야 한다. 공유 코드는 플랫폼 도구를 모른다는 기준(ADR-0004, ADR-0024)과 맞지 않는다.
- 결정:
  - 경계용 타입과 연결 코드는 그대로 둔다(ADR-0020, ADR-0023 유지).
  - `new-rib`이 연결 코드의 뼈대를 만든다.
    - `--android <소스 디렉터리> --android-bridge <타깃> --android-support <모듈>`: `<소스>/<Prefix><Name>Android/<Name>AndroidScreen.swift`, `<소스>/<타깃>/<Name>Handle.swift`
    - `--web <소스 디렉터리> --web-bridge <타깃> --web-support <모듈>`: `<소스>/<Prefix><Name>Web/<Name>WebScreen.swift`, `<소스>/<타깃>/<Name>Bridge.swift`
    - 세 옵션은 함께 준다. 하나라도 빠지면 실패한다. 두 플랫폼의 브리지가 같은 디렉터리의 같은 타깃이어도 실패한다. 같은 이름의 타입이 두 번 선언되기 때문이다.
  - 피처 모드(`--feature`)에 함께 줄 수 있다. 공유 코드와 플랫폼 코드가 다른 패키지면 플랫폼 패키지에서 연결 모드(`--connect <Name>`)로 연결 코드만 만든다. 플러그인은 패키지 밖에 쓰지 않는다.
  - 템플릿은 `TodoModular`의 구조를 전제로 한다. support 모듈의 `BridgedScreen`·`ScreenContext`(Android), `WebScreen`(Web), Android 브리지 타깃의 전역 `controller`와 `screen(id:as:)`를 쓴다.
  - Web 브리지 파일은 화면과 JS 뷰를 잇는 함수(`<name>ViewFactory(_:)`)를 함께 만든다. 샘플의 `ViewMounts`에 손으로 더하던 부분이다.
  - Kotlin 어댑터와 JS 뷰는 만들지 않는다.
- 고려했던 대안:
  (1) 도구 버전을 올려 경계용 타입 없애기: 배경에 적은 대로 공유 패키지가 도구에 의존해야 해서 기각했다.
  (2) 빌드 도구 플러그인으로 연결 코드 생성(SwiftSyntax로 `ViewState`/`ViewAction`을 읽음): 상태를 바꿔도 손댈 곳이 없어진다. 대신 SwiftSyntax 의존성과 빌드 시간이 늘고, 배열·옵셔널·연관 값을 플랫폼별 인자로 푸는 규칙(Android는 배열을 콜백으로 못 넘김, Web의 `Int`는 32비트. ADR-0023)을 생성기가 알아야 한다. 피처 네 개짜리 샘플에서는 줄이는 코드보다 유지할 코드가 많아 기각했다. 피처가 늘어 상태 변경이 실제로 번거로워지면 다시 검토한다.
  (3) 그대로 두고 손으로 쓰기: 새 피처마다 같은 모양의 파일 네 개를 베껴 쓴다. 기각했다.
  (4) support 모듈의 기반 클래스를 `RIBsAndroid`·`RIBsWeb` 라이브러리로 옮겨 템플릿이 샘플 구조에 기대지 않게 하기: `WebScreen`은 JavaScriptKit에 의존하는데 `RIBsWeb`은 의존하지 않는다(ADR-0009). 이번 범위에서 하지 않는다.
- 결과:
  - 새 피처의 연결 코드는 명령 한 번으로 생긴다. 만든 Android 화면과 핸들이 호스트에서 컴파일되는지는 플러그인 테스트가 확인한다.
  - Web 템플릿은 JavaScriptKit이 필요해 플러그인 테스트에서 컴파일하지 않고 내용만 확인한다. `TodoModular`에 임시 피처를 만들어 Wasm 빌드와 `bridge-js.d.ts` 생성을 한 번 확인했다.
  - `ViewState`에 필드를 더하면 브리지 프로토콜의 `render` 인자를, `ViewAction`에 case를 더하면 핸들의 메서드를 여전히 손으로 맞춘다. 빠뜨린 `ViewAction` case는 컴파일러가 알려 주지 않는다.
  - 경계용 id 타입(Android `Int64`, Web `Int`)은 그대로다.
  - 이 구조가 아닌 프로젝트에서는 `--android`·`--web`이 만든 파일이 그대로는 빌드되지 않는다.
- 관련: ADR-0004, ADR-0009, ADR-0020, ADR-0021, ADR-0022, ADR-0023, ADR-0024, ADR-0029
