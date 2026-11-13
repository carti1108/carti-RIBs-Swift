import RIBs

/// 생명주기 콜백을 `이름.콜백`으로 기록하는 Interactor.
@MainActor
final class RecordingInteractor: Interactor {
    let name: String
    let log: EventLog
    var consumesBack = false
    var valueToSave: String?
    var onDidBecomeActive: (() -> Void)?
    var onWillResignActive: (() -> Void)?

    init(name: String, log: EventLog) {
        self.name = name
        self.log = log
        super.init()
    }

    /// 복원된 상태의 `value` 키.
    var restoredValue: String? { savedInstanceState?["value"]?.stringValue }

    override func didBecomeActive() {
        log.record("\(name).didBecomeActive")
        onDidBecomeActive?()
    }

    override func willResignActive() {
        log.record("\(name).willResignActive")
        onWillResignActive?()
    }

    override func handleBackPress() -> Bool { consumesBack }

    override func onSaveInstanceState(_ outState: inout [String: RibValue]) {
        if let valueToSave { outState["value"] = .string(valueToSave) }
    }
}

/// `didLoad`를 기록하는 Router.
@MainActor
final class RecordingRouter: Router<RecordingInteractor> {
    var onDidLoad: (() -> Void)?
    private(set) var didLoadCount = 0

    convenience init(_ name: String, log: EventLog) {
        self.init(interactor: RecordingInteractor(name: name, log: log))
    }

    override func didLoad() {
        didLoadCount += 1
        interactor.log.record("\(interactor.name).didLoad")
        onDidLoad?()
    }
}

/// 뷰를 가진 기록용 Router.
@MainActor
final class RecordingViewableRouter: ViewableRouter<RecordingInteractor, FakeView> {
    convenience init(_ name: String, log: EventLog) {
        self.init(interactor: RecordingInteractor(name: name, log: log), viewController: FakeView(name: name))
    }

    override func didLoad() {
        interactor.log.record("\(interactor.name).didLoad")
    }
}

/// 기록용 LaunchRouter.
@MainActor
final class RecordingLaunchRouter: LaunchRouter<RecordingInteractor, FakeView> {
    convenience init(_ name: String, log: EventLog) {
        self.init(interactor: RecordingInteractor(name: name, log: log), viewController: FakeView(name: name))
    }

    override func didLoad() {
        interactor.log.record("\(interactor.name).didLoad")
    }
}

/// `Router`를 상속하지 않은 가짜 자식. 호출 횟수만 센다.
@MainActor
final class FakeRouting: Routing {
    let interactable: any Interactable
    private(set) var loadCount = 0

    init(interactable: any Interactable = Interactor()) {
        self.interactable = interactable
    }

    var children: [any Routing] { [] }
    var lifecycle: AsyncStream<RouterLifecycle> { AsyncStream { _ in } }

    func load() { loadCount += 1 }
    func attachChild(_ child: any Routing) {}
    func detachChild(_ child: any Routing) {}
}

/// 호출 횟수를 세고, 선택적으로 `didStart`에서 취소될 때까지 도는 Task를 띄우는 Worker.
@MainActor
final class CountingWorker: Worker {
    private(set) var didStartCount = 0
    private(set) var didStopCount = 0
    private(set) var startedTask: Task<Void, Never>?
    var log: EventLog?
    var launchesTaskOnStart = false

    override func didStart(_ interactorScope: any InteractorScope) {
        didStartCount += 1
        log?.record("worker.didStart")
        if launchesTaskOnStart {
            startedTask = try? task { await suspendUntilCancelled() }
        }
    }

    override func didStop() {
        didStopCount += 1
        log?.record("worker.didStop")
    }
}
