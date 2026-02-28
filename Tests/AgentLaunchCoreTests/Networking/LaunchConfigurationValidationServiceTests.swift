import Foundation
import XCTest
@testable import AgentLaunchCore

final class LaunchConfigurationValidationServiceTests: XCTestCase {
    func testValidateSendsResponsesRequestWithModelAndReasoningEffort() async throws {
        let networking = StubLaunchValidationNetworking { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/v1/responses")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let payload = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
            XCTAssertEqual(json["model"] as? String, "gpt-5")
            XCTAssertEqual(json["input"] as? String, "healthcheck")
            XCTAssertEqual(json["max_output_tokens"] as? Int, 1)

            let reasoning = try XCTUnwrap(json["reasoning"] as? [String: Any])
            XCTAssertEqual(reasoning["effort"] as? String, "xhigh")

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"id\":\"resp_1\"}".utf8), response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        try await service.validate(
            configuration: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "sk-test",
                modelIdentifier: "gpt-5",
                reasoningLevel: .xhigh
            )
        )
    }

    func testValidateAppendsResponsesEndpointWhenBaseURLHasNoPath() async throws {
        let networking = StubLaunchValidationNetworking { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/responses")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        try await service.validate(
            configuration: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://example.com")!,
                providerAPIKey: "sk-test",
                modelIdentifier: "gpt-5",
                reasoningLevel: .high
            )
        )
    }

    func testValidateKeepsProvidedVersionPath() async throws {
        let networking = StubLaunchValidationNetworking { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.com/v2/responses")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        try await service.validate(
            configuration: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://example.com/v2")!,
                providerAPIKey: "sk-test",
                modelIdentifier: "gpt-5",
                reasoningLevel: .high
            )
        )
    }

    func testValidateMapsErrorMessageToRejectedError() async throws {
        let networking = StubLaunchValidationNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"error\":{\"message\":\"reasoning effort is not supported for model\"}}".utf8)
            return (body, response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        do {
            try await service.validate(
                configuration: AgentProxyLaunchConfig(
                    apiBaseURL: URL(string: "https://example.com/v1")!,
                    providerAPIKey: "sk-test",
                    modelIdentifier: "gpt-5",
                    reasoningLevel: .high
                )
            )
            XCTFail("Expected rejected validation error")
        } catch let error as LaunchConfigurationValidationError {
            XCTAssertEqual(error, .rejected("HTTP 400: {\"error\":{\"message\":\"reasoning effort is not supported for model\"}}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateOmitsAuthorizationHeaderWhenAPIKeyIsEmpty() async throws {
        let networking = StubLaunchValidationNetworking { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"id\":\"resp_1\"}".utf8), response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        try await service.validate(
            configuration: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://example.com/v1")!,
                providerAPIKey: "",
                modelIdentifier: "gpt-5",
                reasoningLevel: .medium
            )
        )
    }

    func testValidateMapsUnauthorizedRawErrorMessage() async throws {
        let networking = StubLaunchValidationNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"error\":{\"message\":\"API key missing\"}}".utf8)
            return (body, response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        do {
            try await service.validate(
                configuration: AgentProxyLaunchConfig(
                    apiBaseURL: URL(string: "https://example.com/v1")!,
                    providerAPIKey: "",
                    modelIdentifier: "gpt-5",
                    reasoningLevel: .medium
                )
            )
            XCTFail("Expected unauthorized validation error")
        } catch let error as LaunchConfigurationValidationError {
            XCTAssertEqual(error, .rejected("HTTP 401: {\"error\":{\"message\":\"API key missing\"}}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateMapsTopLevelMessageForUnauthorizedError() async throws {
        let networking = StubLaunchValidationNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"message\":\"missing api key\"}".utf8)
            return (body, response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        do {
            try await service.validate(
                configuration: AgentProxyLaunchConfig(
                    apiBaseURL: URL(string: "https://example.com/v1")!,
                    providerAPIKey: "",
                    modelIdentifier: "gpt-5",
                    reasoningLevel: .medium
                )
            )
            XCTFail("Expected unauthorized validation error")
        } catch let error as LaunchConfigurationValidationError {
            XCTAssertEqual(error, .rejected("HTTP 401: {\"message\":\"missing api key\"}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateMapsPlainTextBodyForUnauthorizedError() async throws {
        let networking = StubLaunchValidationNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("missing api key".utf8)
            return (body, response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        do {
            try await service.validate(
                configuration: AgentProxyLaunchConfig(
                    apiBaseURL: URL(string: "https://example.com/v1")!,
                    providerAPIKey: "",
                    modelIdentifier: "gpt-5",
                    reasoningLevel: .medium
                )
            )
            XCTFail("Expected unauthorized validation error")
        } catch let error as LaunchConfigurationValidationError {
            XCTAssertEqual(error, .rejected("HTTP 401: missing api key"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidateUsesRawJSONBodyForUnauthorizedError() async throws {
        let networking = StubLaunchValidationNetworking { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let body = Data("{\"message\":\"missing api key\"}".utf8)
            return (body, response)
        }
        let service = LaunchConfigurationValidationService(networking: networking)

        do {
            try await service.validate(
                configuration: AgentProxyLaunchConfig(
                    apiBaseURL: URL(string: "https://example.com/v1")!,
                    providerAPIKey: "",
                    modelIdentifier: "gpt-5",
                    reasoningLevel: .medium
                )
            )
            XCTFail("Expected unauthorized validation error")
        } catch let error as LaunchConfigurationValidationError {
            XCTAssertEqual(error, .rejected("HTTP 401: {\"message\":\"missing api key\"}"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct StubLaunchValidationNetworking: ModelDiscoveryNetworking {
    let handler: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}
