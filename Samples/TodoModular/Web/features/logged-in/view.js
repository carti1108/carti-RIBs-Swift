// LoggedIn 화면의 웹 뷰. Swift `LoggedInViewBridge`(Sources/TodoModularWeb/LoggedInBridge.swift)를 구현한다.
import { element } from "../../support/dom.js";

export class LoggedInView {
  /** 가장 최근에 mount한 화면의 요소들. */
  #current = null;

  /** `content`는 자식 화면(할 일 목록·상세) 자리다. Swift가 채우므로 원하는 위치에 넣기만 한다. */
  mount(host, content, handle) {
    const welcomeLabel = element("h2", "welcomeLabel");
    const sessionLabel = element("p", "sessionLabel");
    const logoutButton = element("button", "logoutButton", "로그아웃");
    logoutButton.addEventListener("click", () => handle.logoutTapped());
    host.replaceChildren(welcomeLabel, sessionLabel, logoutButton, content);
    this.#current = { welcomeLabel, sessionLabel };
  }

  render(userName, sessionSeconds) {
    if (!this.#current) return;
    this.#current.welcomeLabel.textContent = `${userName}님, 환영합니다`;
    this.#current.sessionLabel.textContent = `로그인 ${sessionSeconds}초`;
  }
}
