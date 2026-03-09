# PayPilot iOS App

The PayPilot iOS client is a SwiftUI application that provides a native mobile interface for the PayPilot fintech platform. It follows the MVVM (Model–View–ViewModel) architecture pattern with Combine for reactive data binding.

---

## Architecture

### Pattern: MVVM + Combine

```
┌─────────────────────────────────────────────────────────────┐
│                         Views (SwiftUI)                      │
│   Declarative UI – subscribe to @Published state from VMs    │
└──────────────────────────┬──────────────────────────────────┘
                           │ @StateObject / @ObservedObject
┌──────────────────────────▼──────────────────────────────────┐
│                      ViewModels                              │
│   @MainActor ObservableObjects – business logic & state     │
│   Combine pipelines for async operations                     │
└──────────────────────────┬──────────────────────────────────┘
                           │ async/await calls
┌──────────────────────────▼──────────────────────────────────┐
│                  Networking (APIClient)                       │
│   URLSession-based HTTP client – encodes/decodes JSON        │
│   Throws typed NetworkError values                           │
└──────────────────────────┬──────────────────────────────────┘
                           │ REST over HTTPS
                    API Gateway :8000
```

### Key design decisions

- **Single `APIClient` instance** injected via the SwiftUI environment so it can be swapped for a mock in tests.
- **`KeychainManager`** handles all secure credential storage (tokens, user ID) using the iOS Keychain Services API.
- **`AppState`** is the single source of truth for authentication status and is observed by the root view to drive navigation.
- **Error handling** uses a typed `NetworkError` enum that maps HTTP status codes to user-friendly messages surfaced through `ErrorView`.

---

## Directory Structure

```
ios-app/
├── Package.swift                        ← Swift package manifest
├── Sources/
│   └── PayPilot/
│       ├── App/
│       │   ├── PayPilotApp.swift        ← @main entry point
│       │   └── AppState.swift           ← Global auth / nav state
│       ├── Models/
│       │   ├── User.swift               ← Codable user model
│       │   ├── Transaction.swift        ← Codable transaction model
│       │   └── FraudAlert.swift         ← Codable fraud alert model
│       ├── Networking/
│       │   ├── APIClient.swift          ← URLSession HTTP client
│       │   ├── Endpoints.swift          ← API endpoint definitions
│       │   └── NetworkError.swift       ← Typed error enum
│       ├── Utilities/
│       │   ├── Extensions.swift         ← Swift/Foundation extensions
│       │   └── KeychainManager.swift    ← Secure token storage
│       └── Views/
│           ├── Auth/
│           │   ├── LoginView.swift      ← Login screen
│           │   └── RegisterView.swift   ← Registration screen
│           ├── Dashboard/
│           │   └── DashboardView.swift  ← Home screen with balance & recent txns
│           ├── Transactions/
│           │   ├── TransactionListView.swift   ← Paginated transaction list
│           │   ├── TransactionDetailView.swift ← Single transaction details
│           │   └── SendMoneyView.swift         ← Payment initiation form
│           └── Components/
│               ├── LoadingView.swift    ← Reusable loading spinner overlay
│               ├── ErrorView.swift      ← Reusable error banner / alert
│               └── TransactionRowView.swift ← List row for a transaction
└── Tests/
    └── PayPilotTests/
        ├── AuthViewModelTests.swift        ← Unit tests for AuthViewModel
        ├── TransactionViewModelTests.swift ← Unit tests for TransactionViewModel
        └── MockAPIClient.swift             ← Test double for APIClient
```

---

## Key Components

### `PayPilotApp.swift`

The application entry point. Creates the shared `APIClient` and `AppState` objects, injects them into the SwiftUI environment, and presents the root navigation view.

### `AppState.swift`

An `@MainActor ObservableObject` that tracks:
- `isAuthenticated: Bool` — drives the root view switch between auth and main flows
- `currentUser: User?` — the signed-in user profile
- Token refresh coordination

### `APIClient.swift`

A generic async HTTP client built on `URLSession`. Key methods:

```swift
// Generic GET
func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T

// Generic POST with encodable body
func post<Body: Encodable, Response: Decodable>(
    _ endpoint: Endpoint,
    body: Body
) async throws -> Response
```

Automatically attaches the stored access token to every request and handles 401 responses by attempting a token refresh before retrying.

### `KeychainManager.swift`

Wraps Keychain Services to store and retrieve:
- `accessToken` — short-lived JWT
- `refreshToken` — long-lived rotation token
- `userId` — cached user identifier

### `AuthViewModel.swift`

Manages the login and registration flows:

```swift
@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(username: String, password: String) async
    func register(username: String, email: String, password: String) async
    func logout() async
}
```

### `TransactionViewModel.swift`

Drives the transaction list and send-money screens:

```swift
@MainActor
class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var summary: TransactionSummary?
    @Published var isLoading = false

    func loadTransactions() async
    func loadSummary() async
    func sendMoney(recipientId: Int, amount: Decimal, currency: String, description: String) async
}
```

### `DashboardViewModel.swift`

Aggregates data for the home screen, loading the transaction summary and recent transactions on appear.

---

## How to Build and Run

### Command line

```bash
cd ios-app

# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test
swift test --parallel   # faster
```

### Xcode

```bash
# Open the package in Xcode
open ios-app/Package.swift
# or
xed ios-app/
```

1. Select a simulator target from the toolbar (iPhone 15, iOS 17 recommended).
2. Press **⌘R** to build and run.
3. Use the **Test navigator** (⌘6) to run individual tests.

### Pointing at a different backend

Edit `Sources/PayPilot/Networking/Endpoints.swift` and change `baseURL`:

```swift
// Local Docker Compose stack
static let baseURL = "http://localhost:8000"

// Staging
static let baseURL = "https://api-staging.paypilot.example.com"
```

---

## Testing

Tests live in `Tests/PayPilotTests/` and use the XCTest framework.

### Test strategy

| File                          | Tests                                              |
|-------------------------------|----------------------------------------------------|
| `AuthViewModelTests.swift`    | Login success/failure, register, logout            |
| `TransactionViewModelTests.swift` | List loading, send money, error propagation   |
| `MockAPIClient.swift`         | Configurable test double – stub responses & errors |

### Running tests

```bash
# All tests
swift test

# Specific test case
swift test --filter AuthViewModelTests

# With verbose output
swift test -v
```

### Writing new tests

Use `MockAPIClient` to inject controlled responses:

```swift
func testLoginFailure() async throws {
    let mock = MockAPIClient()
    mock.stubbedError = NetworkError.unauthorized
    let vm = AuthViewModel(apiClient: mock)

    await vm.login(username: "bad", password: "wrong")

    XCTAssertNotNil(vm.errorMessage)
    XCTAssertFalse(vm.isLoading)
}
```

---

## Supported Platforms

| Platform | Minimum version |
|----------|-----------------|
| iOS      | 16.0            |
| macOS    | 13.0 (for Swift package tests) |
