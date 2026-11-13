#if canImport(SwiftUI)
import RIBs
import RIBsSwiftUI
import SwiftUI
import Testing

@MainActor
struct RIBScreenSlotTests {
    private final class Screen: SwiftUIRenderable {
        func makeView() -> AnyView { AnyView(EmptyView()) }
    }

    @Test func showReplacesCurrentScreen() {
        let slot = RIBScreenSlot()
        let first = Screen()
        let second = Screen()

        slot.show(first)
        slot.show(second)

        #expect(slot.current === second)
    }

    @Test func hideIgnoresScreenThatIsNoLongerShown() {
        let slot = RIBScreenSlot()
        let first = Screen()
        let second = Screen()
        slot.show(first)
        slot.show(second)

        slot.hide(first)

        #expect(slot.current === second)
    }

    @Test func hideClearsCurrentScreen() {
        let slot = RIBScreenSlot()
        let screen = Screen()
        slot.show(screen)

        slot.hide(screen)

        #expect(slot.current == nil)
    }

    @Test func opaqueViewControllableIsShownAsRenderable() {
        let slot = RIBScreenSlot()
        let screen: any ViewControllable = Screen()

        slot.show(screen)
        #expect(slot.current === screen)

        slot.hide(screen)
        #expect(slot.current == nil)
    }

    @Test func viewHostDrivesLaunchRouter() {
        let host = SwiftUIViewHost<Screen>()
        let root = LaunchRouter(interactor: Interactor(), viewController: Screen())

        root.launch(from: host)
        #expect(host.slot.current === root.viewController)
        #expect(root.interactable.isActive)

        root.shutdown()
        #expect(host.slot.current == nil)
        #expect(!root.interactable.isActive)
    }
}
#endif
