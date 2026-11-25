// 플랫폼 입력(#31): 뷰가 클립보드·파일을 다루고, 결과 하나를 ViewAction으로 공유 코드에 넘긴다.
// 클립보드는 브라우저 권한과 포커스에 따라 결과가 달라지므로 `navigator.clipboard.writeText`를 바꿔 끼워 두 결과를 만든다.
import { after, afterEach, before, describe, test } from "node:test";
import assert from "node:assert/strict";
import { startSession, text, timeout, waitForText } from "./support.js";

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

/** 클립보드 쓰기를 기록하고, `succeeds`가 false면 브라우저가 거절할 때처럼 실패시킨다. */
async function stubClipboard(page, succeeds) {
  await page.evaluate((succeeds) => {
    window.copiedTexts = [];
    Object.defineProperty(navigator, "clipboard", {
      configurable: true,
      value: {
        writeText: async (value) => {
          if (!succeeds) throw new DOMException("denied", "NotAllowedError");
          window.copiedTexts.push(value);
        },
      },
    });
  }, succeeds);
}

describe("플랫폼 입력 브리지", () => {
  test("TodoDetail: 제목을 클립보드에 쓰고 결과를 보여 준다", async () => {
    page = await session.open("/features/todo-detail/demo.html");
    await waitForText(page, "#detailTitle", "우유 사기");
    await stubClipboard(page, true);

    await page.click("#copyTitleButton");

    await waitForText(page, "#detailNotice", "제목을 복사했습니다");
    assert.deepEqual(await page.evaluate(() => window.copiedTexts), ["우유 사기"]);
  });

  test("TodoDetail: 클립보드가 거절하면 실패를 보여 주고, 다른 동작 뒤에는 지운다", async () => {
    page = await session.open("/features/todo-detail/demo.html");
    await waitForText(page, "#detailTitle", "우유 사기");
    await stubClipboard(page, false);

    await page.click("#copyTitleButton");
    await waitForText(page, "#detailNotice", "제목을 복사하지 못했습니다");

    await page.click("#toggleDoneButton");
    await page.waitForFunction(() => document.querySelector("#detailNotice") == null, { timeout });
  });

  test("TodoList: 파일을 고르면 줄마다 할 일로 더한다", async () => {
    page = await session.open("/features/todo-list/demo.html");
    await page.waitForSelector("#todoRow-3", { timeout });

    // uploadFile은 디스크의 파일을 요구하므로 DataTransfer로 input에 파일을 넣고 change를 보낸다.
    await page.$eval("#todoImportInput", (input) => {
      const transfer = new DataTransfer();
      transfer.items.add(new File(["빨래\r\n\n  장보기  \n"], "할일.txt", { type: "text/plain" }));
      input.files = transfer.files;
      input.dispatchEvent(new Event("change", { bubbles: true }));
    });

    await waitForText(page, "#todoNotice", " 할일.txt에서 2개를 추가했습니다");
    assert.equal(await text(page, "#todoRow-4"), "빨래");
    assert.equal(await text(page, "#todoRow-5"), "장보기");
  });

  test("TodoList: 파일을 끌어다 놓아도 같은 액션으로 간다", async () => {
    page = await session.open("/features/todo-list/demo.html");
    await page.waitForSelector("#todoRow-3", { timeout });

    await page.$eval("#todoImport", (zone) => {
      const transfer = new DataTransfer();
      transfer.items.add(new File(["운동\n"], "놓기.txt", { type: "text/plain" }));
      zone.dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: transfer }));
      zone.dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }));
    });

    await waitForText(page, "#todoNotice", " 놓기.txt에서 1개를 추가했습니다");
    assert.equal(await text(page, "#todoRow-4"), "운동");
  });
});
