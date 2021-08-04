# Service
- SwiftUI solves dependency injection in an ingenious, extensible way.
- The EnvironmentValues struct can resolve services from arbitrary, even user defined EnvironmentKeys.
- Furthermore, SwiftUI allows you to modify the environment at any point in the view tree. This means you can have different services injected into a subtree of Views.
- So you can go nuts with configurations, should you need to, which you probably won’t.
- So, what's a good service?
    - A good service can do anything.
    - By default, it stays in its domain and does what you'd expect.
    - But when developing or testing, you may want it to do all kinds of crazy things.
    - So it should have access to the whole environment, to be able to do anything.
  
```
@dynamicMemberLookup protocol Service: EnvironmentKey where Value == Self {
  init()
  @MainActor var environment: EnvironmentValues { get set }
  typealias Endpoint<Action> = (EnvironmentValues) -> Action
  
  associatedtype Endpoints
  @MainActor var endpoints: Endpoints { get }
}
extension Service {
  static var defaultValue: Self { .init() }
}

extension Service {
  @MainActor subscript<Action>(dynamicMember keyPath: KeyPath<Endpoints, Endpoint<Action>>) -> Action {
    endpoints[keyPath: keyPath](environment)
  }
}

extension EnvironmentValues {
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

extension Environment where Value: Service {
  init() {
    self.init(\.[service: \Value.self])
  }
}

```
- Wow, thats both stupid and stupid complicated 👍, but how is it to use?

```
struct Google: Service {
  var environment: EnvironmentValues = .init()
  var endpoints = (
    open: { environment in
      { query in
        environment.openURL(url(for: query))
      }
    } as Endpoint<(String) -> Void>,
    fetch: { environment in
      { query in
        //we're using `shared` session here, but we might as well retrieve one from the environment
        let session = URLSession.shared
        let (data, response) = try await session.data(from: url(for: query))
        return data
      }
    } as Endpoint<(String) async throws -> Data>
  )
  
  private static func url(for query: String) -> URL {
    var components = URLComponents(string: "https://www.google.com")!
    components.queryItems = [URLQueryItem(name: "q", value: query)]
    return components.url!
  }
}

struct GoogleView: View {
  @Environment() private var google: Google
  
  @State var query: String = ""
  @State var fetchedData: Result<Data, Error>?
  @State var currentRequest: Task<(), Never>?
  var body: some View {
    VStack {
      HStack {
        TextField("Search", text: $query)
        Button {
          currentRequest?.cancel()
          currentRequest = Task {
            fetchedData = await Result {
              try await google.fetch(query)
            }
          }
        } label: {
          Text("Fetch")
        }
        Button {
          google.open(query)
        } label: {
          Text("Open")
        }
      }
    }
    Text("Result: " + String(describing: fetchedData))
  }
}

// helper
extension Result where Failure == Error {
  init(catching body: () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}

```
- Why?

```
struct GoogleView_Previews: PreviewProvider {
  static var previews: some View {
    // default config
    GoogleView()
    // fetch from google but open in duckduckgo
    GoogleView()
      .environment(
        \.[service: \Google.self].endpoints.open,
         { environment in
           { query in
             var components = URLComponents(string: "https://www.duckduckgo.com")!
             components.queryItems = [URLQueryItem(name: "q", value: query)]
             environment.openURL(components.url!)
           }
         }
      )
  }
}
```
