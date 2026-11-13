### ADR-0014 샘플 패키지는 루트 패키지를 디렉터리 이름이 아닌 `RIBs` 이름으로 참조한다
- 상태: 채택
- 날짜: 2026-11-14
- 배경: `Samples/WebLogin/Package.swift`는 루트를 `.package(path: "../..")`로 받고 제품을 `package: "carti-RIBs-Swift"`로 찾았다. SwiftPM은 경로 의존의 식별자를 경로 마지막 구성 요소(체크아웃 디렉터리 이름)로 정하므로, 저장소를 다른 이름으로 클론하면 제품을 찾지 못해 빌드가 깨졌다.
- 결정: `.package(name: "RIBs", path: "../..")`로 이름을 고정하고 제품은 `package: "RIBs"`로 찾는다. `RIBs`는 루트 `Package.swift`의 `name`과 같다. Android 샘플(`Samples/AndroidLogin/app/src/main/swift/Package.swift`)이 이미 같은 방식을 쓴다.
- 고려했던 대안:
  (1) 샘플 안에 루트를 가리키는 고정 이름 심볼릭 링크를 두고 그 경로로 의존: Windows 체크아웃에서 심볼릭 링크가 깨지고, SwiftPM이 링크를 풀어 실제 디렉터리 이름을 쓸 수 있어 보장이 약하다.
  (2) 루트 디렉터리 이름을 문서로 강제: 포크·CI 작업 디렉터리 이름을 통제할 수 없다.
  (3) 샘플을 루트 패키지 타깃으로 합치기: JavaScriptKit 의존이 루트에 들어와 ADR-0009의 분리 이유와 충돌한다.
- 결과: 디렉터리 이름과 무관하게 웹 샘플이 빌드된다(다른 이름의 복사본에서 `swift package --swift-sdk swift-6.4.2-RELEASE_wasm js`로 확인). `name:` 인자를 쓰는 `package(name:path:)`는 SwiftPM이 아직 지원하는 API다.
- 관련: ADR-0009, ADR-0010
