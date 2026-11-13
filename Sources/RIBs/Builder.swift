/// RIBs-iOS `Buildable`. 각 RIB의 `XxxBuildable` 프로토콜이 상속한다.
@MainActor
public protocol Buildable: AnyObject {}

/// Component를 만들고 Router·Interactor·뷰를 조립한다. RIBs-iOS `Builder<DependencyType>`.
/// 하위 클래스가 `build(...)`를 정의한다. 런타임 인자는 `build`의 인자로, 오래 사는 의존성은 `dependency`에서 꺼낸다.
@MainActor
open class Builder<DependencyType>: Buildable {
    public let dependency: DependencyType

    public init(dependency: DependencyType) {
        self.dependency = dependency
    }
}

/// 빌드할 때마다 새 Component를 만드는 Builder. RIBs-iOS `ComponentizedBuilder`.
/// 하위 클래스는 `build(with:_:)`를 재정의한다. 원본의 "같은 Component 재사용" 검사는 옮기지 않았다.
@MainActor
open class ComponentizedBuilder<Component, Router, DynamicBuildDependency, DynamicComponentDependency>: Buildable {
    private let componentBuilder: (DynamicComponentDependency) -> Component

    public init(componentBuilder: @escaping (DynamicComponentDependency) -> Component) {
        self.componentBuilder = componentBuilder
    }

    public final func build(
        withDynamicBuildDependency dynamicBuildDependency: DynamicBuildDependency,
        dynamicComponentDependency: DynamicComponentDependency
    ) -> Router {
        build(withDynamicBuildDependency: dynamicBuildDependency, dynamicComponentDependency: dynamicComponentDependency).1
    }

    public final func build(
        withDynamicBuildDependency dynamicBuildDependency: DynamicBuildDependency,
        dynamicComponentDependency: DynamicComponentDependency
    ) -> (Component, Router) {
        let component = componentBuilder(dynamicComponentDependency)
        return (component, build(with: component, dynamicBuildDependency))
    }

    /// 재정의 지점. 기본 구현은 실패한다.
    open func build(with component: Component, _ dynamicBuildDependency: DynamicBuildDependency) -> Router {
        fatalError("\(type(of: self)) must override build(with:_:)")
    }
}

/// 동적 의존성이 없는 `ComponentizedBuilder`. RIBs-iOS `SimpleComponentizedBuilder`.
@MainActor
open class SimpleComponentizedBuilder<Component, Router>: ComponentizedBuilder<Component, Router, Void, Void> {
    public init(componentBuilder: @escaping () -> Component) {
        super.init(componentBuilder: { _ in componentBuilder() })
    }

    public final func build() -> Router {
        build(withDynamicBuildDependency: (), dynamicComponentDependency: ())
    }

    public final override func build(with component: Component, _ dynamicBuildDependency: Void) -> Router {
        build(with: component)
    }

    /// 재정의 지점. 기본 구현은 실패한다.
    open func build(with component: Component) -> Router {
        fatalError("\(type(of: self)) must override build(with:)")
    }
}
