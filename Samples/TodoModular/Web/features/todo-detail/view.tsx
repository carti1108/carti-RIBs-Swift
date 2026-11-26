// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

type Props = {
  title: string;
  isDone: boolean;
  notice: string | null;
  onBack: () => void;
  onToggleDone: () => void;
  /** 클립보드에 쓴 결과. 클립보드는 플랫폼 기능이라 뷰가 다루고 결과만 넘긴다(#31). */
  onTitleCopied: (succeeded: boolean) => void;
};

/** 권한이 없거나 보안 컨텍스트가 아니면 `navigator.clipboard`가 없거나 거절한다. */
async function copyToClipboard(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/** 뒤로 버튼은 닫기를 요청만 한다. */
export function TodoDetailView({ title, isDone, notice, onBack, onToggleDone, onTitleCopied }: Props) {
  return (
    <>
      <button id="backButton" onClick={onBack}>
        ← 목록
      </button>
      <h3 id="detailTitle">{title}</h3>
      <button id="toggleDoneButton" onClick={onToggleDone}>
        {isDone ? "완료 취소" : "완료로 표시"}
      </button>
      <button id="copyTitleButton" onClick={async () => onTitleCopied(await copyToClipboard(title))}>
        제목 복사
      </button>
      {notice != null && <p id="detailNotice">{notice}</p>}
    </>
  );
}
