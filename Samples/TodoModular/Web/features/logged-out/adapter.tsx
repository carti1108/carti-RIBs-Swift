import { ReactScreen } from "../../support/react-screen";
import type { LoggedOutScreenHandle, LoggedOutViewBridge } from "../../support/swift";
import { LoggedOutView } from "./view";

/** 어댑터(ADR-0027). Swift `LoggedOutViewBridge`(Sources/TodoModularWeb/LoggedOutBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedOutAdapter implements LoggedOutViewBridge {
  #screen = new ReactScreen<LoggedOutScreenHandle>();

  mount(host: Element, handle: LoggedOutScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(errorMessage: string | null, isLoading: boolean): void {
    this.#screen.render((handle) => (
      <LoggedOutView
        errorMessage={errorMessage}
        isLoading={isLoading}
        onLogin={(rawName) => handle.loginTapped(rawName)}
      />
    ));
  }
}
