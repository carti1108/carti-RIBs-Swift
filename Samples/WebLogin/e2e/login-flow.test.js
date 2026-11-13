// 헤드리스 Chrome으로 Wasm 로그인 샘플의 흐름을 확인한다. iOS LoginFlowUITests와 같은 시나리오다.
// 먼저 `swift package --swift-sdk <wasm SDK> js`로 .build/plugins/PackageToJS/outputs/Package를 만들어 둔다.
import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const root = fileURLToPath(new URL("..", import.meta.url));
const mimeTypes = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".json": "application/json" };
const loginDelayMillis = 1500;
const timeout = 10_000;

let server;
let baseURL;
let browser;
let page;

function serveStatic(request, response) {
  const path = normalize(decodeURIComponent(new URL(request.url, "http://localhost").pathname));
  if (path.includes("..")) {
    response.writeHead(400).end();
    return;
  }
  const file = join(root, path === "/" ? "index.html" : path);
  readFile(file)
    .then((body) => {
      response.writeHead(200, { "Content-Type": mimeTypes[extname(file)] ?? "application/octet-stream" });
      response.end(body);
    })
    .catch(() => response.writeHead(404).end());
}

const text = (selector) => page.$eval(selector, (node) => node.textContent);
const isVisible = (selector) =>
  page.$eval(selector, (node) => !node.hidden).catch(() => false);

async function login(name) {
  await page.waitForSelector("#nameField", { timeout });
  await page.type("#nameField", name);
  await page.click("#loginButton");
}

before(async () => {
  server = createServer(serveStatic);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  baseURL = `http://127.0.0.1:${server.address().port}/`;
  browser = await puppeteer.launch({ headless: true, args: process.env.CI ? ["--no-sandbox"] : [] });
});

after(async () => {
  await browser?.close();
  server?.close();
});

beforeEach(async () => {
  page = await browser.newPage();
  page.on("pageerror", (error) => assert.fail(`page error: ${error.message}`));
  await page.goto(`${baseURL}?loginDelayMillis=${loginDelayMillis}`);
});

describe("Wasm 로그인 샘플", () => {
  test("빈 이름이면 오류를 보여 준다", async () => {
    await page.waitForSelector("#loginButton", { timeout });
    await page.click("#loginButton");

    await page.waitForSelector("#errorLabel:not([hidden])", { timeout });
    assert.equal(await text("#errorLabel"), "이름을 입력하세요");
  });

  test("로그인 중 로딩을 보이고, 환영 화면 뒤 로그아웃하면 빈 로그인 화면으로 돌아간다", async () => {
    await login("  carti ");

    await page.waitForSelector("#loadingIndicator:not([hidden])", { timeout });
    assert.equal(await page.$eval("#loginButton", (node) => node.disabled), true);

    await page.waitForSelector("#welcomeLabel", { timeout });
    assert.equal(await text("#welcomeLabel"), "carti님, 환영합니다");

    await page.click("#logoutButton");
    await page.waitForSelector("#nameField", { timeout });
    assert.equal(await page.$eval("#nameField", (node) => node.value), "");
    assert.equal(await isVisible("#errorLabel"), false);
  });

  test("fail로 로그인하면 서버 오류를 보이고 다시 시도할 수 있다", async () => {
    await login("fail");

    await page.waitForSelector("#errorLabel:not([hidden])", { timeout });
    assert.equal(await text("#errorLabel"), "로그인에 실패했습니다");
    assert.equal(await isVisible("#loadingIndicator"), false);
    assert.equal(await page.$eval("#loginButton", (node) => node.disabled), false);
  });

  test("상세에서 완료를 바꾸고 뒤로 가면 목록에 반영된다", async () => {
    await login("carti");

    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await page.waitForSelector("#detailTitle", { timeout });
    assert.equal(await text("#detailTitle"), "우유 사기");

    await page.click("#toggleDoneButton");
    await page.waitForFunction(() => document.querySelector("#toggleDoneButton")?.textContent === "완료 취소", { timeout });
    await page.click("#backButton");

    await page.waitForSelector("#todoRow-1", { timeout });
    assert.equal(await text("#todoRow-1"), "✓ 우유 사기");
    assert.equal(await page.$("#detailTitle"), null);
  });

  test("상세 화면에서 새로고침하면 sessionStorage에 저장한 상태로 같은 화면을 복원한다", async () => {
    await login("carti");
    await page.waitForSelector("#todoRow-1", { timeout });
    await page.click("#todoRow-1");
    await page.waitForSelector("#detailTitle", { timeout });
    await page.click("#toggleDoneButton");
    await page.waitForFunction(() => document.querySelector("#toggleDoneButton")?.textContent === "완료 취소", { timeout });

    await page.reload();

    await page.waitForSelector("#detailTitle", { timeout });
    assert.equal(await text("#detailTitle"), "우유 사기");
    assert.equal(await text("#toggleDoneButton"), "완료 취소");
    assert.equal(await page.$("#nameField"), null);
    await page.click("#backButton");
    await page.waitForSelector("#todoRow-1", { timeout });
    assert.equal(await text("#todoRow-1"), "✓ 우유 사기");
  });
});
