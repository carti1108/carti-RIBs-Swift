// 순수 뷰(ADR-0027). 값과 콜백만 받아 DOM을 그린다. Swift 핸들과 브리지 프로토콜을 모른다.
import { element } from "./dom.js";

/** `child`는 자식 화면(할 일 목록·상세) 자리다. 무엇이 들어오는지 모르고 원하는 위치에 넣기만 한다. */
export function createLoggedInView(host, { child, onLogout }) {
  const welcomeLabel = element("h2", "welcomeLabel");
  const sessionLabel = element("p", "sessionLabel");
  const logoutButton = element("button", "logoutButton", "로그아웃");
  logoutButton.addEventListener("click", onLogout);
  host.replaceChildren(welcomeLabel, sessionLabel, logoutButton, child);

  return {
    render({ userName, sessionSeconds }) {
      welcomeLabel.textContent = `${userName}님, 환영합니다`;
      sessionLabel.textContent = `로그인 ${sessionSeconds}초`;
    },
  };
}
