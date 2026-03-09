#if canImport(Combine)
import XCTest
import Combine
@testable import PayPilot

final class AuthViewModelTests: XCTestCase {
    private var mockClient: MockAPIClient!
    private var viewModel: AuthViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockClient = MockAPIClient()
        viewModel = AuthViewModel(apiClient: mockClient)
        cancellables = []
        // Ensure keychain is clean before each test
        KeychainManager.delete(key: KeychainManager.accessTokenKey)
        KeychainManager.delete(key: KeychainManager.refreshTokenKey)
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockClient = nil
        KeychainManager.delete(key: KeychainManager.accessTokenKey)
        KeychainManager.delete(key: KeychainManager.refreshTokenKey)
        super.tearDown()
    }

    // MARK: - Login tests

    func test_login_success_updatesAppState() {
        mockClient.loginResult = .success(makeAuthResponse())

        let expectation = expectation(description: "Login succeeds")

        viewModel.$isLoggedIn
            .dropFirst()
            .sink { isLoggedIn in
                if isLoggedIn { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.login(username: "testuser", password: "password123")

        wait(for: [expectation], timeout: 3)

        XCTAssertTrue(viewModel.isLoggedIn)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_login_failure_setsErrorMessage() {
        mockClient.loginResult = .failure(.unauthorized)

        let expectation = expectation(description: "Error set")

        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.login(username: "testuser", password: "wrongpassword")

        wait(for: [expectation], timeout: 3)

        XCTAssertFalse(viewModel.isLoggedIn)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_login_emptyUsername_setsErrorWithoutCallingAPI() {
        viewModel.login(username: "", password: "password123")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoggedIn)
    }

    func test_login_emptyPassword_setsErrorWithoutCallingAPI() {
        viewModel.login(username: "testuser", password: "")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoggedIn)
    }

    func test_login_storesTokensInKeychain() {
        mockClient.loginResult = .success(makeAuthResponse())

        let expectation = expectation(description: "Login stores tokens")

        viewModel.$isLoggedIn
            .dropFirst()
            .sink { isLoggedIn in
                if isLoggedIn { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.login(username: "testuser", password: "password123")

        wait(for: [expectation], timeout: 3)

        let storedAccess = KeychainManager.load(key: KeychainManager.accessTokenKey)
        let storedRefresh = KeychainManager.load(key: KeychainManager.refreshTokenKey)
        XCTAssertEqual(storedAccess, "access-token-abc")
        XCTAssertEqual(storedRefresh, "refresh-token-xyz")
    }

    // MARK: - Register tests

    func test_register_success_updatesAppState() {
        mockClient.registerResult = .success(makeAuthResponse())

        let expectation = expectation(description: "Register succeeds")

        viewModel.$isLoggedIn
            .dropFirst()
            .sink { isLoggedIn in
                if isLoggedIn { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.register(username: "newuser", email: "new@example.com", password: "securePass1")

        wait(for: [expectation], timeout: 3)

        XCTAssertTrue(viewModel.isLoggedIn)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_register_invalidEmail_setsError() {
        viewModel.register(username: "user", email: "not-an-email", password: "securePass1")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoggedIn)
    }

    func test_register_shortPassword_setsError() {
        viewModel.register(username: "user", email: "user@example.com", password: "123")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoggedIn)
    }

    func test_register_emptyUsername_setsError() {
        viewModel.register(username: "", email: "user@example.com", password: "securePass1")

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoggedIn)
    }

    func test_register_serverError_setsErrorMessage() {
        mockClient.registerResult = .failure(.serverError(500))

        let expectation = expectation(description: "Server error message set")

        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.register(username: "user", email: "user@example.com", password: "securePass1")

        wait(for: [expectation], timeout: 3)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Validation tests

    func test_validEmail_returnsTrue() {
        XCTAssertTrue("user@example.com".isValidEmail)
        XCTAssertTrue("user.name+tag@sub.domain.co".isValidEmail)
    }

    func test_invalidEmail_returnsFalse() {
        XCTAssertFalse("notanemail".isValidEmail)
        XCTAssertFalse("@nodomain".isValidEmail)
        XCTAssertFalse("noat.com".isValidEmail)
    }

    func test_validPassword_atLeast8Chars() {
        XCTAssertTrue("12345678".isValidPassword)
        XCTAssertFalse("1234567".isValidPassword)
        XCTAssertFalse("".isValidPassword)
    }
}

#endif // canImport(Combine)
