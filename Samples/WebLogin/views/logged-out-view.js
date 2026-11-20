// LoggedOut 화면의 웹 뷰. Swift `LoggedOutViewBridge`(Sources/WebLogin/LoggedOutBridge.swift)를 구현한다.
// 타입은 BridgeJS가 만든 bridge-js.d.ts의 `LoggedOutViewBridge`, `LoggedOutScreenHandle`을 따른다.

function element(tag, id, text) {
  const node = document.createElement(tag);
  if (id) node.id = id;
  if (text) node.textContent = text;
  return node;
}

export class LoggedOutView {
  /** 가장 최근에 mount한 화면의 요소들. */
  #current = null;

  /** 새 LoggedOut 화면이 생길 때 Swift가 부른다. 이름 입력값은 이 뷰가 들고 있다가 로그인 때 넘긴다. */
  mount(host, handle) {
    const nameField = element("input", "nameField");
    nameField.placeholder = "이름";
    const errorLabel = element("p", "errorLabel");
    errorLabel.hidden = true;
    const loadingIndicator = element("p", "loadingIndicator", "로그인 중…");
    loadingIndicator.hidden = true;
    const loginButton = element("button", "loginButton", "로그인");
    loginButton.addEventListener("click", () => handle.loginTapped(nameField.value));
    host.replaceChildren(element("h1", null, "로그인"), nameField, errorLabel, loadingIndicator, loginButton);
    this.#current = { nameField, errorLabel, loadingIndicator, loginButton };
  }

  render(errorMessage, isLoading) {
    if (!this.#current) return;
    const { nameField, errorLabel, loadingIndicator, loginButton } = this.#current;
    errorLabel.textContent = errorMessage ?? "";
    errorLabel.hidden = errorMessage == null;
    loadingIndicator.hidden = !isLoading;
    nameField.disabled = isLoading;
    loginButton.disabled = isLoading;
  }
}
