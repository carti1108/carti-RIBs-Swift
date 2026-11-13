import RIBs

/// Android에서 그리는 RIB 뷰의 기반 클래스. 공유 코드의 뷰 계약(`XxxViewContract`)을 구현하는 화면이 상속한다.
///
/// 화면은 자기 상태를 `state()`로 내놓고, 바뀌면 `setNeedsRender()`를 부른다.
/// Kotlin 입력은 `handle(action:argument:)`로 들어온다. SwiftUI 어댑터의 `SwiftUIRenderable`과 같은 자리다.
@MainActor
open class AndroidScreen: ViewControllable {
    /// Kotlin이 어떤 Composable로 그릴지 고르는 이름.
    public let kind: String
    /// 렌더러 안에서 유일한 번호. Kotlin이 입력을 돌려줄 때 쓴다.
    public let id: Int64
    private weak var renderer: AndroidRenderer?

    public init(kind: String, renderer: AndroidRenderer) {
        precondition(!kind.isEmpty, "AndroidScreen kind must not be empty")
        self.kind = kind
        self.renderer = renderer
        id = renderer.makeScreenID()
        renderer.register(self)
    }

    /// 화면 고유 상태. `id`, `kind` 키는 렌더러가 채우므로 쓰지 않는다.
    open func state() -> [String: RibValue] { [:] }

    /// Kotlin 입력. 모르는 동작은 무시한다.
    open func handle(action: String, argument: String) {}

    public final func setNeedsRender() {
        renderer?.render()
    }

    final func renderTree() -> RibState {
        var values = state()
        precondition(values["id"] == nil && values["kind"] == nil, "\(type(of: self)).state() must not use reserved keys id/kind")
        values["id"] = .int(id)
        values["kind"] = .string(kind)
        return RibState(values)
    }
}
