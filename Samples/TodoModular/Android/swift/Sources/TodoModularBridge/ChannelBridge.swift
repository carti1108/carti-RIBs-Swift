import FeatureLoggedInAndroid
import FeatureLoggedOutAndroid
import FeatureTodoDetailAndroid
import FeatureTodoListAndroid

/// 단일 채널 Android 브리지 라우터.
/// `kind` 문자열은 각 피처 `XxxAndroidViewFactory.kind`와 같고, `BridgeCodec.swift`의 인코더/디코더를 부른다.
@MainActor
enum AndroidScreenChannel {
    static func attach(screenID: Int64, kind: String, onState: @escaping @MainActor (String) -> Void) {
        switch kind {
        case "loggedOut":
            controller?.screen(id: screenID, as: LoggedOutAndroidScreen.self)?.attach {
                onState(encodeLoggedOutViewStateJSON($0))
            }
        case "loggedIn":
            controller?.screen(id: screenID, as: LoggedInAndroidScreen.self)?.attach {
                onState(encodeLoggedInViewStateJSON($0))
            }
        case "todoList":
            controller?.screen(id: screenID, as: TodoListAndroidScreen.self)?.attach {
                onState(encodeTodoListViewStateJSON($0))
            }
        case "todoDetail":
            controller?.screen(id: screenID, as: TodoDetailAndroidScreen.self)?.attach {
                onState(encodeTodoDetailViewStateJSON($0))
            }
        default:
            break
        }
    }

    static func detach(screenID: Int64, kind: String) {
        switch kind {
        case "loggedOut":
            controller?.screen(id: screenID, as: LoggedOutAndroidScreen.self)?.detach()
        case "loggedIn":
            controller?.screen(id: screenID, as: LoggedInAndroidScreen.self)?.detach()
        case "todoList":
            controller?.screen(id: screenID, as: TodoListAndroidScreen.self)?.detach()
        case "todoDetail":
            controller?.screen(id: screenID, as: TodoDetailAndroidScreen.self)?.detach()
        default:
            break
        }
    }

    static func dispatch(screenID: Int64, kind: String, actionJSON: String) {
        switch kind {
        case "loggedOut":
            guard let action = try? decodeLoggedOutViewActionJSON(actionJSON) else { return }
            controller?.screen(id: screenID, as: LoggedOutAndroidScreen.self)?.send(action)
        case "loggedIn":
            guard let action = try? decodeLoggedInViewActionJSON(actionJSON) else { return }
            controller?.screen(id: screenID, as: LoggedInAndroidScreen.self)?.send(action)
        case "todoList":
            guard let action = try? decodeTodoListViewActionJSON(actionJSON) else { return }
            controller?.screen(id: screenID, as: TodoListAndroidScreen.self)?.send(action)
        case "todoDetail":
            guard let action = try? decodeTodoDetailViewActionJSON(actionJSON) else { return }
            controller?.screen(id: screenID, as: TodoDetailAndroidScreen.self)?.send(action)
        default:
            break
        }
    }
}
