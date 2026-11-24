// 순수 뷰(ADR-0027). 값과 콜백만 받아 DOM을 그린다. Swift 핸들과 브리지 프로토콜을 모른다.
import { element } from "./dom.js";

/** 뒤로 버튼은 닫기를 요청만 한다. */
export function createTodoDetailView(host, { onBack, onToggleDone }) {
  const backButton = element("button", "backButton", "← 목록");
  backButton.addEventListener("click", onBack);
  const titleLabel = element("h3", "detailTitle");
  const toggleButton = element("button", "toggleDoneButton");
  toggleButton.addEventListener("click", onToggleDone);
  host.replaceChildren(backButton, titleLabel, toggleButton);

  return {
    render({ title, isDone }) {
      titleLabel.textContent = title;
      toggleButton.textContent = isDone ? "완료 취소" : "완료로 표시";
    },
  };
}
