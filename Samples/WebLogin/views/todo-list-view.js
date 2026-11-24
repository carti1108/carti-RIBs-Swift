// 순수 뷰(ADR-0027). 값과 콜백만 받아 DOM을 그린다. Swift 핸들과 브리지 프로토콜을 모른다.
import { element } from "./dom.js";

/** `items`는 `{ id, title, isDone }` 배열이다. */
export function createTodoListView(host, { onSelect }) {
  return {
    render({ items }) {
      host.replaceChildren(
        ...items.map((item) => {
          const button = element("button", `todoRow-${item.id}`, (item.isDone ? "✓ " : "") + item.title);
          button.addEventListener("click", () => onSelect(item.id));
          const row = element("li");
          row.append(button);
          return row;
        }),
      );
    },
  };
}
