import RIBs
import RIBsWeb
import Testing

@MainActor
struct WebScreenSlotTests {
    private final class Screen: ViewControllable {}

    @MainActor
    private final class ChangeRecorder {
        var received: [ObjectIdentifier?] = []
        func record(_ screen: (any ViewControllable)?) { received.append(screen.map(ObjectIdentifier.init)) }
    }

    @Test func showReplacesCurrentScreen() {
        let slot = WebScreenSlot()
        let first = Screen()
        let second = Screen()

        slot.show(first)
        slot.show(second)

        #expect(slot.current === second)
    }

    @Test func hideIgnoresScreenThatIsNoLongerShown() {
        let slot = WebScreenSlot()
        let first = Screen()
        let second = Screen()
        slot.show(first)
        slot.show(second)

        slot.hide(first)

        #expect(slot.current === second)
    }

    @Test func hideClearsCurrentScreen() {
        let slot = WebScreenSlot()
        let screen = Screen()
        slot.show(screen)

        slot.hide(screen)

        #expect(slot.current == nil)
    }

    @Test func observeDeliversCurrentScreenImmediatelyAndOnEveryChange() {
        let slot = WebScreenSlot()
        let first = Screen()
        let second = Screen()
        slot.show(first)
        let recorder = ChangeRecorder()

        let subscription = slot.observe(recorder.record)
        slot.show(second)
        slot.hide(second)

        #expect(recorder.received == [ObjectIdentifier(first), ObjectIdentifier(second), nil])
        subscription.cancel()
    }

    @Test func observerIsNotNotifiedWhenSameScreenIsShownAgainOrStaleScreenIsHidden() {
        let slot = WebScreenSlot()
        let first = Screen()
        let second = Screen()
        slot.show(first)
        let recorder = ChangeRecorder()
        let subscription = slot.observe(recorder.record)

        slot.show(first)
        slot.hide(second)

        #expect(recorder.received == [ObjectIdentifier(first)])
        subscription.cancel()
    }

    @Test func cancelledSubscriptionStopsReceivingChanges() {
        let slot = WebScreenSlot()
        let recorder = ChangeRecorder()
        let subscription = slot.observe(recorder.record)

        subscription.cancel()
        slot.show(Screen())

        #expect(recorder.received == [nil])
    }

    @Test func viewHostShowsAndHidesRootViewThroughItsSlot() {
        let host = WebViewHost<Screen>()
        let root = Screen()

        host.show(root)
        #expect(host.slot.current === root)

        host.hide(root)
        #expect(host.slot.current == nil)
    }
}
