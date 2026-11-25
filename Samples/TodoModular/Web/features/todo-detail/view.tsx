import { ReactScreen } from "../../support/react-screen";
import type { TodoDetailScreenHandle, TodoDetailViewBridge } from "../../support/swift";

type Props = {
  title: string;
  isDone: boolean;
  onBack: () => void;
  onToggleDone: () => void;
};

/** 뒤로 버튼은 닫기를 요청만 한다. 닫는 일은 부모 RIB이 한다. */
export function TodoDetailScreen({ title, isDone, onBack, onToggleDone }: Props) {
  return (
    <>
      <button id="backButton" onClick={onBack}>
        ← 목록
      </button>
      <h3 id="detailTitle">{title}</h3>
      <button id="toggleDoneButton" onClick={onToggleDone}>
        {isDone ? "완료 취소" : "완료로 표시"}
      </button>
    </>
  );
}

/** Swift `TodoDetailViewBridge`(Sources/TodoModularWeb/TodoDetailBridge.swift)의 React 구현. */
export class TodoDetailView implements TodoDetailViewBridge {
  #screen = new ReactScreen<TodoDetailScreenHandle>();

  mount(host: Element, handle: TodoDetailScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(title: string, isDone: boolean): void {
    this.#screen.render((handle) => (
      <TodoDetailScreen
        title={title}
        isDone={isDone}
        onBack={() => handle.backTapped()}
        onToggleDone={() => handle.toggleDoneTapped()}
      />
    ));
  }
}
