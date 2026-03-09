import Foundation

public struct User: Codable, Identifiable {
    public let id: Int
    public let username: String
    public let email: String
    public let isActive: Bool
    public let isAdmin: Bool
    public let createdAt: Date

    public init(id: Int, username: String, email: String, isActive: Bool, isAdmin: Bool, createdAt: Date) {
        self.id = id
        self.username = username
        self.email = email
        self.isActive = isActive
        self.isAdmin = isAdmin
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isActive  = "is_active"
        case isAdmin   = "is_admin"
        case createdAt = "created_at"
    }
}

public struct AuthResponse: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case tokenType    = "token_type"
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
