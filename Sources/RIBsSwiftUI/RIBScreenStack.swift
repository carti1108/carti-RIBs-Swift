#if canImport(SwiftUI)
import Observation
import RIBs
import SwiftUI

/// `NavigationStack`의 path에 넣는 항목. RIB 화면 객체의 정체성으로 비교한다.
public struct RIBStackEntry: Hashable {
    public let screen: any SwiftUIRenderable
    private let id: ObjectIdentifier

    @MainActor
    init(_ screen: any SwiftUIRenderable) {
        self.screen = screen
        self.id = ObjectIdentifier(screen)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 바닥 화면 하나와 그 위에 쌓인 화면들. `RIBStackView`가 `NavigationStack`으로 그린다.
///
/// Router가 부르는 `push`/`pop`과 사용자가 스와이프·뒤로 버튼으로 닫는 경로가 모두 이 path로 모인다.
/// 사용자가 닫은 화면은 `onDismissedByUser`로 알리고, 뒤이어 Router가 부르는 `pop`은 아무 일도 하지 않는다.
@MainActor
@Observable
public final class RIBScreenStack {
    public private(set) var root: (any SwiftUIRenderable)?
    public private(set) var path: [RIBStackEntry] = []
    @ObservationIgnored public var onDismissedByUser: ((any SwiftUIRenderable) -> Void)?

    public init() {}

    public func setRoot(_ screen: any SwiftUIRenderable) {
        root = screen
    }

    /// 이미 쌓여 있는 화면이면 무시한다.
    public func push(_ screen: any SwiftUIRenderable) {
        let entry = RIBStackEntry(screen)
        guard !path.contains(entry) else { return }
        path.append(entry)
    }

    /// 쌓여 있지 않은 화면이면 무시한다.
    public func pop(_ screen: any SwiftUIRenderable) {
        path.removeAll { $0 == RIBStackEntry(screen) }
    }

    /// SwiftUI가 path 바인딩에 쓴 값을 받는다. 사용자는 화면을 빼기만 할 수 있으므로 없던 항목은 버린다.
    public func userDidChangePath(to newPath: [RIBStackEntry]) {
        let kept = path.filter(newPath.contains)
        let removed = path.filter { !newPath.contains($0) }
        guard !removed.isEmpty else { return }
        path = kept
        for entry in removed.reversed() {
            onDismissedByUser?(entry.screen)
        }
    }
}

/// `RIBScreenStack`을 `NavigationStack`으로 그린다. 바닥 화면이 없으면 빈 스택이다.
public struct RIBStackView: View {
    private let stack: RIBScreenStack

    public init(stack: RIBScreenStack) {
        self.stack = stack
    }

    public var body: some View {
        NavigationStack(path: Binding(get: { stack.path }, set: { stack.userDidChangePath(to: $0) })) {
            Group {
                if let root = stack.root {
                    // 같은 타입의 새 RIB 화면으로 바뀌어도 이전 화면의 @State가 남지 않도록 객체마다 정체성을 준다.
                    root.makeView().id(ObjectIdentifier(root))
                }
            }
            .navigationDestination(for: RIBStackEntry.self) { $0.screen.makeView() }
        }
    }
}
#endif
