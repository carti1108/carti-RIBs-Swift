// 어댑터(뷰 계약 구현)가 들고 갱신하는 모델. 순수 뷰는 이 모델을 모르고 값만 받는다.
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
