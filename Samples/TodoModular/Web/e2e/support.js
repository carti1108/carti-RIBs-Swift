// E2E 공통: Vite가 빌드한 `dist`를 정적 서버로 띄우고 헤드리스 Chrome을 연다.
// `npm run test:e2e`가 빌드부터 한다. 그 전에 `swift package --swift-sdk <wasm SDK> js`로 Wasm 패키지를 만들어 둔다.
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const root = fileURLToPath(new URL("../dist", import.meta.url));
const mimeTypes = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".wasm": "application/wasm" };

export const timeout = 10_000;

/** 테스트가 조종하는 할 일 API. 앱은 `fetch("/api/todos")`로 실제 HTTP 요청을 보낸다(ADR-0033). */
function createTodoAPI() {
  const api = {
    /** 지금까지 받은 `/api/todos` 요청 수. */
    requests: 0,
    remainingFailures: 0,
    /** 다음 `count`번의 요청에 503을 돌려준다. */
    failNext(count) {
      api.remainingFailures = count;
    },
    handle(response) {
      api.requests += 1;
      if (api.remainingFailures > 0) {
        api.remainingFailures -= 1;
        response.writeHead(503).end();
        return;
      }
      readFile(join(root, "api/todos")).then((body) => {
        response.writeHead(200, { "Content-Type": "application/json" });
        response.end(body);
      });
    },
  };
  return api;
}

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

/** 서버와 브라우저를 띄운다. `open(path)`는 페이지 오류가 나면 테스트를 실패시키는 새 페이지를 연다. */
export async function startSession() {
  const api = createTodoAPI();
  const server = createServer((request, response) => {
    if (new URL(request.url, "http://localhost").pathname === "/api/todos") {
      api.handle(response);
    } else {
      serveStatic(request, response);
    }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const baseURL = `http://127.0.0.1:${server.address().port}`;
  const browser = await puppeteer.launch({ headless: true, args: process.env.CI ? ["--no-sandbox"] : [] });
  return {
    api,
    async open(path) {
      const page = await browser.newPage();
      page.on("pageerror", (error) => assert.fail(`page error: ${error.message}`));
      await page.goto(`${baseURL}${path}`);
      return page;
    },
    async close() {
      await browser.close();
      server.close();
    },
  };
}

export const text = (page, selector) => page.$eval(selector, (node) => node.textContent);
export const isVisible = (page, selector) => page.$eval(selector, (node) => !node.hidden).catch(() => false);

export async function waitForText(page, selector, expected) {
  await page.waitForFunction(
    (selector, expected) => document.querySelector(selector)?.textContent === expected,
    { timeout },
    selector,
    expected,
  );
}

export async function login(page, name) {
  await page.waitForSelector("#nameField", { timeout });
  await page.type("#nameField", name);
  await page.click("#loginButton");
}
