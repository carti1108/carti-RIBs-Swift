import { ReactScreen } from "../../support/react-screen";
import type { TodoListRow, TodoListScreenHandle, TodoListViewBridge } from "../../support/swift";

type Props = {
  rows: TodoListRow[];
  onSelect: (id: number) => void;
};

/** 화면 자리(`host`)가 `<ul>`이라 항목만 그린다. */
export function TodoListScreen({ rows, onSelect }: Props) {
  return rows.map((row) => (
    <li key={row.id}>
      <button id={`todoRow-${row.id}`} onClick={() => onSelect(row.id)}>
        {(row.isDone ? "✓ " : "") + row.title}
      </button>
    </li>
  ));
}

/** Swift `TodoListViewBridge`(Sources/TodoModularWeb/TodoListBridge.swift)의 React 구현. */
export class TodoListView implements TodoListViewBridge {
  #screen = new ReactScreen<TodoListScreenHandle>();

  mount(host: Element, handle: TodoListScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(rows: TodoListRow[]): void {
    this.#screen.render((handle) => <TodoListScreen rows={rows} onSelect={(id) => handle.todoTapped(id)} />);
  }
}
