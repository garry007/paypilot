import Foundation
#if canImport(Combine)
import Combine
@testable import PayPilot

// MARK: - MockAPIClient
final class MockAPIClient: APIClientProtocol {
    var loginResult: Result<AuthResponse, NetworkError> = .failure(.unknown)
    var registerResult: Result<AuthResponse, NetworkError> = .failure(.unknown)
    var logoutResult: Result<EmptyResponse, NetworkError> = .success(EmptyResponse())

    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable?) -> AnyPublisher<T, NetworkError> {
        let result: Result<T, NetworkError>

        switch endpoint {
        case .login:
            result = cast(loginResult)
        case .register:
            result = cast(registerResult)
        case .logout:
            result = cast(logoutResult)
        default:
            result = .failure(.unknown)
        }

        return result.publisher
            .mapError { $0 }
            .eraseToAnyPublisher()
    }

    private func cast<A, B>(_ result: Result<A, NetworkError>) -> Result<B, NetworkError> {
        switch result {
        case .success(let value):
            if let typed = value as? B {
                return .success(typed)
            }
            return .failure(.decodingError(CastError()))
        case .failure(let error):
            return .failure(error)
        }
    }
}

struct CastError: Error {}

// MARK: - Helpers
func makeUser() -> User {
    User(
        id: "user-123",
        username: "testuser",
        email: "test@example.com",
        createdAt: Date(),
        isActive: true
    )
}

func makeAuthResponse() -> AuthResponse {
    AuthResponse(
        accessToken: "access-token-abc",
        refreshToken: "refresh-token-xyz",
        tokenType: "bearer",
        user: makeUser()
    )
}
#endif // canImport(Combine)
