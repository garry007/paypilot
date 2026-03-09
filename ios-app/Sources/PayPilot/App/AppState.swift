import Foundation
#if canImport(Combine)
import Combine

public final class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User? = nil

    public static let shared = AppState()

    private init() {
        if let token = KeychainManager.load(key: KeychainManager.accessTokenKey), !token.isEmpty {
            isAuthenticated = true
        }
    }

    public func signIn(user: User, accessToken: String, refreshToken: String) {
        KeychainManager.save(token: accessToken, forKey: KeychainManager.accessTokenKey)
        KeychainManager.save(token: refreshToken, forKey: KeychainManager.refreshTokenKey)
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }

    public func signOut() {
        KeychainManager.delete(key: KeychainManager.accessTokenKey)
        KeychainManager.delete(key: KeychainManager.refreshTokenKey)
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
}
#endif // canImport(Combine)
