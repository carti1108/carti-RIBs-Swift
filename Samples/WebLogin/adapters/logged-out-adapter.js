// 어댑터(ADR-0027). Swift `LoggedOutViewBridge`(Sources/WebLogin/LoggedOutBridge.swift)를 구현하고 값을 순수 뷰(views/logged-out-view.js)에 넘긴다.
// 타입은 BridgeJS가 만든 bridge-js.d.ts를 따른다. 화면 종류마다 어댑터는 하나이고, 가장 최근에 mount한 화면에 그린다.
import { createLoggedOutView } from "../views/logged-out-view.js";

export class LoggedOutAdapter {
  #view = null;

  mount(host, handle) {
    this.#view = createLoggedOutView(host, { onLogin: (rawName) => handle.loginTapped(rawName) });
  }

  render(errorMessage, isLoading) {
    this.#view?.render({ errorMessage, isLoading });
  }
}
