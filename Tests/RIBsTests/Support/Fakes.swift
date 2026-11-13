import RIBs

/// 순서를 확인하기 위한 이벤트 기록. 테스트마다 새로 만든다.
@MainActor
final class EventLog {
    private(set) var entries: [String] = []

    func record(_ entry: String) {
        entries.append(entry)
    }

    func clear() {
        entries = []
    }
}

/// 이름만 가진 가짜 뷰.
@MainActor
final class FakeView: ViewControllable {
    let name: String

    init(name: String) {
        self.name = name
    }
}

/// show/hide 호출을 `show(name)`/`hide(name)`으로 기록하는 호스트.
@MainActor
final class RecordingHost: ViewHost {
    let log: EventLog

    init(log: EventLog = EventLog()) {
        self.log = log
    }

    func show(_ view: FakeView) {
        log.record("show(\(view.name))")
    }

    func hide(_ view: FakeView) {
        log.record("hide(\(view.name))")
    }
}

/// 테스트 클로저 사이에서 값을 주고받는 상자.
@MainActor
final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
