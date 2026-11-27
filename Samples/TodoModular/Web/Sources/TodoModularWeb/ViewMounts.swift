import FeatureLoggedInWeb
import FeatureLoggedOutWeb
import FeatureTodoDetailWeb
import FeatureTodoListWeb
import TodoWebSupport

/// 피처의 웹 화면과 단일 채널 뷰(`ChannelViewBridge`)를 잇는다.
/// 상태 직렬화와 액션 역직렬화는 `Generated/BridgeCodec.swift`가 맡는다.
@MainActor
enum ViewMounts {
    static func loggedOut(_ view: any ChannelViewBridge) -> LoggedOutWebViewFactory {
        LoggedOutWebViewFactory { screen in
            let handle = ChannelHandle { [weak screen] json in
                guard let action = try? decodeLoggedOutViewActionJSON(json) else { return }
                screen?.send(action)
            }
            view.mount(host: screen.element, content: nil, handle: handle)
            screen.attach { view.render(stateJSON: encodeLoggedOutViewStateJSON($0)) }
        }
    }

    static func loggedIn(_ view: any ChannelViewBridge) -> LoggedInWebViewFactory {
        LoggedInWebViewFactory { screen in
            let handle = ChannelHandle { [weak screen] json in
                guard let action = try? decodeLoggedInViewActionJSON(json) else { return }
                screen?.send(action)
            }
            view.mount(host: screen.element, content: screen.content, handle: handle)
            screen.attach { view.render(stateJSON: encodeLoggedInViewStateJSON($0)) }
        }
    }

    static func todoList(_ view: any ChannelViewBridge) -> TodoListWebViewFactory {
        TodoListWebViewFactory { screen in
            let handle = ChannelHandle { [weak screen] json in
                guard let action = try? decodeTodoListViewActionJSON(json) else { return }
                screen?.send(action)
            }
            view.mount(host: screen.element, content: nil, handle: handle)
            screen.attach { view.render(stateJSON: encodeTodoListViewStateJSON($0)) }
        }
    }

    static func todoDetail(_ view: any ChannelViewBridge) -> TodoDetailWebViewFactory {
        TodoDetailWebViewFactory { screen in
            let handle = ChannelHandle { [weak screen] json in
                guard let action = try? decodeTodoDetailViewActionJSON(json) else { return }
                screen?.send(action)
            }
            view.mount(host: screen.element, content: nil, handle: handle)
            screen.attach { view.render(stateJSON: encodeTodoDetailViewStateJSON($0)) }
        }
    }
}
