import { ReactScreen } from "../../support/react-screen";
import type { TodoListRow, TodoListScreenHandle, TodoListViewBridge } from "../../support/swift";
import { TodoListView } from "./view";

/** 어댑터(ADR-0027). Swift `TodoListViewBridge`(Sources/TodoModularWeb/TodoListBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class TodoListAdapter implements TodoListViewBridge {
  #screen = new ReactScreen<TodoListScreenHandle>();

  mount(host: Element, handle: TodoListScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(rows: TodoListRow[], isLoading: boolean, errorMessage: string | null): void {
    const items = rows.map(({ id, title, isDone }) => ({ id, title, isDone }));
    this.#screen.render((handle) => (
      <TodoListView
        items={items}
        isLoading={isLoading}
        errorMessage={errorMessage}
        onSelect={(id) => handle.todoTapped(id)}
        onRetry={() => handle.retryTapped()}
      />
    ));
  }
}
