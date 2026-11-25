import { useEffect, useRef } from "react";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedInScreenHandle, LoggedInViewBridge } from "../../support/swift";

type Props = {
  userName: string;
  sessionSeconds: number;
  content: Element;
  onLogout: () => void;
};

/** `content`는 자식 화면(할 일 목록·상세) 자리다. Swift가 채우므로 원하는 위치에 넣기만 한다. */
export function LoggedInScreen({ userName, sessionSeconds, content, onLogout }: Props) {
  const slot = useRef<HTMLDivElement>(null);
  useEffect(() => {
    slot.current?.replaceChildren(content);
  }, [content]);

  return (
    <>
      <h2 id="welcomeLabel">{userName}님, 환영합니다</h2>
      <p id="sessionLabel">로그인 {sessionSeconds}초</p>
      <button id="logoutButton" onClick={onLogout}>
        로그아웃
      </button>
      <div ref={slot} />
    </>
  );
}

type Mounted = { content: Element; handle: LoggedInScreenHandle };

/** Swift `LoggedInViewBridge`(Sources/TodoModularWeb/LoggedInBridge.swift)의 React 구현. */
export class LoggedInView implements LoggedInViewBridge {
  #screen = new ReactScreen<Mounted>();

  mount(host: Element, content: Element, handle: LoggedInScreenHandle): void {
    this.#screen.mount(host, { content, handle });
  }

  render(userName: string, sessionSeconds: number): void {
    this.#screen.render(({ content, handle }) => (
      <LoggedInScreen
        userName={userName}
        sessionSeconds={sessionSeconds}
        content={content}
        onLogout={() => handle.logoutTapped()}
      />
    ));
  }
}
