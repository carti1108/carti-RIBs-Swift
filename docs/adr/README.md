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
| [0008](ADR-0008-login-sample-structure.md) | 로그인 샘플을 Foundation 없는 공유 타깃과 플랫폼 앱으로 나눈다 | 채택 |
| [0009](ADR-0009-web-via-javascriptkit-dom.md) | 웹(Wasm)은 Swift가 JavaScriptKit으로 DOM을 직접 그린다 | 채택 |
| [0010](ADR-0010-android-via-jni-and-main-looper.md) | Android는 손으로 쓴 JNI로 화면 트리 JSON을 Compose에 넘기고, 메인 큐를 메인 Looper에 붙인다 | 채택 |
| [0011](ADR-0011-api-dump-check.md) | 공개 API를 swift-api-digester 덤프로 체크인하고 CI에서 비교한다 | 채택 |
| [0012](ADR-0012-docc-plugin-dependency.md) | 문서는 swift-docc-plugin과 RIBs.docc 카탈로그로 만든다 | 채택 |
| [0013](ADR-0013-web-session-storage-restore.md) | 웹 샘플은 sessionStorage에 RibState를 저장하고 새로고침 때 복원한다 | 채택 |
| [0015](ADR-0015-sample-root-package-name.md) | 샘플 패키지는 루트 패키지를 디렉터리 이름이 아닌 `RIBs` 이름으로 참조한다 | 채택 |
| [0016](ADR-0016-mount-and-ribstate-as-extensions.md) | `mount`/`RibMount`와 `RibState`를 RIBs-iOS 밖의 확장으로 유지한다 | 채택 |
