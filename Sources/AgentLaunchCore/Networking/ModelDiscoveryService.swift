import Foundation

public enum ModelDiscoveryServiceError: Error, Equatable, Sendable {
    case invalidResponse
    case unauthorized(message: String? = nil)
    case forbidden(message: String? = nil)
    case notFound(message: String? = nil)
    case httpStatus(Int, message: String? = nil)
    case decodeFailure
}

extension ModelDiscoveryServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case let .unauthorized(message):
            return message ?? "HTTP 401"
        case let .forbidden(message):
            return message ?? "HTTP 403"
        case let .notFound(message):
            return message ?? "HTTP 404"
        case let .httpStatus(status, message):
            return message ?? "HTTP \(status)"
        case .decodeFailure:
            return "Unable to parse model list response."
        }
    }
}

public protocol ModelDiscoveryNetworking: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: ModelDiscoveryNetworking {}

public final class ModelDiscoveryService: Sendable {
    private let networking: any ModelDiscoveryNetworking

    public init(networking: any ModelDiscoveryNetworking = URLSession.shared) {
        self.networking = networking
    }

    public func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String] {
        let endpointURL = resolveModelsEndpoint(from: apiBaseURL)
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        if !providerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(providerAPIKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await networking.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw ModelDiscoveryServiceError.unauthorized(message: rawHTTPErrorMessage(statusCode: 401, data: data))
        case 403:
            throw ModelDiscoveryServiceError.forbidden(message: rawHTTPErrorMessage(statusCode: 403, data: data))
        case 404:
            throw ModelDiscoveryServiceError.notFound(message: rawHTTPErrorMessage(statusCode: 404, data: data))
        default:
            throw ModelDiscoveryServiceError.httpStatus(httpResponse.statusCode, message: rawHTTPErrorMessage(statusCode: httpResponse.statusCode, data: data))
        }

        do {
            let payload = try JSONDecoder().decode(ModelDiscoveryResponse.self, from: data)
            return payload.data.map(\.id).sorted()
        } catch is DecodingError {
            throw ModelDiscoveryServiceError.decodeFailure
        }
    }

    private func resolveModelsEndpoint(from baseURL: URL) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return baseURL
                .appendingPathComponent("v1", isDirectory: false)
                .appendingPathComponent("models", isDirectory: false)
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.hasSuffix("models") {
            return components.url ?? baseURL
        }

        if trimmedPath.hasSuffix("v1") {
            components.path = components.path.hasSuffix("/") ? components.path + "models" : components.path + "/models"
        } else if trimmedPath.isEmpty {
            components.path = "/v1/models"
        } else {
            components.path = components.path.hasSuffix("/") ? components.path + "v1/models" : components.path + "/v1/models"
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

private struct ModelDiscoveryResponse: Decodable {
    let data: [ModelDiscoveryItem]
}

private struct ModelDiscoveryItem: Decodable {
    let id: String
}
