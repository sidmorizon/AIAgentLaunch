import Foundation

public enum LaunchConfigurationValidationError: Error, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case httpStatus(Int)
    case rejected(String)
}

extension LaunchConfigurationValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .unauthorized:
            return "Authorization failed (401). Check API key."
        case .forbidden:
            return "Access denied (403). The key does not have permission."
        case .notFound:
            return "Endpoint not found (404). Check Base URL path."
        case let .httpStatus(status):
            return "Request failed with HTTP \(status)."
        case let .rejected(message):
            return message
        }
    }
}

public final class LaunchConfigurationValidationService: Sendable {
    private let networking: any ModelDiscoveryNetworking

    public init(networking: any ModelDiscoveryNetworking = URLSession.shared) {
        self.networking = networking
    }

    public func validate(configuration: AgentProxyLaunchConfig) async throws {
        let endpointURL = resolveResponsesEndpoint(from: configuration.apiBaseURL)
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        if !configuration.providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(configuration.providerAPIKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ResponsesValidationRequest(
                model: configuration.modelIdentifier,
                input: "healthcheck",
                reasoning: .init(effort: configuration.reasoningLevel.rawValue),
                maxOutputTokens: 1
            )
        )

        let (data, response) = try await networking.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LaunchConfigurationValidationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            return
        case 401:
            if let message = rawHTTPErrorMessage(statusCode: 401, data: data) {
                throw LaunchConfigurationValidationError.rejected(message)
            }
            throw LaunchConfigurationValidationError.unauthorized
        case 403:
            if let message = rawHTTPErrorMessage(statusCode: 403, data: data) {
                throw LaunchConfigurationValidationError.rejected(message)
            }
            throw LaunchConfigurationValidationError.forbidden
        case 404:
            if let message = rawHTTPErrorMessage(statusCode: 404, data: data) {
                throw LaunchConfigurationValidationError.rejected(message)
            }
            throw LaunchConfigurationValidationError.notFound
        default:
            if let message = rawHTTPErrorMessage(statusCode: httpResponse.statusCode, data: data) {
                throw LaunchConfigurationValidationError.rejected(message)
            }
            throw LaunchConfigurationValidationError.httpStatus(httpResponse.statusCode)
        }
    }

    private func resolveResponsesEndpoint(from baseURL: URL) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL.appendingPathComponent("responses", isDirectory: false)
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.hasSuffix("responses") {
            return components.url ?? baseURL
        }

        if trimmedPath.isEmpty {
            components.path = "/responses"
        } else {
            components.path = components.path.hasSuffix("/") ? components.path + "responses" : components.path + "/responses"
        }

        return components.url ?? baseURL
    }

    private func rawHTTPErrorMessage(statusCode: Int, data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return "HTTP \(statusCode): \(text)"
    }
}

private struct ResponsesValidationRequest: Encodable {
    let model: String
    let input: String
    let reasoning: ReasoningPayload
    let maxOutputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case model
        case input
        case reasoning
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct ReasoningPayload: Encodable {
    let effort: String
}
