// 웹 뷰들이 같이 쓰는 요소 생성 헬퍼.
export function element(tag, id, text) {
  const node = document.createElement(tag);
  if (id) node.id = id;
  if (text) node.textContent = text;
  return node;
}
