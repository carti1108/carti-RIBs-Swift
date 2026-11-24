// 이 피처만 띄운다. 다른 피처의 뷰와 어댑터는 불러오지 않는다.
import { init } from "../../support/swift";
import { TodoDetailAdapter } from "./adapter";

const { exports } = await init();
exports.startTodoDetailDemo(new TodoDetailAdapter());
