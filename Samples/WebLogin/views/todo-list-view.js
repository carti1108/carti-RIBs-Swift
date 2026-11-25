// TodoList 화면의 웹 뷰. Swift `TodoListViewBridge`(Sources/WebLogin/TodoListBridge.swift)를 구현한다.
import { element } from "./dom.js";

export class TodoListView {
  /** 가장 최근에 mount한 화면의 자리와 핸들. */
  #current = null;

  mount(host, handle) {
    this.#current = { host, handle };
  }

  render(rows) {
    if (!this.#current) return;
    const { host, handle } = this.#current;
    host.replaceChildren(
      ...rows.map((row) => {
        const button = element("button", `todoRow-${row.id}`, (row.isDone ? "✓ " : "") + row.title);
        button.addEventListener("click", () => handle.todoTapped(row.id));
        const item = element("li");
        item.append(button);
        return item;
      }),
    );
  }
}
