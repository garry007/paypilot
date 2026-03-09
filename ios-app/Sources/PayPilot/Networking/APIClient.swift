import Foundation
#if canImport(Combine)
import Combine

// MARK: - APIClientProtocol
public protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable?) -> AnyPublisher<T, NetworkError>
}

// MARK: - APIClient
public final class APIClient: APIClientProtocol {
    public static let shared = APIClient()

    private let session: URLSession
    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(session: URLSession = .shared) {
        self.session = session
        self.baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8000/api/v1"

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Public request method
    public func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable? = nil) -> AnyPublisher<T, NetworkError> {
        guard let urlRequest = buildRequest(endpoint: endpoint, body: body) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        return perform(urlRequest)
            .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                guard let self = self, error == .unauthorized else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                return self.refreshAndRetry(originalEndpoint: endpoint, body: body)
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Private helpers

    private func buildRequest(endpoint: Endpoint, body: Encodable?) -> URLRequest? {
        let urlString = baseURL + endpoint.path
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = KeychainManager.load(key: KeychainManager.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try? encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, NetworkError> {
        session.dataTaskPublisher(for: request)
            .mapError { NetworkError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<T, NetworkError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: NetworkError.unknown).eraseToAnyPublisher()
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return Just(data)
                        .decode(type: T.self, decoder: self.decoder)
                        .mapError { NetworkError.decodingError($0) }
                        .eraseToAnyPublisher()
                case 401:
                    return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
                case 404:
                    return Fail(error: NetworkError.notFound).eraseToAnyPublisher()
                default:
                    return Fail(error: NetworkError.serverError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }

    private func refreshAndRetry<T: Decodable>(originalEndpoint: Endpoint, body: Encodable?) -> AnyPublisher<T, NetworkError> {
        guard let refreshToken = KeychainManager.load(key: KeychainManager.refreshTokenKey),
              !refreshToken.isEmpty else {
            AppState.shared.signOut()
            return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
        }

        let refreshBody = ["refresh_token": refreshToken]

        guard let refreshURL = URL(string: baseURL + Endpoint.refreshToken.path) else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        var refreshRequest = URLRequest(url: refreshURL)
        refreshRequest.httpMethod = "POST"
        refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        refreshRequest.httpBody = try? JSONSerialization.data(withJSONObject: refreshBody)

        return session.dataTaskPublisher(for: refreshRequest)
            .mapError { NetworkError.networkError($0) }
            .flatMap { data, response -> AnyPublisher<AuthResponse, NetworkError> in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    return Fail(error: NetworkError.unauthorized).eraseToAnyPublisher()
                }
                return Just(data)
                    .decode(type: AuthResponse.self, decoder: self.decoder)
                    .mapError { NetworkError.decodingError($0) }
                    .eraseToAnyPublisher()
            }
            .flatMap { [weak self] authResponse -> AnyPublisher<T, NetworkError> in
                guard let self = self else {
                    return Fail(error: NetworkError.unknown).eraseToAnyPublisher()
                }
                KeychainManager.save(token: authResponse.accessToken, forKey: KeychainManager.accessTokenKey)
                KeychainManager.save(token: authResponse.refreshToken, forKey: KeychainManager.refreshTokenKey)
                guard let retryRequest = self.buildRequest(endpoint: originalEndpoint, body: body) else {
                    return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
                }
                return self.perform(retryRequest)
            }
            .catch { error -> AnyPublisher<T, NetworkError> in
                AppState.shared.signOut()
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - NetworkError Equatable
extension NetworkError: Equatable {
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound),
             (.unknown, .unknown):
            return true
        case (.serverError(let a), .serverError(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - AnyEncodable type-erased wrapper
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: Encodable) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
#endif // canImport(Combine)
