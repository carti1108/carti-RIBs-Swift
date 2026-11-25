// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

/** 목록 한 줄. 뷰가 정의하고 어댑터가 채운다. */
export type TodoListItem = {
  id: number;
  title: string;
  isDone: boolean;
};

type Props = {
  items: TodoListItem[];
  isLoading: boolean;
  errorMessage: string | null;
  notice: string | null;
  onSelect: (id: number) => void;
  onRetry: () => void;
  /** 끌어다 놓거나 고른 텍스트 파일의 이름과 내용. 받는 방법은 뷰가 다루고 결과 하나만 넘긴다(#31). */
  onFileReceived: (name: string, text: string) => void;
};

/** 한 파일에서 읽는 최대 바이트. 줄 수 상한은 공유 코드가 정하고, 뷰는 큰 파일을 통째로 읽어 넘기지 않는다. */
const maxFileBytes = 64 * 1024;

async function readFile(file: File | undefined, onFileReceived: Props["onFileReceived"]) {
  if (file == null) return;
  onFileReceived(file.name, await file.slice(0, maxFileBytes).text());
}

/** 화면 자리가 `<ul>`이라 항목만 그린다. 로딩과 오류도 항목 하나로 그린다. */
export function TodoListView({ items, isLoading, errorMessage, notice, onSelect, onRetry, onFileReceived }: Props) {
  return (
    <>
      {isLoading && <li id="todoLoading">불러오는 중…</li>}
      {errorMessage != null && (
        <li>
          <span id="todoError">{errorMessage}</span>{" "}
          <button id="todoRetryButton" onClick={onRetry}>
            다시 시도
          </button>
        </li>
      )}
      <li
        id="todoImport"
        onDragOver={(event) => event.preventDefault()}
        onDrop={(event) => {
          event.preventDefault();
          void readFile(event.dataTransfer.files[0], onFileReceived);
        }}
      >
        <label>
          텍스트 파일을 여기에 놓거나 고르세요{" "}
          <input
            id="todoImportInput"
            type="file"
            accept=".txt,text/plain"
            onChange={(event) => {
              // 같은 파일을 다시 골라도 change가 오도록 값을 비운다. 파일은 비우기 전에 꺼낸다.
              const file = event.currentTarget.files?.[0];
              event.currentTarget.value = "";
              void readFile(file, onFileReceived);
            }}
          />
        </label>
        {notice != null && <span id="todoNotice"> {notice}</span>}
      </li>
      {items.map((item) => (
        <li key={item.id}>
          <button id={`todoRow-${item.id}`} onClick={() => onSelect(item.id)}>
            {(item.isDone ? "✓ " : "") + item.title}
          </button>
        </li>
      ))}
    </>
  );
}
