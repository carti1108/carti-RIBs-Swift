// 전체 앱(index.html)의 흐름. iOS TodoFlowUITests, Android LoginFlowTest와 같은 시나리오다.
import { after, afterEach, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { isVisible, login, startSession, text, timeout, waitForText } from "./support.js";

const loginDelayMillis = 1500;

let session;
let page;

before(async () => {
  session = await startSession();
});

after(async () => {
  await session?.close();
});

beforeEach(async () => {
  page = await session.open(`/?loginDelayMillis=${loginDelayMillis}`);
});

afterEach(async () => {
  await page?.close();
});

describe("TodoModular 웹 앱", () => {
  test("빈 이름이면 오류를 보여 준다", async () => {
    await page.waitForSelector("#loginButton", { timeout });
    await page.click("#loginButton");

    await page.waitForSelector("#errorLabel:not([hidden])", { timeout });
    assert.equal(await text(page, "#errorLabel"), "이름을 입력하세요");
  });

  test("로그인 중 로딩을 보이고, 환영 화면 뒤 로그아웃하면 빈 로그인 화면으로 돌아간다", async () => {
    await login(page, "  carti ");

    await page.waitForSelector("#loadingIndicator:not([hidden])", { timeout });
    assert.equal(await page.$eval("#loginButton", (node) => node.disabled), true);

    await waitForText(page, "#welcomeLabel", "carti님, 환영합니다");

    await page.click("#logoutButton");
    await page.waitForSelector("#nameField", { timeout });
    assert.equal(await page.$eval("#nameField", (node) => node.value), "");
    assert.equal(await isVisible(page, "#errorLabel"), false);
  });

  test("fail로 로그인하면 서버 오류를 보이고 다시 시도할 수 있다", async () => {
    await login(page, "fail");

    await page.waitForSelector("#errorLabel:not([hidden])", { timeout });
    assert.equal(await text(page, "#errorLabel"), "로그인에 실패했습니다");
    assert.equal(await isVisible(page, "#loadingIndicator"), false);
    assert.equal(await page.$eval("#loginButton", (node) => node.disabled), false);
  });

  test("상세에서 완료를 바꾸고 뒤로 가면 목록에 반영된다", async () => {
    await login(page, "carti");

    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await waitForText(page, "#detailTitle", "우유 사기");

    await page.click("#toggleDoneButton");
    await waitForText(page, "#toggleDoneButton", "완료 취소");
    await page.click("#backButton");

    await waitForText(page, "#todoRow-1", "✓ 우유 사기");
    assert.equal(await page.$("#detailTitle"), null);
  });

  test("상세 화면에서 새로고침하면 sessionStorage에 저장한 상태로 같은 화면을 복원한다", async () => {
    await login(page, "carti");
    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await page.waitForSelector("#detailTitle", { timeout });
    await page.click("#toggleDoneButton");
    await waitForText(page, "#toggleDoneButton", "완료 취소");

    await page.reload();

    await waitForText(page, "#detailTitle", "우유 사기");
    assert.equal(await text(page, "#toggleDoneButton"), "완료 취소");
    assert.equal(await page.$("#nameField"), null);
    await page.click("#backButton");
    await waitForText(page, "#todoRow-1", "✓ 우유 사기");
  });
});
