// 피처별 데모 페이지. 피처 하나만 띄우고, 부모에게 갈 이벤트는 `#demoEvent`에 보인다.
// iOS `FeatureXxxExample`, Android `feature/<f>/demo`와 같은 역할이다.
import { after, afterEach, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { login, startSession, text, timeout, waitForText } from "./support.js";

let session;
let page;

before(async () => {
  session = await startSession();
});

after(async () => {
  await session?.close();
});

afterEach(async () => {
  await page?.close();
});

describe("TodoModular 피처 데모 페이지", () => {
  test("LoggedOut: 로그인에 성공하면 부모에게 didLogin을 보낸다", async () => {
    page = await session.open("/features/logged-out/demo.html?loginDelayMillis=100");

    await login(page, "carti");

    await waitForText(page, "#demoEvent", "didLogin(userName: carti)");
  });

  test("LoggedIn: 자리표시 자식으로 상세 라우팅과 로그아웃 요청을 확인한다", async () => {
    page = await session.open("/features/logged-in/demo.html");

    await waitForText(page, "#welcomeLabel", "demo님, 환영합니다");
    await waitForText(page, "#placeholderTitle", "자리표시 목록");

    await page.click("#placeholderAction");
    await waitForText(page, "#placeholderTitle", "자리표시 상세 #1");
    await page.click("#placeholderAction");
    await waitForText(page, "#placeholderTitle", "자리표시 목록");

    await page.click("#logoutButton");
    await waitForText(page, "#demoEvent", "didRequestLogout()");
  });

  test("TodoList: 항목을 누르면 부모에게 선택을 보내고 목록이 갱신된다", async () => {
    page = await session.open("/features/todo-list/demo.html");

    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");

    await waitForText(page, "#demoEvent", "didSelectTodo(id: 1)");
    await waitForText(page, "#todoRow-1", "✓ 우유 사기");
  });

  test("TodoDetail: 완료를 바꾸고, 뒤로 가기는 부모에게 닫기를 요청한다", async () => {
    page = await session.open("/features/todo-detail/demo.html");

    await waitForText(page, "#detailTitle", "우유 사기");
    await page.click("#toggleDoneButton");
    await waitForText(page, "#toggleDoneButton", "완료 취소");

    await page.click("#backButton");
    await waitForText(page, "#demoEvent", "didRequestCloseDetail()");
    assert.equal(await text(page, "#detailTitle"), "우유 사기");
  });
});
