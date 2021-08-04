import SwiftUI

@dynamicMemberLookup public protocol Service: EnvironmentKey where Value == Self {
  init() // technically this isn't required but it works out nicely with structs (no `defaultValue` declaration needed)
  @MainActor var environment: EnvironmentValues { get set }
  typealias Endpoint<Action> = (EnvironmentValues) -> Action
  associatedtype Endpoints
  
  @MainActor // this probably isn't enough to make each endpoint @MainActor, but will ensure MainActor on all reasonable ways of calling this
  // implementations can still ensure @MainActor on accessing Endpoints' properties, but an Endpoints struct is needed (won't work with tuple)
  var endpoints: Endpoints { get }
}
public extension Service {
  static var defaultValue: Self { .init() }
}

public extension Service {
  @MainActor subscript<Action>(dynamicMember keyPath: KeyPath<Endpoints, Endpoint<Action>>) -> Action {
    endpoints[keyPath: keyPath](environment)
  }
}

public extension Service {
  // afaik there's no easy way to get rid of the annoying `service()(params)` at callsite
  // we would have to start overloading for different `Action` shapes
  @MainActor func callAsFunction<Action>() -> Action where Endpoints == Endpoint<Action> {
    endpoints(environment)
  }
}

public extension EnvironmentValues {
  @MainActor subscript<S: Service>(service keyPath: KeyPath<S, S>) -> S {
    get {
      var instance = self[S.self]
      instance.environment = self
      return instance
    }
    set {
      self[S.self] = newValue
    }
  }
}

public extension Environment where Value: Service {
  init() {
    self.init(\.[service: \Value.self])
  }
}
