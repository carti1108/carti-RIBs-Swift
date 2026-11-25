// 어댑터(ADR-0027). Swift `TodoListViewBridge`(Sources/WebLogin/TodoListBridge.swift)를 구현하고 값을 순수 뷰(views/todo-list-view.js)에 넘긴다.
// 타입은 BridgeJS가 만든 bridge-js.d.ts를 따른다. 화면 종류마다 어댑터는 하나이고, 가장 최근에 mount한 화면에 그린다.
import { createTodoListView } from "../views/todo-list-view.js";

export class TodoListAdapter {
  #view = null;

  mount(host, handle) {
    this.#view = createTodoListView(host, { onSelect: (id) => handle.todoTapped(id) });
  }

  render(rows) {
    this.#view?.render({ items: rows.map(({ id, title, isDone }) => ({ id, title, isDone })) });
  }
}
