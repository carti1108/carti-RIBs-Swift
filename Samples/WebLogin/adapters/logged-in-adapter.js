// 어댑터(ADR-0027). Swift `LoggedInViewBridge`(Sources/WebLogin/LoggedInBridge.swift)를 구현하고 값을 순수 뷰(views/logged-in-view.js)에 넘긴다.
// 타입은 BridgeJS가 만든 bridge-js.d.ts를 따른다. 화면 종류마다 어댑터는 하나이고, 가장 최근에 mount한 화면에 그린다.
import { createLoggedInView } from "../views/logged-in-view.js";

export class LoggedInAdapter {
  #view = null;

  /** `content`는 Swift가 채우는 자식 화면 자리다. 순수 뷰에는 `child`로 넘긴다. */
  mount(host, content, handle) {
    this.#view = createLoggedInView(host, { child: content, onLogout: () => handle.logoutTapped() });
  }

  render(userName, sessionSeconds) {
    this.#view?.render({ userName, sessionSeconds });
  }
}
