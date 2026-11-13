#if canImport(SwiftUI)
import RIBs
import SwiftUI

/// SwiftUI로 그릴 수 있는 RIB 뷰. 공유 코드의 뷰 계약(`XxxViewContract`)을 구현하는 화면 객체가 함께 채택한다.
///
/// 공유 코드는 자식 화면을 `any ViewControllable`로만 넘기므로, 부모 화면은 이 프로토콜로 바꿔 SwiftUI 뷰를 꺼낸다.
/// UIKit의 `uiviewController`와 같은 역할이다.
@MainActor
public protocol SwiftUIRenderable: ViewControllable {
    func makeView() -> AnyView
}
#endif
