import RIBs

/// RIB 화면 트리를 문자열 하나로 그려 Android(Kotlin/Compose) 쪽에 넘기고, 사용자 입력을 화면 객체로 되돌린다(ADR-0010).
///
/// 화면 상태는 `RibState`의 JSON 인코딩을 그대로 쓴다. Kotlin은 `org.json`으로 읽는다.
/// 상태가 바뀔 때마다 트리 전체를 다시 그려 `sink`로 보낸다. 화면 수가 적은 샘플 규모를 전제로 한다.
@MainActor
public final class AndroidRenderer {
    /// 루트 화면이 없을 때 보내는 값.
    public static let emptyTree = "{}"

    private let sink: (String) -> Void
    private var root: AndroidScreen?
    private var screens: [Int64: WeakScreen] = [:]
    private var lastID: Int64 = 0

    /// `sink`는 그린 트리를 받는다. Android에서는 JNI로 Kotlin에 넘긴다.
    public init(sink: @escaping (String) -> Void) {
        self.sink = sink
    }

    /// 지금 트리의 인코딩. 테스트와 `sink`가 같은 값을 본다.
    public var encodedTree: String {
        root.map { $0.renderTree().encodedString() } ?? Self.emptyTree
    }

    public func render() {
        sink(encodedTree)
    }

    /// Kotlin이 보낸 입력을 화면에 전달한다. 화면이 이미 사라졌으면 false.
    @discardableResult
    public func dispatch(screenID: Int64, action: String, argument: String) -> Bool {
        guard let screen = screens[screenID]?.screen else {
            screens[screenID] = nil
            return false
        }
        screen.handle(action: action, argument: argument)
        return true
    }

    func makeScreenID() -> Int64 {
        lastID += 1
        return lastID
    }

    func register(_ screen: AndroidScreen) {
        screens = screens.filter { $0.value.screen != nil }
        screens[screen.id] = WeakScreen(screen: screen)
    }

    func setRoot(_ screen: AndroidScreen) {
        root = screen
        render()
    }

    func clearRoot(_ screen: AndroidScreen) {
        guard root === screen else { return }
        root = nil
        render()
    }
}

private struct WeakScreen {
    weak var screen: AndroidScreen?
}
