import XCTest
import SwiftUI
@testable import Service

final class ServiceTests: XCTestCase {
    func testExample() throws {}
}
// for now I'm just testing that below code builds

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

extension Result where Failure == Error {
  init(catching body: () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
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

struct GoogleView_Previews/*: Not a PreviewProvider*/ {
  @ViewBuilder static var previews: some View {
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

