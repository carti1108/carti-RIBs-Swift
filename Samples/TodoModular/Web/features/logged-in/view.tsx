// 순수 뷰(ADR-0027). props로 받은 값과 콜백만으로 그린다. React만 import하고 Swift 브리지 타입을 모른다.

import type { ReactNode } from "react";

type Props = {
  userName: string;
  sessionSeconds: number;
  onLogout: () => void;
  /** 자식 화면(할 일 목록·상세) 자리. 무엇이 들어오는지 모른다. */
  children: ReactNode;
};

export function LoggedInView({ userName, sessionSeconds, onLogout, children }: Props) {
  return (
    <>
      <h2 id="welcomeLabel">{userName}님, 환영합니다</h2>
      <p id="sessionLabel">로그인 {sessionSeconds}초</p>
      <button id="logoutButton" onClick={onLogout}>
        로그아웃
      </button>
      {children}
    </>
  );
}
