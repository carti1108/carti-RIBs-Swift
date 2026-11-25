import { useEffect, useRef } from "react";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedInScreenHandle, LoggedInViewBridge } from "../../support/swift";
import { LoggedInView } from "./view";

/** Swift가 채우는 DOM 요소(`content`)를 React 트리의 한 자리에 붙인다. 순수 뷰에는 `children`으로 넘긴다. */
function ChildSlot({ content }: { content: Element }) {
  const slot = useRef<HTMLDivElement>(null);
  useEffect(() => {
    slot.current?.replaceChildren(content);
  }, [content]);
  return <div ref={slot} />;
}

type Mounted = { content: Element; handle: LoggedInScreenHandle };

/** 어댑터(ADR-0027). Swift `LoggedInViewBridge`(Sources/TodoModularWeb/LoggedInBridge.swift)를 구현하고 값을 순수 뷰에 넘긴다. */
export class LoggedInAdapter implements LoggedInViewBridge {
  #screen = new ReactScreen<Mounted>();

  mount(host: Element, content: Element, handle: LoggedInScreenHandle): void {
    this.#screen.mount(host, { content, handle });
  }

  render(userName: string, sessionSeconds: number): void {
    this.#screen.render(({ content, handle }) => (
      <LoggedInView userName={userName} sessionSeconds={sessionSeconds} onLogout={() => handle.logoutTapped()}>
        <ChildSlot content={content} />
      </LoggedInView>
    ));
  }
}
