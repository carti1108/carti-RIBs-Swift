enum Templates {
    static func rib(_ n: String) -> String {
        """
        import RIBs

        /// 뷰 → 공유 코드: 사용자 입력.
        @MainActor
        public protocol \(n)PresentableListener: AnyObject {
            func didTapClose()
        }

        /// Interactor → 뷰: 플랫폼이 구현하는 뷰 계약.
        @MainActor
        public protocol \(n)Presentable: Presentable {
            /// 활성 구간에만 설정된다. 플랫폼은 `weak`로 둔다.
            var listener: (any \(n)PresentableListener)? { get set }
            func showTitle(_ title: String)
        }

        /// Router → 뷰. 자식 화면을 붙일 때 메서드를 추가한다.
        @MainActor
        public protocol \(n)ViewControllable: ViewControllable {}

        /// 플랫폼 뷰 하나가 구현하는 묶음. Interactor는 `\(n)Presentable`로, Router는 `\(n)ViewControllable`로만 본다.
        @MainActor
        public protocol \(n)ViewContract: \(n)Presentable, \(n)ViewControllable {}

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

        public final class \(n)Interactor: PresentableInteractor<any \(n)Presentable>, \(n)PresentableListener {
            private weak var listener: (any \(n)Listener)?

            public init(presenter: any \(n)Presentable, listener: any \(n)Listener) {
                self.listener = listener
                super.init(presenter: presenter)
            }

            public override func didBecomeActive() {
                presenter.listener = self
                presenter.showTitle("\(n)")
            }

            public override func willResignActive() {
                presenter.listener = nil
            }

            public func didTapClose() {
                listener?.didRequestClose\(n)()
            }
        }

        public typealias \(n)Router = ViewableRouter<\(n)Interactor, any \(n)ViewControllable>

        """
    }

    static func test(_ n: String, module: String) -> String {
        """
        import RIBs
        import Testing
        @testable import \(module)

        @MainActor
        struct \(n)InteractorTests {
            private final class FakeView: \(n)ViewContract {
                weak var listener: (any \(n)PresentableListener)?
                var title: String?
                func showTitle(_ title: String) { self.title = title }
            }

            private final class FakeListener: \(n)Listener {
                var closeCount = 0
                func didRequestClose\(n)() { closeCount += 1 }
            }

            @Test func activationShowsTitleAndCloseIsForwarded() {
                // Given
                let view = FakeView()
                let listener = FakeListener()
                let interactor = \(n)Interactor(presenter: view, listener: listener)

                // When
                interactor.activate()
                view.listener?.didTapClose()

                // Then
                #expect(view.title == "\(n)")
                #expect(listener.closeCount == 1)

                interactor.deactivate()
                #expect(view.listener == nil)
            }
        }

        """
    }

    static func swiftUIScreen(_ n: String, module: String) -> String {
        """
        import \(module)
        import Observation
        import RIBsSwiftUI
        import SwiftUI

        /// \(n) RIB의 SwiftUI 뷰.
        @MainActor
        @Observable
        final class \(n)Screen: \(n)ViewContract, SwiftUIRenderable {
            @ObservationIgnored weak var listener: (any \(n)PresentableListener)?
            private(set) var title = ""

            func showTitle(_ title: String) { self.title = title }

            func makeView() -> AnyView { AnyView(\(n)View(screen: self)) }
        }

        private struct \(n)View: View {
            let screen: \(n)Screen

            var body: some View {
                VStack(spacing: 16) {
                    Text(screen.title).font(.title.bold())
                    Button("닫기") { screen.listener?.didTapClose() }
                }
                .padding(24)
            }
        }

        """
    }
}
