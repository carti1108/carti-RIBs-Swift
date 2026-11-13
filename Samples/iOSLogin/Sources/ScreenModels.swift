// 화면 객체(뷰 계약 구현)는 이 모델을 들고 갱신만 한다.
import LoginShared
import Observation

@MainActor @Observable
final class LoggedOutModel {
    var errorMessage: String?
    var isLoading = false
}

@MainActor @Observable
final class LoggedInModel {
    var userName = ""
    var sessionSeconds: Int64 = 0
}

@MainActor @Observable
final class TodoListModel {
    var todos: [Todo] = []
}

@MainActor @Observable
final class TodoDetailModel {
    var title = ""
    var isDone = false
}
