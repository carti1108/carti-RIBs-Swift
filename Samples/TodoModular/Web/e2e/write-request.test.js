// 쓰기 요청 스파이크(#31). 앱과 다른 출처의 API 서버에 인증 헤더를 붙여 POST를 보내고,
// 공유 코드(`TodoAPIClient`)가 분류한 결과를 페이지의 `#result`로 확인한다.
import { after, afterEach, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "node:http";
import { startSession, timeout } from "./support.js";

/** 앱과 포트가 달라 다른 출처가 되는 API 서버. 응답과 CORS 허용 여부를 테스트가 정한다. */
async function startCrossOriginAPI() {
  const api = {
    allowCORS: true,
    /** 프리플라이트가 허용하는 메서드. */
    allowMethods: "POST, PATCH, DELETE",
    reply: { status: 201, body: { id: 7, title: "운동", done: false } },
    /** 받은 요청. 프리플라이트(OPTIONS)도 들어간다. */
    received: [],
  };
  const server = createServer((request, response) => {
    let body = "";
    request.on("data", (chunk) => (body += chunk));
    request.on("end", () => {
      api.received.push({ method: request.method, path: request.url, headers: request.headers, body });
      const cors = api.allowCORS
        ? { "Access-Control-Allow-Origin": request.headers.origin ?? "*" }
        : {};
      if (request.method === "OPTIONS") {
        const allow = api.allowCORS
          ? { "Access-Control-Allow-Methods": api.allowMethods, "Access-Control-Allow-Headers": "Authorization, Content-Type" }
          : {};
        response.writeHead(204, { ...cors, ...allow }).end();
        return;
      }
      const contentType = api.reply.status >= 400 ? "application/problem+json" : "application/json";
      response.writeHead(api.reply.status, { ...cors, "Content-Type": contentType });
      response.end(typeof api.reply.body === "string" ? api.reply.body : JSON.stringify(api.reply.body));
    });
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  // 앱은 127.0.0.1로 연다. API는 localhost로 불러 포트와 호스트가 모두 다른 출처로 만든다.
  api.baseURL = `http://localhost:${server.address().port}`;
  api.close = () => server.close();
  return api;
}

let session;
let api;
let page;

before(async () => {
  session = await startSession();
});

after(async () => {
  await session?.close();
});

beforeEach(async () => {
  api = await startCrossOriginAPI();
});

afterEach(async () => {
  await page?.close();
  api?.close();
});

async function run({ token = "secret-token", title = "운동" } = {}) {
  const query = new URLSearchParams({ api: api.baseURL, token, title });
  page = await session.open(`/spikes/write-request.html?${query}`);
  await page.waitForFunction(() => document.querySelector("#result")?.textContent !== "", { timeout });
  return page.$eval("#result", (node) => node.textContent);
}

/** 공유 클라이언트를 거치지 않고 요청 하나를 그대로 보낸다. */
async function sendRaw({ method, path, body = "", token = "secret-token" }) {
  const query = new URLSearchParams({ api: api.baseURL, token, method, path, body });
  page = await session.open(`/spikes/write-request.html?${query}`);
  await page.waitForFunction(() => document.querySelector("#result")?.textContent !== "", { timeout });
  return page.$eval("#result", (node) => node.textContent);
}

const requests = (method) => api.received.filter((request) => request.method === method);

const posts = () => api.received.filter((request) => request.method === "POST");

describe("다른 출처 API에 쓰기 요청", () => {
  test("프리플라이트 뒤 인증 헤더와 JSON 본문으로 POST하고, 만든 할 일을 읽는다", async () => {
    assert.equal(await run(), "created 7 운동");

    const preflight = api.received.find((request) => request.method === "OPTIONS");
    assert.ok(preflight, "Authorization 헤더가 있으면 브라우저가 프리플라이트를 보낸다");
    assert.match(preflight.headers["access-control-request-headers"], /authorization/);
    const [post] = posts();
    assert.equal(post.path, "/todos");
    assert.equal(post.headers.authorization, "Bearer secret-token");
    assert.equal(post.headers["content-type"], "application/json");
    assert.deepEqual(JSON.parse(post.body), { title: "운동" });
  });

  test("토큰이 없으면 Authorization 없이 보내고 401을 unauthorized로 분류한다", async () => {
    api.reply = { status: 401, body: { title: "토큰 없음", status: 401 } };

    assert.equal(await run({ token: "" }), "unauthorized: 토큰 없음");
    assert.equal(posts()[0].headers.authorization, undefined);
  });

  test("401 Problem Details의 title을 공유 코드가 읽는다", async () => {
    api.reply = { status: 401, body: { type: "https://example.com/probs/expired", title: "토큰 만료", status: 401 } };

    assert.equal(await run(), "unauthorized: 토큰 만료");
  });

  test("409는 conflict로 분류한다", async () => {
    api.reply = { status: 409, body: { title: "이미 있는 할 일", status: 409 } };

    assert.equal(await run(), "conflict: 이미 있는 할 일");
  });

  test("5xx는 상태 코드와 Problem Details를 함께 넘긴다", async () => {
    api.reply = { status: 503, body: { title: "점검 중", status: 503 } };

    assert.equal(await run(), "status 503: 점검 중");
  });

  test("Problem Details가 아닌 오류 본문은 문제 없음으로 둔다", async () => {
    api.reply = { status: 502, body: "<html>Bad Gateway</html>" };

    assert.equal(await run(), "status 502: -");
  });

  test("서버가 CORS를 허용하지 않으면 POST는 나가지 않고 unreachable이 된다", async () => {
    api.allowCORS = false;

    assert.equal(await run(), "unreachable");
    assert.equal(posts().length, 0);
  });

  test("PATCH는 인증 헤더와 JSON 본문을 그대로 보낸다", async () => {
    api.reply = { status: 200, body: {} };

    assert.equal(await sendRaw({ method: "PATCH", path: "/todos/7", body: '{"done":true}' }), "status 200");

    const [patch] = requests("PATCH");
    assert.equal(patch.path, "/todos/7");
    assert.equal(patch.headers.authorization, "Bearer secret-token");
    assert.equal(patch.headers["content-type"], "application/json");
    assert.equal(patch.body, '{"done":true}');
  });

  test("본문 없는 DELETE는 Content-Type과 본문 없이 보낸다", async () => {
    api.reply = { status: 204, body: "" };

    assert.equal(await sendRaw({ method: "DELETE", path: "/todos/7" }), "status 204");

    const [deleted] = requests("DELETE");
    assert.equal(deleted.path, "/todos/7");
    assert.equal(deleted.headers.authorization, "Bearer secret-token");
    assert.equal(deleted.headers["content-type"], undefined);
    assert.equal(deleted.body, "");
  });

  test("프리플라이트가 PATCH를 허용하지 않으면 요청은 나가지 않고 unreachable이 된다", async () => {
    api.allowMethods = "POST";

    assert.equal(await sendRaw({ method: "PATCH", path: "/todos/7", body: "{}" }), "unreachable");
    assert.equal(requests("PATCH").length, 0);
  });
});
