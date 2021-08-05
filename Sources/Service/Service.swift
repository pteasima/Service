import SwiftUI

@dynamicMemberLookup public protocol Service: EnvironmentKey where Value == Self {
  init() // technically this isn't required but it works out nicely with structs (no `defaultValue` declaration needed)
  var environment: EnvironmentValues { get set }
  typealias Endpoint<Action> = (EnvironmentValues) -> Action
  associatedtype Endpoints
  
  var endpoints: Endpoints { get }
}
public extension Service {
  static var defaultValue: Self { .init() }
}

public extension Service {
  subscript<Action>(dynamicMember keyPath: KeyPath<Endpoints, Endpoint<Action>>) -> Action {
    endpoints[keyPath: keyPath](environment)
  }
}

public extension Service {
  // afaik there's no easy way to get rid of the annoying `service()(params)` at callsite
  // we would have to start overloading for different `Action` shapes
  func callAsFunction<Action>() -> Action where Endpoints == Endpoint<Action> {
    endpoints(environment)
  }
}

public extension EnvironmentValues {
  subscript<S: Service>(service keyPath: KeyPath<S, S>) -> S {
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
