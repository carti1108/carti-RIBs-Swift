import { useEffect, useRef } from "react";
import { ReactScreen } from "../../support/react-screen";
import type { ChannelHandle, ChannelViewBridge } from "../../support/swift";
import type { LoggedInViewAction, LoggedInViewState } from "../../support/generated/view-state";
import { LoggedInView } from "./view";

/** Swift가 채우는 DOM 요소(`content`)를 React 트리의 한 자리에 붙인다. 순수 뷰에는 `children`으로 넘긴다. */
function ChildSlot({ content }: { content: Element }) {
  const slot = useRef<HTMLDivElement>(null);
  useEffect(() => {
    slot.current?.replaceChildren(content);
  }, [content]);
  return <div ref={slot} />;
}

type Mounted = { content: Element; handle: ChannelHandle };

function send(handle: ChannelHandle, action: LoggedInViewAction): void {
  handle.dispatch(JSON.stringify(action));
}

/** 어댑터(ADR-0027). 단일 채널 `ChannelViewBridge`를 구현하고 생성 타입을 순수 뷰에 넘긴다. */
export class LoggedInAdapter implements ChannelViewBridge {
  #screen = new ReactScreen<Mounted>();

  mount(host: Element, content: Element | null, handle: ChannelHandle): void {
    if (!content) throw new Error("LoggedInAdapter requires a child content element");
    this.#screen.mount(host, { content, handle });
  }

  render(stateJSON: string): void {
    const state = JSON.parse(stateJSON) as LoggedInViewState;
    this.#screen.render(({ content, handle }) => (
      <LoggedInView
        userName={state.userName}
        sessionSeconds={state.sessionSeconds}
        onLogout={() => send(handle, { kind: "logoutTapped" })}
      >
        <ChildSlot content={content} />
      </LoggedInView>
    ));
  }
}
