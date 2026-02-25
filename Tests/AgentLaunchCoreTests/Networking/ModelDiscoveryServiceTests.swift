import Foundation
import XCTest
@testable import AgentLaunchCore

final class ModelDiscoveryServiceTests: XCTestCase {
    func testFetchModelsReturnsSortedModelIDs() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/v1/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"data\":[{\"id\":\"gpt-5\"},{\"id\":\"gpt-4.1\"},{\"id\":\"o3-mini\"}]}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        let modelIdentifiers = try await service.fetchModels(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test"
        )

        XCTAssertEqual(modelIdentifiers, ["gpt-4.1", "gpt-5", "o3-mini"])
    }

    func testFetchModelsMaps401ToUnauthorizedError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "sk-test"
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsMapsInvalidJSONToDecodeError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("not-json".utf8), response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "sk-test"
            )
            XCTFail("Expected decode failure error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .decodeFailure)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct StubModelDiscoveryNetworking: ModelDiscoveryNetworking {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}
