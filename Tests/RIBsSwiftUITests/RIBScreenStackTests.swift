#if canImport(SwiftUI)
import RIBs
import RIBsSwiftUI
import SwiftUI
import Testing

@MainActor
struct RIBScreenStackTests {
    private final class Screen: SwiftUIRenderable {
        func makeView() -> AnyView { AnyView(EmptyView()) }
    }

    private let stack = RIBScreenStack()
    private let dismissed = Dismissed()

    private final class Dismissed {
        var screens: [any SwiftUIRenderable] = []
    }

    init() {
        stack.onDismissedByUser = { [dismissed] in dismissed.screens.append($0) }
    }

    @Test func setRootReplacesRootAndKeepsPath() {
        let first = Screen()
        let second = Screen()
        let pushed = Screen()
        stack.setRoot(first)
        stack.push(pushed)

        stack.setRoot(second)

        #expect(stack.root === second)
        #expect(stack.path.map(\.screen).elementsEqual([pushed], by: ===))
    }

    @Test func pushAppendsAndIgnoresScreenAlreadyOnStack() {
        let first = Screen()
        let second = Screen()

        stack.push(first)
        stack.push(second)
        stack.push(first)

        #expect(stack.path.map(\.screen).elementsEqual([first, second], by: ===))
    }

    @Test func popRemovesScreenAndDoesNotReportIt() {
        let screen = Screen()
        stack.push(screen)

        stack.pop(screen)

        #expect(stack.path.isEmpty)
        #expect(dismissed.screens.isEmpty)
    }

    @Test func popIgnoresScreenThatIsNotOnStack() {
        let shown = Screen()
        stack.push(shown)

        stack.pop(Screen())

        #expect(stack.path.map(\.screen).elementsEqual([shown], by: ===))
    }

    /// 스와이프 뒤로 가기처럼 SwiftUI가 path를 줄이면 빠진 화면을 알린다. 뒤이은 `pop`은 아무 일도 하지 않는다.
    @Test func pathShortenedByUserReportsRemovedScreens() {
        let first = Screen()
        let second = Screen()
        stack.push(first)
        stack.push(second)

        stack.userDidChangePath(to: [stack.path[0]])

        #expect(stack.path.map(\.screen).elementsEqual([first], by: ===))
        #expect(dismissed.screens.elementsEqual([second], by: ===))

        stack.pop(second)
        #expect(stack.path.map(\.screen).elementsEqual([first], by: ===))
        #expect(dismissed.screens.count == 1)
    }

    /// 사용자는 화면을 더할 수 없다. path에 없던 항목이 들어오면 버린다.
    @Test func userCannotAddScreens() {
        let shown = Screen()
        stack.push(shown)
        let other = RIBScreenStack()
        other.push(Screen())

        stack.userDidChangePath(to: stack.path + other.path)

        #expect(stack.path.map(\.screen).elementsEqual([shown], by: ===))
        #expect(dismissed.screens.isEmpty)
    }
}
#endif
