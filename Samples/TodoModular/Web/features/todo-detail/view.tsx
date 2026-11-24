// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

type Props = {
  title: string;
  isDone: boolean;
  onBack: () => void;
  onToggleDone: () => void;
};

/** 뒤로 버튼은 닫기를 요청만 한다. */
export function TodoDetailView({ title, isDone, onBack, onToggleDone }: Props) {
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
