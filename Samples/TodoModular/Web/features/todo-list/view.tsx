// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

/** 목록 한 줄. 뷰가 정의하고 어댑터가 채운다. */
export type TodoListItem = {
  id: number;
  title: string;
  isDone: boolean;
};

type Props = {
  items: TodoListItem[];
  onSelect: (id: number) => void;
};

/** 화면 자리가 `<ul>`이라 항목만 그린다. */
export function TodoListView({ items, onSelect }: Props) {
  return items.map((item) => (
    <li key={item.id}>
      <button id={`todoRow-${item.id}`} onClick={() => onSelect(item.id)}>
        {(item.isDone ? "✓ " : "") + item.title}
      </button>
    </li>
  ));
}
