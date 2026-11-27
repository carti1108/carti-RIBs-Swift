import { ReactScreen } from "../../support/react-screen";
import type { ChannelHandle, ChannelViewBridge } from "../../support/swift";
import type { LoggedOutViewAction, LoggedOutViewState } from "../../support/generated/view-state";
import { LoggedOutView } from "./view";

function send(handle: ChannelHandle, action: LoggedOutViewAction): void {
  handle.dispatch(JSON.stringify(action));
}

/** 어댑터(ADR-0027). 단일 채널 `ChannelViewBridge`를 구현하고 생성 타입을 순수 뷰에 넘긴다. */
export class LoggedOutAdapter implements ChannelViewBridge {
  #screen = new ReactScreen<ChannelHandle>();

  mount(host: Element, handle: ChannelHandle): void {
    this.#screen.mount(host, handle);
  }

  setContent(_content: Element): void {}

  render(stateJSON: string): void {
    const state = JSON.parse(stateJSON) as LoggedOutViewState;
    this.#screen.render((handle) => (
      <LoggedOutView
        errorMessage={state.errorMessage}
        isLoading={state.isLoading}
        onLogin={(rawName) => send(handle, { kind: "loginTapped", rawName })}
      />
    ));
  }
}
