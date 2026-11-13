import RIBs
import Testing
@testable import RIBsAndroid

@MainActor
private final class LabelScreen: AndroidScreen {
    var text = ""
    private(set) var received: [(String, String)] = []

    init(renderer: AndroidRenderer) { super.init(kind: "label", renderer: renderer) }

    override func state() -> [String: RibValue] { ["text": .string(text)] }

    override func handle(action: String, argument: String) { received.append((action, argument)) }
}

@MainActor
private final class ContainerScreen: AndroidScreen {
    lazy var slot = AndroidScreenSlot(owner: self)

    init(renderer: AndroidRenderer) { super.init(kind: "container", renderer: renderer) }

    override func state() -> [String: RibValue] { ["child": slot.renderedValue] }
}

@MainActor
private final class Sink {
    var trees: [String] = []
}

@MainActor
struct AndroidRendererTests {
    fileprivate let sink = Sink()
    let renderer: AndroidRenderer

    init() {
        let sink = self.sink
        renderer = AndroidRenderer { sink.trees.append($0) }
    }

    @Test func emptyRendererEncodesEmptyObject() {
        #expect(renderer.encodedTree == "{}")
    }

    @Test func hostShowRendersRootWithIdAndKind() {
        let host = AndroidViewHost<LabelScreen>(renderer: renderer)
        let label = LabelScreen(renderer: renderer)
        label.text = "안녕"

        host.show(label)

        #expect(sink.trees == [#"{"id":\#(label.id),"kind":"label","text":"안녕"}"#])
    }

    @Test func hostHideOnlyClearsCurrentRoot() {
        let host = AndroidViewHost<LabelScreen>(renderer: renderer)
        let first = LabelScreen(renderer: renderer)
        let second = LabelScreen(renderer: renderer)
        host.show(first)
        host.show(second)

        host.hide(first)
        #expect(renderer.encodedTree.contains("\"id\":\(second.id)"))

        host.hide(second)
        #expect(sink.trees.last == "{}")
    }

    @Test func slotNestsChildAndRerendersOwner() throws {
        let container = ContainerScreen(renderer: renderer)
        AndroidViewHost<ContainerScreen>(renderer: renderer).show(container)
        let child = LabelScreen(renderer: renderer)

        container.slot.show(child)

        let tree = try RibState(decoding: try #require(sink.trees.last))
        #expect(tree["child"]?.stateValue?["kind"] == .string("label"))

        container.slot.hide(child)
        #expect(try RibState(decoding: try #require(sink.trees.last))["child"] == .null)
    }

    @Test func slotHideIgnoresScreenThatIsNotShown() {
        let container = ContainerScreen(renderer: renderer)
        let shown = LabelScreen(renderer: renderer)
        container.slot.show(shown)

        container.slot.hide(LabelScreen(renderer: renderer))

        #expect(container.slot.current === shown)
    }

    @Test func dispatchRoutesToLiveScreenAndRejectsDeadOne() {
        let label = LabelScreen(renderer: renderer)
        #expect(renderer.dispatch(screenID: label.id, action: "tap", argument: "x"))
        #expect(label.received.map(\.0) == ["tap"])
        #expect(label.received.map(\.1) == ["x"])

        var deadID: Int64 = 0
        do { deadID = LabelScreen(renderer: renderer).id }
        #expect(!renderer.dispatch(screenID: deadID, action: "tap", argument: ""))
    }

    @Test func screenIDsAreUnique() {
        let ids = (0..<5).map { _ in LabelScreen(renderer: renderer).id }
        #expect(Set(ids).count == 5)
    }

    @Test func mainLooperAttachIsNoOpOffAndroid() {
        #expect(AndroidMainLooper.attach() == false)
    }
}
