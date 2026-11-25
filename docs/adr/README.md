# ADR 목록

| 번호 | 제목 | 상태 |
|---|---|---|
| [0001](ADR-0001-uber-ribs-ios-as-reference.md) | uber/RIBs-iOS를 원본으로 삼는다 | 채택 |
| [0002](ADR-0002-swift-concurrency-instead-of-rx.md) | Rx 대신 Swift Concurrency를 쓴다 | 채택 |
| [0003](ADR-0003-main-actor-lifecycle.md) | 생명주기 타입을 @MainActor로 격리한다 | 채택 |
| [0004](ADR-0004-no-foundation-core.md) | 코어는 Foundation 없이 표준 라이브러리만 쓴다 | 채택 |
| [0005](ADR-0005-manual-component-di.md) | 수동 Component DI | 채택 |
| [0006](ADR-0006-opaque-view-controllable.md) | ViewControllable을 불투명한 타입으로 둔다 | 채택 |
| [0007](ADR-0007-ui-adapters.md) | SwiftUI·UIKit 어댑터를 별도 타깃으로 둔다 | 채택 |
| [0008](ADR-0008-login-sample-structure.md) | 로그인 샘플을 Foundation 없는 공유 타깃과 플랫폼 앱으로 나눈다 | 채택 (뷰 계약의 메서드 모양은 ADR-0025로 대체됨) |
| [0009](ADR-0009-web-via-javascriptkit-dom.md) | 웹(Wasm)은 Swift가 JavaScriptKit으로 DOM을 직접 그린다 | 대체됨(ADR-0022) |
| [0010](ADR-0010-android-via-jni-and-main-looper.md) | Android는 손으로 쓴 JNI로 화면 트리 JSON을 Compose에 넘기고, 메인 큐를 메인 Looper에 붙인다 | 대체됨(ADR-0021) |
| [0011](ADR-0011-api-dump-check.md) | 공개 API를 swift-api-digester 덤프로 체크인하고 CI에서 비교한다 | 채택 |
| [0012](ADR-0012-docc-plugin-dependency.md) | 문서는 swift-docc-plugin과 RIBs.docc 카탈로그로 만든다 | 채택 |
| [0013](ADR-0013-web-session-storage-restore.md) | 웹 샘플은 sessionStorage에 RibState를 저장하고 새로고침 때 복원한다 | 채택 |
| [0014](ADR-0014-android-main-queue-spi-self-check.md) | Android 메인 큐 연결은 libdispatch SPI를 유지하고 시작 시 자체검사한다 | 채택 |
| [0015](ADR-0015-sample-root-package-name.md) | 샘플 패키지는 루트 패키지를 디렉터리 이름이 아닌 `RIBs` 이름으로 참조한다 | 채택 |
| [0016](ADR-0016-mount-and-ribstate-as-extensions.md) | `mount`/`RibMount`와 `RibState`를 RIBs-iOS 밖의 확장으로 유지한다 | 채택 |
| [0017](ADR-0017-allow-foundation-essentials.md) | 코어와 공유 모듈에서 FoundationEssentials를 허용한다 | 제안 |
| [0018](ADR-0018-rib-snapshot.md) | 트리 저장·복원을 `Codable` 기반 `RibSnapshot`으로 바꾼다 | 제안 |
| [0019](ADR-0019-view-contract-shape-not-enforced.md) | 코어는 뷰 계약의 모양을 강제하지 않는다 | 채택 (샘플 통일 여부는 ADR-0025로 대체됨) |
| [0020](ADR-0020-per-screen-view-bridge.md) | 플랫폼 뷰 경계는 화면마다 격리 없는 브리지 프로토콜 하나와 핸들 클래스 하나로 둔다 | 채택 |
| [0021](ADR-0021-android-view-bridge-via-swift-java.md) | Android 뷰 브리지는 swift-java(JNI 모드)로 생성하고 Swift 런타임을 동적 라이브러리로 싣는다 | 채택 |
| [0022](ADR-0022-web-view-bridge-via-bridgejs.md) | Web 뷰 브리지는 BridgeJS로 생성하고 뷰는 JS가 그린다 | 채택 |
| [0023](ADR-0023-screen-structure-outside-view-bridge.md) | 화면 구조는 브리지 밖에 두고, 목록 항목은 경계용 값 타입으로 넘긴다 | 채택 |
| [0024](ADR-0024-mufeature-sample-modules.md) | µFeature 샘플은 피처마다 Interface·Impl·Testing·Tests를 나누고, Impl은 조립 모듈만 import한다 | 채택 |
| [0025](ADR-0025-sample-view-contract-state-and-action.md) | 샘플의 뷰 계약은 모두 `render(state)`와 `handle(action)`으로 둔다 | 채택 |
| [0026](ADR-0026-todomodular-web-views-in-react.md) | TodoModular 웹 뷰는 React와 TypeScript로 쓰고, 프레임워크는 JS 쪽에만 둔다 | 채택 (피처 뷰의 파일 배치는 ADR-0027로 대체됨) |
| [0027](ADR-0027-pure-view-and-adapter.md) | 샘플의 플랫폼 뷰를 순수 뷰와 어댑터로 나눈다 | 채택 |
| [0028](ADR-0028-sample-boundary-check-script.md) | 샘플의 모듈 경계는 import 문을 읽는 스크립트로 검사한다 | 채택 |
| [0029](ADR-0029-new-rib-feature-template.md) | `new-rib`에 µFeature 피처 모드를 두고, 템플릿을 ViewState/ViewAction과 순수 뷰·어댑터 모양으로 바꾼다 | 채택 |
