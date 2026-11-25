// TodoDetail 화면의 웹 뷰. Swift `TodoDetailViewBridge`(Sources/WebLogin/TodoDetailBridge.swift)를 구현한다.
import { element } from "./dom.js";

export class TodoDetailView {
  /** 가장 최근에 mount한 화면의 요소들. */
  #current = null;

  mount(host, handle) {
    const backButton = element("button", "backButton", "← 목록");
    backButton.addEventListener("click", () => handle.backTapped());
    const titleLabel = element("h3", "detailTitle");
    const toggleButton = element("button", "toggleDoneButton");
    toggleButton.addEventListener("click", () => handle.toggleDoneTapped());
    host.replaceChildren(backButton, titleLabel, toggleButton);
    this.#current = { titleLabel, toggleButton };
  }

  render(title, isDone) {
    if (!this.#current) return;
    this.#current.titleLabel.textContent = title;
    this.#current.toggleButton.textContent = isDone ? "완료 취소" : "완료로 표시";
  }
}
