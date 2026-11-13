import RIBs

/// 루트 RIB 화면을 렌더러의 루트로 붙이는 `ViewHost`.
@MainActor
public final class AndroidViewHost<View: AndroidScreen>: ViewHost {
    private let renderer: AndroidRenderer

    public init(renderer: AndroidRenderer) {
        self.renderer = renderer
    }

    public func show(_ view: View) {
        renderer.setRoot(view)
    }

    public func hide(_ view: View) {
        renderer.clearRoot(view)
    }
}
