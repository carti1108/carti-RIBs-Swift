// E2E 공통: 이 디렉터리를 정적 서버로 띄우고 헤드리스 Chrome을 연다.
// 먼저 `swift package --swift-sdk <wasm SDK> js`로 .build/plugins/PackageToJS/outputs/Package를 만들어 둔다.
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const root = fileURLToPath(new URL("..", import.meta.url));
const mimeTypes = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".json": "application/json" };

export const timeout = 10_000;

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
  const server = createServer(serveStatic);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const baseURL = `http://127.0.0.1:${server.address().port}`;
  const browser = await puppeteer.launch({ headless: true, args: process.env.CI ? ["--no-sandbox"] : [] });
  return {
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
