import Foundation

public struct User: Codable, Identifiable {
    public let id: String
    public let username: String
    public let email: String
    public let createdAt: Date
    public let isActive: Bool

    public init(id: String, username: String, email: String, createdAt: Date, isActive: Bool) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.isActive = isActive
    }

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case createdAt = "created_at"
        case isActive = "is_active"
    }
}

public struct AuthResponse: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}

public struct LoginRequest: Codable {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct RegisterRequest: Codable {
    public let username: String
    public let email: String
    public let password: String

    public init(username: String, email: String, password: String) {
        self.username = username
        self.email = email
        self.password = password
    }
}
