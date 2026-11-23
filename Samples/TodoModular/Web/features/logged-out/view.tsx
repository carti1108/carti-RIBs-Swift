import { useState } from "react";
import { ReactScreen } from "../../support/react-screen";
import type { LoggedOutScreenHandle, LoggedOutViewBridge } from "../../support/swift";

type Props = {
  errorMessage: string | null;
  isLoading: boolean;
  onLogin: (rawName: string) => void;
};

/** 이름 입력값은 이 컴포넌트가 들고 있다가 로그인 때 넘긴다. */
export function LoggedOutScreen({ errorMessage, isLoading, onLogin }: Props) {
  const [name, setName] = useState("");
  return (
    <>
      <h1>로그인</h1>
      <input
        id="nameField"
        placeholder="이름"
        value={name}
        disabled={isLoading}
        onChange={(event) => setName(event.target.value)}
      />
      <p id="errorLabel" hidden={errorMessage == null}>
        {errorMessage}
      </p>
      <p id="loadingIndicator" hidden={!isLoading}>
        로그인 중…
      </p>
      <button id="loginButton" disabled={isLoading} onClick={() => onLogin(name)}>
        로그인
      </button>
    </>
  );
}

/** Swift `LoggedOutViewBridge`(Sources/TodoModularWeb/LoggedOutBridge.swift)의 React 구현. */
export class LoggedOutView implements LoggedOutViewBridge {
  #screen = new ReactScreen<LoggedOutScreenHandle>();

  mount(host: Element, handle: LoggedOutScreenHandle): void {
    this.#screen.mount(host, handle);
  }

  render(errorMessage: string | null, isLoading: boolean): void {
    this.#screen.render((handle) => (
      <LoggedOutScreen
        errorMessage={errorMessage}
        isLoading={isLoading}
        onLogin={(rawName) => handle.loginTapped(rawName)}
      />
    ));
  }
}
