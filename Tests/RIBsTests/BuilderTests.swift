import Testing
@testable import RIBs

@MainActor
private final class Service {}

@MainActor
private protocol ChildDependency: Dependency {
    var service: Service { get }
}

@MainActor
private final class ParentComponent: Component<any EmptyDependency>, ChildDependency {
    private(set) var serviceFactoryCalls = 0
    private(set) var optionalFactoryCalls = 0

    var service: Service {
        shared {
            serviceFactoryCalls += 1
            return Service()
        }
    }

    var otherService: Service { shared { Service() } }

    var optionalValue: Int? {
        shared {
            optionalFactoryCalls += 1
            return nil
        }
    }
}

@MainActor
private final class ChildBuilder: Builder<any ChildDependency> {
    func build() -> Router<Interactor> {
        Router(interactor: Interactor())
    }
}

@MainActor
private final class ChildComponent: Component<any ChildDependency> {
    let label: String

    init(dependency: any ChildDependency, label: String) {
        self.label = label
        super.init(dependency: dependency)
    }
}

/// 동적 의존성 두 개를 받는 Builder. 컴포넌트는 `label`을, 빌드 인자는 tag를 정한다.
@MainActor
private final class DynamicChildBuilder:
    ComponentizedBuilder<ChildComponent, Router<Interactor>, String, String>
{
    private(set) var receivedBuildDependencies: [String] = []

    init(parent: any ChildDependency) {
        super.init { label in ChildComponent(dependency: parent, label: label) }
    }

    override func build(with component: ChildComponent, _ dynamicBuildDependency: String) -> Router<Interactor> {
        receivedBuildDependencies.append(dynamicBuildDependency)
        return Router(interactor: Interactor())
    }
}

@MainActor
private final class SimpleChildBuilder: SimpleComponentizedBuilder<ChildComponent, Router<Interactor>> {
    private(set) var components: [ChildComponent] = []

    init(parent: any ChildDependency) {
        super.init { ChildComponent(dependency: parent, label: "simple") }
    }

    override func build(with component: ChildComponent) -> Router<Interactor> {
        components.append(component)
        return Router(interactor: Interactor())
    }
}

@MainActor
struct BuilderTests {
    @Test func shared_returnsSameInstanceWithinComponent() {
        // Given
        let component = ParentComponent(dependency: EmptyComponent())

        // When
        let first = component.service
        let second = component.service

        // Then
        #expect(first === second)
    }

    @Test func shared_isCreatedLazilyOnFirstAccess() {
        // Given
        let component = ParentComponent(dependency: EmptyComponent())
        #expect(component.serviceFactoryCalls == 0)

        // When
        _ = component.service
        _ = component.service

        // Then
        #expect(component.serviceFactoryCalls == 1)
    }

    @Test func shared_isDistinctPerComponentInstance() {
        // Given
        let first = ParentComponent(dependency: EmptyComponent())
        let second = ParentComponent(dependency: EmptyComponent())

        // When / Then
        #expect(first.service !== second.service)
    }

    @Test func shared_isDistinctPerProperty() {
        // Given
        let component = ParentComponent(dependency: EmptyComponent())

        // When / Then
        #expect(component.service !== component.otherService)
    }

    @Test func shared_cachesNilOptionalValue() {
        // Given
        let component = ParentComponent(dependency: EmptyComponent())

        // When
        _ = component.optionalValue
        _ = component.optionalValue

        // Then
        #expect(component.optionalValue == nil)
        #expect(component.optionalFactoryCalls == 1)
    }

    @Test func childBuilder_receivesDependencyFromParentComponent() {
        // Given
        let parent = ParentComponent(dependency: EmptyComponent())

        // When
        let builder = ChildBuilder(dependency: parent)

        // Then
        #expect(builder.dependency.service === parent.service)
        #expect(!builder.build().interactable.isActive)
    }

    @Test func componentizedBuilder_createsNewComponentPerBuildAndPassesDynamicDependencies() {
        // Given
        let parent = ParentComponent(dependency: EmptyComponent())
        let builder = DynamicChildBuilder(parent: parent)

        // When
        let (first, _): (ChildComponent, Router<Interactor>) =
            builder.build(withDynamicBuildDependency: "b1", dynamicComponentDependency: "c1")
        let (second, _): (ChildComponent, Router<Interactor>) =
            builder.build(withDynamicBuildDependency: "b2", dynamicComponentDependency: "c2")
        let _: Router<Interactor> = builder.build(withDynamicBuildDependency: "b3", dynamicComponentDependency: "c3")

        // Then
        #expect(first !== second)
        #expect([first.label, second.label] == ["c1", "c2"])
        #expect(builder.receivedBuildDependencies == ["b1", "b2", "b3"])
        #expect(first.dependency.service === parent.service)
    }

    @Test func simpleComponentizedBuilder_buildsWithFreshComponent() {
        // Given
        let builder = SimpleChildBuilder(parent: ParentComponent(dependency: EmptyComponent()))

        // When
        _ = builder.build()
        _ = builder.build()

        // Then
        #expect(builder.components.count == 2)
        #expect(builder.components[0] !== builder.components[1])
    }
}
