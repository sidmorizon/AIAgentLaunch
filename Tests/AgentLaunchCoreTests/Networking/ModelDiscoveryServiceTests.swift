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
            XCTAssertEqual(error, .unauthorized())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsMaps403ToForbiddenError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "sk-test"
            )
            XCTFail("Expected forbidden error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .forbidden())
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsMaps404ToNotFoundError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "sk-test"
            )
            XCTFail("Expected not found error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .notFound())
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

    func testFetchModelsAppendsV1ModelsWhenBaseURLHasNoVersionPath() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/v1/models")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"data\":[{\"id\":\"gpt-5\"}]}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        _ = try await service.fetchModels(
            apiBaseURL: URL(string: "https://example.com")!,
            providerAPIKey: "sk-test"
        )
    }

    func testFetchModelsOmitsAuthorizationHeaderWhenAPIKeyIsEmpty() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"data\":[{\"id\":\"gpt-5\"}]}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        _ = try await service.fetchModels(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: ""
        )
    }

    func testFetchModelsUsesRawServerMessageForUnauthorizedError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"error\":{\"message\":\"API key missing\"}}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: ""
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .unauthorized(message: "HTTP 401: {\"error\":{\"message\":\"API key missing\"}}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsUsesTopLevelMessageForUnauthorizedError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"message\":\"missing api key\"}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: ""
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .unauthorized(message: "HTTP 401: {\"message\":\"missing api key\"}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsUsesPlainTextBodyForUnauthorizedError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("missing api key".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: ""
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .unauthorized(message: "HTTP 401: missing api key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchModelsUsesRawJSONBodyForUnauthorizedError() async throws {
        let networking = StubModelDiscoveryNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"message\":\"missing api key\"}".utf8)
            return (body, response)
        }
        let service = ModelDiscoveryService(networking: networking)

        do {
            _ = try await service.fetchModels(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: ""
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ModelDiscoveryServiceError {
            XCTAssertEqual(error, .unauthorized(message: "HTTP 401: {\"message\":\"missing api key\"}"))
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
