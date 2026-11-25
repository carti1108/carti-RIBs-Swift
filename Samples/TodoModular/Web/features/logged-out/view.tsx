// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

import { useState } from "react";

type Props = {
  errorMessage: string | null;
  isLoading: boolean;
  onLogin: (rawName: string) => void;
};

/** 이름 입력값은 이 컴포넌트가 들고 있다가 로그인 때 넘긴다. */
export function LoggedOutView({ errorMessage, isLoading, onLogin }: Props) {
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
