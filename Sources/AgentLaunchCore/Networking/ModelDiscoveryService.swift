import Foundation

public enum ModelDiscoveryServiceError: Error, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case httpStatus(Int)
    case decodeFailure
}

extension ModelDiscoveryServiceError: LocalizedError {
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
        request.setValue("Bearer \(providerAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await networking.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelDiscoveryServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ... 299:
            break
        case 401:
            throw ModelDiscoveryServiceError.unauthorized
        case 403:
            throw ModelDiscoveryServiceError.forbidden
        case 404:
            throw ModelDiscoveryServiceError.notFound
        default:
            throw ModelDiscoveryServiceError.httpStatus(httpResponse.statusCode)
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
}

private struct ModelDiscoveryResponse: Decodable {
    let data: [ModelDiscoveryItem]
}

private struct ModelDiscoveryItem: Decodable {
    let id: String
}
