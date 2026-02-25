import Foundation

public enum ModelDiscoveryServiceError: Error, Equatable, Sendable {
    case invalidResponse
    case unauthorized
    case httpStatus(Int)
    case decodeFailure
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
        let endpointURL = apiBaseURL.appendingPathComponent("models", isDirectory: false)
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
}

private struct ModelDiscoveryResponse: Decodable {
    let data: [ModelDiscoveryItem]
}

private struct ModelDiscoveryItem: Decodable {
    let id: String
}
