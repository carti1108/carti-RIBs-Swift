import BridgeGenCore
import Testing

@Suite("BridgeGenCore")
struct BridgeGenTests {
    @Test("TodoModular 스타일 struct·배열을 파싱해 Swift/TS/Kotlin을 생성한다")
    func generatesTodoModularSchema() throws {
        let todoModel = """
        public struct Todo: Identifiable, Equatable, Sendable {
            public let id: Int64
            public let title: String
            public let isDone: Bool
        }
        """
        let todoListInterface = """
        import RIBs
        import TodoCore

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
        """

        let schema = try ContractParser.parseSchema(
            features: [
                FeatureInput(
                    featureName: "TodoList",
                    interfaceModule: "FeatureTodoListInterface",
                    interfaceSource: todoListInterface
                ),
            ],
            modelSources: [todoModel]
        )

        let swiftCode = SwiftChannelGenerator.generate(schema: schema)
        #expect(swiftCode.contains("func encodeTodoListViewStateJSON(_ value: TodoListViewState) -> String"))
        #expect(swiftCode.contains("func decodeTodoListViewActionJSON(_ json: String) throws -> TodoListViewAction"))

        let tsCode = TypeScriptGenerator.generate(schema: schema)
        #expect(tsCode.contains("export type Todo = {"))
        #expect(tsCode.contains("export type TodoListViewState = {"))
        #expect(tsCode.contains("{ kind: \"fileReceived\"; name: string; text: string }"))

        let ktCode = KotlinGenerator.generate(schema: schema, packageName: "com.example.bridge")
        #expect(ktCode.contains("package com.example.bridge"))
        #expect(ktCode.contains("data class Todo("))
        #expect(ktCode.contains("data class TodoListViewState("))
        #expect(ktCode.contains("sealed interface TodoListViewAction"))
    }

    @Test("grep 스타일 중첩 연관값 enum과 단순 enum을 파싱한다")
    func parsesNestedAssociatedEnums() throws {
        let coreModel = """
        public enum AuthProvider: String, Equatable, Sendable {
            case google
            case github
        }
        public enum SignInFailureReason: Equatable, Sendable {
            case disconnected
            case timedOut
            case denied
        }
        """
        let loggedOutInterface = """
        import GrepCore
        import RIBs

        public struct LoggedOutViewState: Equatable, Sendable {
            public enum Notice: Equatable, Sendable {
                case cancelled
                case failed(SignInFailureReason)
                case expired
                case signedOut
            }
            public var notice: Notice?
            public var isSigningIn: Bool
        }
        public enum LoggedOutViewAction: Equatable, Sendable {
            case signInTapped(AuthProvider)
        }
        """

        let schema = try ContractParser.parseSchema(
            features: [
                FeatureInput(
                    featureName: "LoggedOut",
                    interfaceModule: "FeatureLoggedOutInterface",
                    interfaceSource: loggedOutInterface
                ),
            ],
            modelSources: [coreModel]
        )

        let swiftCode = SwiftChannelGenerator.generate(schema: schema)
        #expect(swiftCode.contains("encodeLoggedOutViewStateNotice"))
        #expect(swiftCode.contains("decodeAuthProvider"))

        let tsCode = TypeScriptGenerator.generate(schema: schema)
        #expect(tsCode.contains("export type AuthProvider = \"google\" | \"github\";"))
        #expect(tsCode.contains("export type LoggedOutViewStateNotice ="))
        #expect(tsCode.contains("{ kind: \"failed\"; value: SignInFailureReason }"))

        let ktCode = KotlinGenerator.generate(schema: schema, packageName: "com.unwrap.grep")
        #expect(ktCode.contains("enum class AuthProvider"))
        #expect(ktCode.contains("sealed interface LoggedOutViewStateNotice"))
        #expect(ktCode.contains("data class Failed("))
    }
}
