import { ReactScreen } from "../../support/react-screen";
import type { TodoDetailScreenHandle, TodoDetailViewBridge } from "../../support/swift";
import { TodoDetailView } from "./view";

/** 어댑터(ADR-0027). Swift `TodoDetailViewBridge`(Sources/TodoModularWeb/TodoDetailBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class TodoDetailAdapter implements TodoDetailViewBridge {
  #screen = new ReactScreen<TodoDetailScreenHandle>();

  mount(host: Element, handle: TodoDetailScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(title: string, isDone: boolean, notice: string | null): void {
    this.#screen.render((handle) => (
      <TodoDetailView
        title={title}
        isDone={isDone}
        notice={notice}
        onBack={() => handle.backTapped()}
        onToggleDone={() => handle.toggleDoneTapped()}
        onTitleCopied={(succeeded) => handle.titleCopied(succeeded)}
      />
    ));
  }
}
