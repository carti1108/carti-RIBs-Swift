// 이 피처만 띄운다. 다른 피처의 뷰는 불러오지 않는다.
import { init } from "../../support/swift";
import { TodoDetailView } from "./view";

const { exports } = await init();
exports.startTodoDetailDemo(new TodoDetailView());
