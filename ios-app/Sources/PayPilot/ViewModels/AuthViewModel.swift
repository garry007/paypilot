import Foundation
#if canImport(Combine)
import Combine

public final class AuthViewModel: ObservableObject {
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var isLoggedIn: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - Login
    public func login(username: String, password: String) {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Username and password are required."
            return
        }

        isLoading = true
        errorMessage = nil

        let body = LoginRequest(username: username, password: password)

        apiClient.request(.login, body: body)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] (response: AuthResponse) in
                AppState.shared.signIn(
                    user: response.user,
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                self?.isLoggedIn = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Register
    public func register(username: String, email: String, password: String) {
        guard !username.isEmpty else {
            errorMessage = "Username is required."
            return
        }
        guard email.isValidEmail else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard password.isValidPassword else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        let body = RegisterRequest(username: username, email: email, password: password)

        apiClient.request(.register, body: body)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] (response: AuthResponse) in
                AppState.shared.signIn(
                    user: response.user,
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                self?.isLoggedIn = true
            }
            .store(in: &cancellables)
    }

    // MARK: - Logout
    public func logout() {
        apiClient.request(.logout, body: nil as String?)
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { (_: EmptyResponse) in }
            .store(in: &cancellables)

        AppState.shared.signOut()
        isLoggedIn = false
    }
}

// Used for endpoints that return an empty body
struct EmptyResponse: Codable {}
#endif // canImport(Combine)
