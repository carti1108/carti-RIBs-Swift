// 전체 앱. 피처별 어댑터를 모두 넘기고, 조립은 Swift `TodoAppRoot`가 한다.
import { LoggedInAdapter } from "./features/logged-in/adapter";
import { LoggedOutAdapter } from "./features/logged-out/adapter";
import { TodoDetailAdapter } from "./features/todo-detail/adapter";
import { TodoListAdapter } from "./features/todo-list/adapter";
import { init } from "./support/swift";

const { exports } = await init();
exports.startTodoApp(new LoggedOutAdapter(), new LoggedInAdapter(), new TodoListAdapter(), new TodoDetailAdapter());
