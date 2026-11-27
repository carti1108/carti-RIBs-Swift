import { ReactScreen } from "../../support/react-screen";
import type { ChannelHandle, ChannelViewBridge } from "../../support/swift";
import type { TodoDetailViewAction, TodoDetailViewState } from "../../support/generated/view-state";
import { TodoDetailView } from "./view";

function send(handle: ChannelHandle, action: TodoDetailViewAction): void {
  handle.dispatch(JSON.stringify(action));
}

/** 어댑터(ADR-0027). 단일 채널 `ChannelViewBridge`를 구현하고 생성 타입을 순수 뷰에 넘긴다. */
export class TodoDetailAdapter implements ChannelViewBridge {
  #screen = new ReactScreen<ChannelHandle>();

  mount(host: Element, handle: ChannelHandle): void {
    this.#screen.mount(host, handle);
  }

  setContent(_content: Element): void {}

  render(stateJSON: string): void {
    const state = JSON.parse(stateJSON) as TodoDetailViewState;
    this.#screen.render((handle) => (
      <TodoDetailView
        title={state.title}
        isDone={state.isDone}
        notice={state.notice}
        onBack={() => send(handle, { kind: "backTapped" })}
        onToggleDone={() => send(handle, { kind: "toggleDoneTapped" })}
        onTitleCopied={(succeeded) => send(handle, { kind: "titleCopied", succeeded })}
      />
    ));
  }
}
