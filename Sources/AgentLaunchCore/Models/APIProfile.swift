import Foundation

public struct APIProfile: Equatable, Sendable, Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var baseURLText: String
    public var apiKey: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, baseURLText: String, apiKey: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.baseURLText = baseURLText
        self.apiKey = apiKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case baseURLText
        case apiKey
        case createdAt
        case updatedAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        baseURLText = try container.decode(String.self, forKey: .baseURLText)
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
