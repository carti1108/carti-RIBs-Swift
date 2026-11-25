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

  test("브라우저 뒤로 가기로 상세를 닫으면 목록으로 돌아오고 다른 할 일을 열 수 있다", async () => {
    await login(page, "carti");
    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await waitForText(page, "#detailTitle", "우유 사기");

    await page.goBack();

    await page.waitForSelector("#todoRow-2", { timeout });
    assert.equal(await page.$("#detailTitle"), null);
    // RIB 트리에 상세가 남아 있으면 두 번째 상세가 열리지 않는다.
    await page.click("#todoRow-2");
    await waitForText(page, "#detailTitle", "RIB 문서 읽기");
  });

  test("화면의 뒤로 버튼으로 닫은 뒤 연 상세는 기록 항목을 다시 쓰고, 브라우저 뒤로 가기로 닫힌다", async () => {
    await login(page, "carti");
    await page.waitForSelector("#todoRow-1", { timeout });
    const lengthBefore = await page.evaluate(() => history.length);
    await page.click("#todoRow-1");
    await page.waitForSelector("#detailTitle", { timeout });
    await page.click("#backButton");
    await page.waitForSelector("#todoRow-2", { timeout });

    await page.click("#todoRow-2");
    await waitForText(page, "#detailTitle", "RIB 문서 읽기");
    assert.equal(await page.evaluate(() => history.length), lengthBefore + 1);

    await page.goBack();
    await page.waitForSelector("#todoRow-1", { timeout });
    assert.equal(await page.$("#detailTitle"), null);
  });

  test("뒤로 갔다가 앞으로 가도 상세는 다시 열리지 않고, 그 뒤 연 상세는 뒤로 가기로 닫힌다", async () => {
    await login(page, "carti");
    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await page.waitForSelector("#detailTitle", { timeout });
    await page.goBack();
    await page.waitForSelector("#todoRow-1", { timeout });

    await page.goForward();
    assert.equal(await page.$("#detailTitle"), null);

    await page.click("#todoRow-2");
    await waitForText(page, "#detailTitle", "RIB 문서 읽기");
    await page.goBack();
    await page.waitForSelector("#todoRow-1", { timeout });
    assert.equal(await page.$("#detailTitle"), null);
    assert.match(page.url(), /loginDelayMillis/);
  });

  test("할 일을 불러오지 못하면 오류와 다시 시도 버튼을 보이고, 다시 시도하면 목록이 나온다", async () => {
    await page.close();
    page = await session.open("/?loginDelayMillis=1&todoFailures=1");
    await login(page, "carti");

    await waitForText(page, "#todoError", "할 일을 불러오지 못했습니다");
    assert.equal(await page.$("#todoRow-1"), null);

    await page.click("#todoRetryButton");

    await page.waitForSelector("#todoRow-1", { timeout });
    assert.equal(await page.$("#todoError"), null);
    assert.equal(await page.$("#todoLoading"), null);
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
