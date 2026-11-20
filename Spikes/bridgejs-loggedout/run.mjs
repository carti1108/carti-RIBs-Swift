// 웹 뷰 자리에 서는 JS 쪽 구현. Swift 프로토콜 LoggedOutViewBridge 를 객체로 구현한다.
import { instantiate } from "./.build/plugins/PackageToJS/outputs/Package/instantiate.js";
import { defaultNodeSetup } from "./.build/plugins/PackageToJS/outputs/Package/platforms/node.js";

const { exports } = await instantiate(await defaultNodeSetup({}));
const rendered = [];
const view = { render(state) { rendered.push(`error=${state.errorMessage ?? "-"} loading=${state.isLoading}`); } };

const handle = new exports.LoggedOutScreenHandle(view);
handle.activate();
const Tag = exports.LoggedOutViewAction.Tag;
handle.send({ tag: Tag.LoginTapped, rawName: "" });
handle.send({ tag: Tag.LoginTapped, rawName: "carti" });
console.log("lastName=" + handle.lastName());
rendered.forEach((r) => console.log(r));
const expected = ["error=- loading=false", "error=이름을 입력하세요 loading=false", "error=- loading=true"];
const ok = JSON.stringify(rendered) === JSON.stringify(expected);
console.log(ok ? "PASS" : "FAIL");
process.exit(ok ? 0 : 1);
