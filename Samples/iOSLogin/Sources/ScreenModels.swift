// 화면 객체(뷰 계약 구현)는 이 모델을 들고 갱신만 한다.
import LoginShared
import Observation

@MainActor @Observable
final class LoggedOutModel {
    var state = LoggedOutViewState()
}

@MainActor @Observable
final class LoggedInModel {
    var state = LoggedInViewState(userName: "")
}

@MainActor @Observable
final class TodoListModel {
    var state = TodoListViewState()
}

@MainActor @Observable
final class TodoDetailModel {
    var state = TodoDetailViewState(title: "", isDone: false)
}
