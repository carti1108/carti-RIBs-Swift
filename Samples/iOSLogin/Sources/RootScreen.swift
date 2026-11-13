import LoginShared
import RIBs
import RIBsSwiftUI
import SwiftUI

/// 루트 RIB의 뷰. 자식 RIB 화면 하나를 보여 준다.
@MainActor
final class RootScreen: RootViewControllable, SwiftUIRenderable {
    private let slot = RIBScreenSlot()

    func showScreen(_ screen: any ViewControllable) { slot.show(screen) }
    func hideScreen(_ screen: any ViewControllable) { slot.hide(screen) }

    func makeView() -> AnyView {
        AnyView(RIBSlotView(slot: slot).animation(.default, value: slot.current.map(ObjectIdentifier.init)))
    }
}

/// 공유 코드가 RIB마다 요청하는 뷰를 SwiftUI 구현으로 만들어 준다.
@MainActor
final class SwiftUIViewFactory: LoginViewFactory {
    func makeRootView() -> RootScreen { RootScreen() }
    func makeLoggedOutView() -> any LoggedOutViewContract { LoggedOutScreen() }
    func makeLoggedInView() -> any LoggedInViewContract { LoggedInScreen() }
    func makeTodoListView() -> any TodoListViewContract { TodoListScreen() }
    func makeTodoDetailView() -> any TodoDetailViewContract { TodoDetailScreen() }
}
