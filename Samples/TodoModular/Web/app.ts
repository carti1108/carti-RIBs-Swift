// 전체 앱. 피처별 웹 뷰를 모두 넘기고, 조립은 Swift `TodoAppRoot`가 한다.
import { LoggedInView } from "./features/logged-in/view";
import { LoggedOutView } from "./features/logged-out/view";
import { TodoDetailView } from "./features/todo-detail/view";
import { TodoListView } from "./features/todo-list/view";
import { init } from "./support/swift";

const { exports } = await init();
exports.startTodoApp(new LoggedOutView(), new LoggedInView(), new TodoListView(), new TodoDetailView());
