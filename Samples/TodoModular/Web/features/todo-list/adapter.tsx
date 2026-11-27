import { ReactScreen } from "../../support/react-screen";
import type { ChannelHandle, ChannelViewBridge } from "../../support/swift";
import type { TodoListViewAction, TodoListViewState } from "../../support/generated/view-state";
import { TodoListView } from "./view";

function send(handle: ChannelHandle, action: TodoListViewAction): void {
  handle.dispatch(JSON.stringify(action));
}

/** 어댑터(ADR-0027). 단일 채널 `ChannelViewBridge`를 구현하고 생성 타입을 순수 뷰에 넘긴다. */
export class TodoListAdapter implements ChannelViewBridge {
  #screen = new ReactScreen<ChannelHandle>();

  mount(host: Element, handle: ChannelHandle): void {
    this.#screen.mount(host, handle);
  }

  setContent(_content: Element): void {}

  render(stateJSON: string): void {
    const state = JSON.parse(stateJSON) as TodoListViewState;
    this.#screen.render((handle) => (
      <TodoListView
        items={state.todos}
        isLoading={state.isLoading}
        errorMessage={state.errorMessage}
        notice={state.notice}
        onSelect={(id) => send(handle, { kind: "todoTapped", id })}
        onRetry={() => send(handle, { kind: "retryTapped" })}
        onFileReceived={(name, text) => send(handle, { kind: "fileReceived", name, text })}
      />
    ));
  }
}
