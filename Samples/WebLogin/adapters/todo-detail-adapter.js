// 어댑터(ADR-0027). Swift `TodoDetailViewBridge`(Sources/WebLogin/TodoDetailBridge.swift)를 구현하고 값을 순수 뷰(views/todo-detail-view.js)에 넘긴다.
// 타입은 BridgeJS가 만든 bridge-js.d.ts를 따른다. 화면 종류마다 어댑터는 하나이고, 가장 최근에 mount한 화면에 그린다.
import { createTodoDetailView } from "../views/todo-detail-view.js";

export class TodoDetailAdapter {
  #view = null;

  mount(host, handle) {
    this.#view = createTodoDetailView(host, {
      onBack: () => handle.backTapped(),
      onToggleDone: () => handle.toggleDoneTapped(),
    });
  }

  render(title, isDone) {
    this.#view?.render({ title, isDone });
  }
}
