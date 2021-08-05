import SwiftUI

public typealias Endpoint<Action> = (EnvironmentValues) -> Action

@dynamicMemberLookup public struct Service<Key: EnvironmentKey> {
  var environment: EnvironmentValues
  var endpoints: Key.Value
}

public extension Service {
  subscript<Action>(dynamicMember keyPath: KeyPath<Key.Value, Endpoint<Action>>) -> Action {
    endpoints[keyPath: keyPath](environment)
  }
  
  func callAsFunction<Action>() -> Action where Key.Value == Endpoint<Action> {
    endpoints(environment)
  }
}

public extension EnvironmentValues {
  subscript<Key: EnvironmentKey>(service keyPath: KeyPath<Key, Key> = \Key.self) -> Service<Key> {
    .init(environment: self, endpoints: self[Key.self])
  }
}

extension Environment {
  init<Key>() where Value == Service<Key>, Key.Value == Key {
    self.init(\.[service: \Key.self])
  }
}

