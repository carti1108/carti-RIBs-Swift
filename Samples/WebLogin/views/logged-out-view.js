// 순수 뷰(ADR-0027). 값과 콜백만 받아 DOM을 그린다. Swift 핸들과 브리지 프로토콜을 모른다.
import { element } from "./dom.js";

/** `host` 안에 화면을 만들고, 값을 받아 다시 그리는 `render`를 돌려준다. 이름 입력값은 이 뷰가 들고 있다가 로그인 때 넘긴다. */
export function createLoggedOutView(host, { onLogin }) {
  const nameField = element("input", "nameField");
  nameField.placeholder = "이름";
  const errorLabel = element("p", "errorLabel");
  errorLabel.hidden = true;
  const loadingIndicator = element("p", "loadingIndicator", "로그인 중…");
  loadingIndicator.hidden = true;
  const loginButton = element("button", "loginButton", "로그인");
  loginButton.addEventListener("click", () => onLogin(nameField.value));
  host.replaceChildren(element("h1", null, "로그인"), nameField, errorLabel, loadingIndicator, loginButton);

  return {
    render({ errorMessage, isLoading }) {
      errorLabel.textContent = errorMessage ?? "";
      errorLabel.hidden = errorMessage == null;
      loadingIndicator.hidden = !isLoading;
      nameField.disabled = isLoading;
      loginButton.disabled = isLoading;
    },
  };
}
