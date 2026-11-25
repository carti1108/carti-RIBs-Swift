// 쓰기 요청 스파이크(#31). 결과는 Swift가 `#result`에 쓴다. 뷰와 어댑터는 불러오지 않는다.
//   ?api=<다른 출처 주소>&token=<토큰>&title=<제목>                      공유 클라이언트로 `POST /todos`
//   ?api=...&token=...&method=PATCH&path=/todos/7&body=<JSON>           요청 하나를 그대로 보낸다
import { init } from "../support/swift";

const params = new URLSearchParams(location.search);
const get = (name: string) => params.get(name) ?? "";
const { exports } = await init();
if (params.has("method")) {
  exports.runTransportSpike(get("api"), get("token"), get("method"), get("path"), get("body"));
} else {
  exports.runWriteRequestSpike(get("api"), get("token"), get("title"));
}
