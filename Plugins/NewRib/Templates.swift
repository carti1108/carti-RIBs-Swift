enum Templates {
    /// 두 모드가 함께 쓰는 뷰 계약. 상태 하나를 그리고 액션 하나를 받는다(ADR-0025의 모양).
    private static func viewContract(_ n: String) -> String {
        """
        /// 화면에 그릴 값 전체. 플랫폼은 이 값만 보고 그린다.
        public struct \(n)ViewState: Equatable, Sendable {
            public var title: String

            public init(title: String = "") {
                self.title = title
            }
        }

        /// 뷰 → 공유 코드: 사용자 입력. case 이름은 일어난 일로 짓는다.
        public enum \(n)ViewAction: Equatable, Sendable {
            case closeTapped
        }

        @MainActor
        public protocol \(n)PresentableListener: AnyObject {
            func handle(_ action: \(n)ViewAction)
        }

        /// Interactor → 뷰: 플랫폼이 구현하는 뷰 계약.
        @MainActor
        public protocol \(n)Presentable: Presentable {
            /// 활성 구간에만 설정된다. 플랫폼은 `weak`로 둔다.
            var listener: (any \(n)PresentableListener)? { get set }
            func render(_ state: \(n)ViewState)
        }

        /// Router → 뷰. 자식 화면을 붙일 때 메서드를 추가한다.
        @MainActor
        public protocol \(n)ViewControllable: ViewControllable {}

        /// 플랫폼 뷰 하나가 구현하는 묶음. Interactor는 `\(n)Presentable`로, Router는 `\(n)ViewControllable`로만 본다.
        @MainActor
        public protocol \(n)ViewContract: \(n)Presentable, \(n)ViewControllable {}
        """
    }

    /// Interactor 본문. 접근 수준만 모드마다 다르다.
    private static func interactor(_ n: String, access: String) -> String {
        """
        \(access)final class \(n)Interactor: PresentableInteractor<any \(n)Presentable>, \(n)PresentableListener {
            private weak var listener: (any \(n)Listener)?
            private var viewState = \(n)ViewState(title: "\(n)")

            \(access)init(presenter: any \(n)Presentable, listener: any \(n)Listener) {
                self.listener = listener
                super.init(presenter: presenter)
            }

            \(access)override func didBecomeActive() {
                presenter.listener = self
                presenter.render(viewState)
            }

            \(access)override func willResignActive() {
                presenter.listener = nil
            }

            \(access)func handle(_ action: \(n)ViewAction) {
                switch action {
                case .closeTapped: listener?.didRequestClose\(n)()
                }
            }
        }
        """
    }

    private static func interactorTestBody(_ n: String, view: String, listener: String) -> String {
        """
            @Test func rendersInitialStateWhenActivated() {
                let view = \(view)()
                let interactor = \(n)Interactor(presenter: view, listener: \(listener)())

                interactor.activate()

                #expect(view.states == [\(n)ViewState(title: "\(n)")])
                interactor.deactivate()
                #expect(view.listener == nil)
            }

            @Test func closeIsForwardedToListener() {
                let view = \(view)()
                let listener = \(listener)()
                let interactor = \(n)Interactor(presenter: view, listener: listener)
                interactor.activate()

                view.listener?.handle(.closeTapped)

                #expect(listener.closeRequests == 1)
                interactor.deactivate()
            }
        """
    }

    // MARK: - 한 모듈 모드

    static func rib(_ n: String) -> String {
        """
        import RIBs

        \(viewContract(n))

        /// 부모가 제공해야 하는 것.
        @MainActor
        public protocol \(n)Dependency: Dependency {
            func make\(n)View() -> any \(n)ViewContract
        }

        /// 자식 → 부모: 사용자 의도로 표현한다. 라우팅은 부모가 정한다.
        @MainActor
        public protocol \(n)Listener: AnyObject {
            func didRequestClose\(n)()
        }

        public final class \(n)Builder: Builder<any \(n)Dependency> {
            public func build(listener: any \(n)Listener) -> \(n)Router {
                let view = dependency.make\(n)View()
                return \(n)Router(interactor: \(n)Interactor(presenter: view, listener: listener), viewController: view)
            }
        }

        \(interactor(n, access: "public "))

        public typealias \(n)Router = ViewableRouter<\(n)Interactor, any \(n)ViewControllable>

        """
    }

    static func ribTest(_ n: String, module: String) -> String {
        """
        import RIBs
        import Testing

        @testable import \(module)

        @MainActor
        struct \(n)InteractorTests {
            private final class FakeView: \(n)ViewContract {
                weak var listener: (any \(n)PresentableListener)?
                private(set) var states: [\(n)ViewState] = []
                func render(_ state: \(n)ViewState) { states.append(state) }
            }

            private final class FakeListener: \(n)Listener {
                private(set) var closeRequests = 0
                func didRequestClose\(n)() { closeRequests += 1 }
            }

        \(interactorTestBody(n, view: "FakeView", listener: "FakeListener"))
        }

        """
    }

    // MARK: - 피처 모드 (Interface · Impl · Testing · Tests)

    static func featureInterface(_ n: String) -> String {
        """
        import RIBs

        \(viewContract(n))

        /// 플랫폼이 이 피처의 뷰를 만들어 준다.
        @MainActor
        public protocol \(n)ViewFactory: AnyObject {
            func make\(n)View() -> any \(n)ViewContract
        }

        /// 부모가 제공해야 하는 서비스. 뷰 팩토리는 Builder가 따로 받는다.
        @MainActor
        public protocol \(n)Dependency: Dependency {}

        /// 자식 → 부모: 사용자 의도로 표현한다. 라우팅은 부모가 정한다.
        @MainActor
        public protocol \(n)Listener: AnyObject {
            func didRequestClose\(n)()
        }

        /// 부모는 이 프로토콜만 안다. 구현(`\(n)Builder`)은 조립 모듈이 만들어 넘긴다.
        @MainActor
        public protocol \(n)Buildable: Buildable {
            func build(listener: any \(n)Listener) -> any ViewableRouting
        }

        """
    }

    static func featureImpl(_ n: String, module: String) -> String {
        """
        import \(module)Interface
        import RIBs

        public final class \(n)Builder: Builder<any \(n)Dependency>, \(n)Buildable {
            private let viewFactory: any \(n)ViewFactory

            public init(dependency: any \(n)Dependency, viewFactory: any \(n)ViewFactory) {
                self.viewFactory = viewFactory
                super.init(dependency: dependency)
            }

            public func build(listener: any \(n)Listener) -> any ViewableRouting {
                let view = viewFactory.make\(n)View()
                return \(n)Router(interactor: \(n)Interactor(presenter: view, listener: listener), viewController: view)
            }
        }

        \(interactor(n, access: ""))

        typealias \(n)Router = ViewableRouter<\(n)Interactor, any \(n)ViewControllable>

        """
    }

    static func featureFakes(_ n: String, module: String) -> String {
        """
        import \(module)Interface
        import RIBs

        @MainActor
        public final class Fake\(n)View: \(n)ViewContract {
            public weak var listener: (any \(n)PresentableListener)?
            /// 그려진 상태를 순서대로 모은다.
            public private(set) var states: [\(n)ViewState] = []
            public var state: \(n)ViewState? { states.last }

            public init() {}

            public func render(_ state: \(n)ViewState) { states.append(state) }
        }

        @MainActor
        public final class Fake\(n)ViewFactory: \(n)ViewFactory {
            public private(set) var views: [Fake\(n)View] = []

            public init() {}

            public func make\(n)View() -> any \(n)ViewContract {
                let view = Fake\(n)View()
                views.append(view)
                return view
            }
        }

        @MainActor
        public final class Fake\(n)Listener: \(n)Listener {
            public private(set) var closeRequests = 0

            public init() {}

            public func didRequestClose\(n)() { closeRequests += 1 }
        }

        @MainActor
        public final class Fake\(n)Dependency: \(n)Dependency {
            public init() {}
        }

        /// 부모 피처 테스트용. 실제 로직 없이 빈 화면 Router를 돌려주고, 받은 리스너를 기록한다.
        @MainActor
        public final class Fake\(n)Buildable: \(n)Buildable {
            public private(set) var listeners: [any \(n)Listener] = []
            public private(set) var views: [Fake\(n)View] = []

            public init() {}

            public func build(listener: any \(n)Listener) -> any ViewableRouting {
                listeners.append(listener)
                let view = Fake\(n)View()
                views.append(view)
                return ViewableRouter<Interactor, Fake\(n)View>(interactor: Interactor(), viewController: view)
            }
        }

        """
    }

    static func featureTest(_ n: String, module: String) -> String {
        """
        import \(module)Interface
        import \(module)Testing
        import RIBs
        import Testing

        @testable import \(module)

        /// \(n) 피처 단독 테스트. 부모와 다른 피처 없이 돈다.
        @MainActor
        struct \(n)Tests {
        \(interactorTestBody(n, view: "Fake\(n)View", listener: "Fake\(n)Listener"))

            @Test func builderMakesOneViewPerBuild() {
                let views = Fake\(n)ViewFactory()
                let builder = \(n)Builder(dependency: Fake\(n)Dependency(), viewFactory: views)

                let router = builder.build(listener: Fake\(n)Listener())

                #expect(views.views.count == 1)
                #expect(router.viewControllable === views.views.first)
            }
        }

        """
    }

    // MARK: - SwiftUI: 순수 뷰와 어댑터 (ADR-0027)

    static func pureView(_ n: String, isPublic: Bool) -> String {
        let access = isPublic ? "public " : ""
        let initializer = isPublic ? """

            public init(title: String, onClose: @escaping () -> Void) {
                self.title = title
                self.onClose = onClose
            }

        """ : ""
        return """
        import SwiftUI

        /// \(n) 화면의 순수 뷰. 값과 콜백만 받아 그린다. 공유 코드와 RIBs를 import하지 않는다.
        \(access)struct \(n)View: View {
            let title: String
            let onClose: () -> Void
        \(initializer)
            \(access)var body: some View {
                VStack(spacing: 16) {
                    Text(title).font(.title.bold())
                    Button("닫기", action: onClose)
                }
                .padding(24)
            }
        }

        #Preview {
            \(n)View(title: "\(n)", onClose: {})
        }

        """
    }

    /// `viewModule`이 nil이면 순수 뷰와 같은 모듈에 둔다(한 모듈 모드).
    static func adapter(_ n: String, contractModule: String, viewModule: String?) -> String {
        let viewImport = viewModule.map { "import \($0)\n" } ?? ""
        let factory = viewModule == nil ? "" : """

        /// \(n) 피처의 어댑터를 만든다. 조립 모듈이 `\(n)Builder`에 넘긴다.
        @MainActor
        public final class \(n)ScreenFactory: \(n)ViewFactory {
            public init() {}

            public func make\(n)View() -> any \(n)ViewContract { \(n)Screen() }
        }

        """
        return """
        import \(contractModule)
        \(viewImport)import Observation
        import RIBs
        import RIBsSwiftUI
        import SwiftUI
        \(factory)
        /// \(n) RIB의 어댑터. 뷰 계약을 구현하고, 받은 상태를 풀어 순수 뷰(`\(n)View`)에 넘긴다.
        @MainActor
        final class \(n)Screen: \(n)ViewContract, SwiftUIRenderable {
            weak var listener: (any \(n)PresentableListener)?
            private let model = \(n)Model()

            func render(_ state: \(n)ViewState) { model.state = state }

            func makeView() -> AnyView {
                AnyView(\(n)Content(model: model) { [weak self] action in self?.listener?.handle(action) })
            }
        }

        @MainActor @Observable
        final class \(n)Model {
            var state = \(n)ViewState()
        }

        /// 모델을 관찰해 순수 뷰를 다시 그린다. 상태를 인자로 풀고 콜백을 액션으로 묶는다.
        private struct \(n)Content: View {
            let model: \(n)Model
            let send: (\(n)ViewAction) -> Void

            var body: some View {
                \(n)View(title: model.state.title) { send(.closeTapped) }
            }
        }

        """
    }
}
