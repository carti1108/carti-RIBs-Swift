/// 부모 RIB이 제공해야 하는 의존성의 표식. RIBs-iOS `Dependency`.
@MainActor
public protocol Dependency: AnyObject {}

/// 아무것도 필요 없는 RIB의 Dependency. RIBs-iOS `EmptyDependency`.
@MainActor
public protocol EmptyDependency: Dependency {}

/// RIB이 만들고 자식에게 넘기는 의존성 묶음. RIBs-iOS `Component<DependencyType>`.
/// 자식 RIB의 Dependency 프로토콜을 구현해 자식 Builder에 자신을 넘긴다(수동 DI).
@MainActor
open class Component<DependencyType>: Dependency {
    public let dependency: DependencyType
    private var sharedInstances: [String: AnyObject] = [:]

    public init(dependency: DependencyType) {
        self.dependency = dependency
    }

    /// 이 Component 인스턴스 안에서 한 번만 만들어지는 값. RIBs-iOS `shared { }`.
    /// 계산 프로퍼티 안에서 `shared { ... }`로 쓰며, 호출한 프로퍼티 이름이 키가 된다.
    public final func shared<T>(_ key: String = #function, _ factory: () -> T) -> T {
        if let box = sharedInstances[key] as? SharedBox<T> { return box.value }
        let instance = factory()
        sharedInstances[key] = SharedBox(instance)
        return instance
    }
}

/// `shared` 캐시 항목. `T`가 Optional이어도 nil을 그대로 담도록 상자에 넣는다.
private final class SharedBox<T> {
    let value: T
    init(_ value: T) { self.value = value }
}

/// 루트 RIB에 넘기는 빈 Component. RIBs-iOS `EmptyComponent`.
@MainActor
open class EmptyComponent: EmptyDependency {
    public init() {}
}
