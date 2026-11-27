import BridgeGenCore
import Foundation
import Testing

@Suite("BridgeGenCore")
struct BridgeGenTests {
    @Test("LoggedOut Interface를 파싱한다")
    func parsesLoggedOutInterface() throws {
        let source = """
        public struct LoggedOutViewState: Equatable, Sendable {
            public var errorMessage: String?
            public var isLoading: Bool
        }
        public enum LoggedOutViewAction: Equatable, Sendable {
            case loginTapped(rawName: String)
        }
        public protocol LoggedOutViewControllable: ViewControllable {}
        """

        let spec = try ContractParser.parseFeature(
            featureName: "LoggedOut",
            interfaceSource: source,
            modelSources: []
        )

        #expect(spec.featureName == "LoggedOut")
        #expect(spec.hasChildSlots == false)
        #expect(spec.stateFields == [
            ValueField(name: "errorMessage", type: .optional(.primitive(.string))),
            ValueField(name: "isLoading", type: .primitive(.bool)),
        ])
        #expect(spec.actions == [
            ActionCase(name: "loginTapped", params: [
                ActionParam(label: "rawName", name: "rawName", type: .primitive(.string)),
            ]),
        ])
    }

    @Test("외부 struct 배열과 자식 슬롯을 파싱한다")
    func parsesArrayModelAndChildSlots() throws {
        let todoModel = """
        public struct Todo: Identifiable, Equatable, Sendable {
            public let id: Int64
            public let title: String
            public let isDone: Bool
        }
        """
        let todoListInterface = """
        public struct TodoListViewState: Equatable, Sendable {
            public var todos: [Todo]
            public var isLoading: Bool
            public var errorMessage: String?
            public var notice: String?
        }
        public enum TodoListViewAction: Equatable, Sendable {
            case todoTapped(id: Int64)
            case retryTapped
            case fileReceived(name: String, text: String)
        }
        public protocol TodoListViewControllable: ViewControllable {}
        """
        let loggedInInterface = """
        public struct LoggedInViewState: Equatable, Sendable {
            public var userName: String
            public var sessionSeconds: Int64
        }
        public enum LoggedInViewAction: Equatable, Sendable {
            case logoutTapped
            case detailDismissedByUser
        }
        public protocol LoggedInViewControllable: ViewControllable {
            func showList(_ screen: any ViewControllable)
            func showDetail(_ screen: any ViewControllable)
        }
        """

        let todoSpec = try ContractParser.parseFeature(
            featureName: "TodoList",
            interfaceSource: todoListInterface,
            modelSources: [todoModel]
        )
        #expect(todoSpec.referencedStructs["Todo"] == ValueStructSpec(
            name: "Todo",
            fields: [
                ValueField(name: "id", type: .primitive(.int64)),
                ValueField(name: "title", type: .primitive(.string)),
                ValueField(name: "isDone", type: .primitive(.bool)),
            ]
        ))

        let loggedInSpec = try ContractParser.parseFeature(
            featureName: "LoggedIn",
            interfaceSource: loggedInInterface,
            modelSources: []
        )
        #expect(loggedInSpec.hasChildSlots == true)
    }

    @Test("Android Handle 생성은 커스텀 배열을 알림+pull 패턴으로 분리한다")
    func generatesAndroidHandleWithPullArray() {
        let spec = FeatureBridgeSpec(
            featureName: "TodoList",
            stateFields: [
                ValueField(name: "todos", type: .array(.customStruct(name: "Todo"))),
                ValueField(name: "isLoading", type: .primitive(.bool)),
                ValueField(name: "errorMessage", type: .optional(.primitive(.string))),
                ValueField(name: "notice", type: .optional(.primitive(.string))),
            ],
            actions: [
                ActionCase(name: "todoTapped", params: [
                    ActionParam(label: "id", name: "id", type: .primitive(.int64)),
                ]),
                ActionCase(name: "retryTapped"),
                ActionCase(name: "fileReceived", params: [
                    ActionParam(label: "name", name: "name", type: .primitive(.string)),
                    ActionParam(label: "text", name: "text", type: .primitive(.string)),
                ]),
            ],
            hasChildSlots: false,
            referencedStructs: [
                "Todo": ValueStructSpec(name: "Todo", fields: [
                    ValueField(name: "id", type: .primitive(.int64)),
                    ValueField(name: "title", type: .primitive(.string)),
                    ValueField(name: "isDone", type: .primitive(.bool)),
                ]),
            ]
        )

        let code = AndroidBridgeGenerator.generateHandle(for: spec)

        #expect(code.contains("public struct TodoListTodo: Sendable"))
        #expect(code.contains("func render(isLoading: Bool, errorMessage: String?, notice: String?)"))
        #expect(code.contains("func todosChanged()"))
        #expect(code.contains("public func todos() -> [TodoListTodo]"))
        #expect(code.contains("public func todoTapped(id: Int64)"))
        #expect(code.contains("public func retryTapped()"))
        #expect(code.contains("public func fileReceived(name: String, text: String)"))
    }

    @Test("Web Bridge와 ViewMounts 생성은 Int64를 Int로 바꾸고 자식 슬롯 mount를 처리한다")
    func generatesWebBridgeAndViewMounts() {
        let loggedIn = FeatureBridgeSpec(
            featureName: "LoggedIn",
            stateFields: [
                ValueField(name: "userName", type: .primitive(.string)),
                ValueField(name: "sessionSeconds", type: .primitive(.int64)),
            ],
            actions: [
                ActionCase(name: "logoutTapped"),
                ActionCase(name: "detailDismissedByUser"),
            ],
            hasChildSlots: true
        )

        let bridge = WebBridgeGenerator.generateBridge(for: loggedIn)
        #expect(bridge.contains("func mount(host: JSObject, content: JSObject, handle: LoggedInScreenHandle)"))
        #expect(bridge.contains("func render(userName: String, sessionSeconds: Int)"))
        #expect(bridge.contains("@JS func detailDismissedByUser()"))

        let mounts = WebBridgeGenerator.generateViewMounts(for: [loggedIn])
        #expect(mounts.contains("view.mount(host: screen.element, content: screen.content, handle: handle)"))
        #expect(mounts.contains("sessionSeconds: Int(state.sessionSeconds)"))
    }

    @Test("DriftChecker는 누락된 상태 필드와 액션을 감지한다")
    func detectsDriftBetweenSpecAndExistingBridge() {
        let spec = FeatureBridgeSpec(
            featureName: "TodoDetail",
            stateFields: [
                ValueField(name: "title", type: .primitive(.string)),
                ValueField(name: "isDone", type: .primitive(.bool)),
                ValueField(name: "notice", type: .optional(.primitive(.string))),
            ],
            actions: [
                ActionCase(name: "toggleDoneTapped"),
                ActionCase(name: "backTapped"),
                ActionCase(name: "titleCopied", params: [
                    ActionParam(label: "succeeded", name: "succeeded", type: .primitive(.bool)),
                ]),
            ],
            hasChildSlots: false
        )

        let existingAndroidHandle = """
        public protocol TodoDetailViewBridge {
            func render(title: String, isDone: Bool)
        }
        public final class TodoDetailScreenHandle: Sendable {
            public func toggleDoneTapped() {}
            public func backTapped() {}
        }
        """

        let issues = DriftChecker.checkAndroidHandle(spec: spec, handleSource: existingAndroidHandle)
        #expect(issues == [
            DriftIssue(platform: "Android", feature: "TodoDetail", kind: "state field", symbol: "notice"),
            DriftIssue(platform: "Android", feature: "TodoDetail", kind: "action", symbol: "titleCopied"),
        ])
    }
}
