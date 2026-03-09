#if canImport(Combine)
import XCTest
import Combine
@testable import PayPilot

// MARK: - TransactionMockAPIClient
final class TransactionMockAPIClient: APIClientProtocol {
    var listResult: Result<PaginatedTransactions, NetworkError> = .failure(.unknown)
    var statsResult: Result<TransactionSummary, NetworkError> = .failure(.unknown)
    var createResult: Result<Transaction, NetworkError> = .failure(.unknown)

    // Track how many times list is called for pagination testing
    var listCallCount = 0

    func request<T: Decodable>(_ endpoint: Endpoint, body: Encodable?) -> AnyPublisher<T, NetworkError> {
        let result: Result<T, NetworkError>

        switch endpoint {
        case .listTransactions:
            listCallCount += 1
            result = cast(listResult)
        case .transactionStats:
            result = cast(statsResult)
        case .createTransaction:
            result = cast(createResult)
        default:
            result = .failure(.unknown)
        }

        return result.publisher.eraseToAnyPublisher()
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

// MARK: - Factories
private func makeTransaction(
    id: String = UUID().uuidString,
    status: TransactionStatus = .completed,
    amount: Double = 100.0
) -> Transaction {
    Transaction(
        id: id,
        senderId: "sender-1",
        recipientId: "recipient-1",
        amount: amount,
        currency: "USD",
        status: status,
        description: "Test payment",
        createdAt: Date(),
        updatedAt: Date(),
        fraudScore: nil
    )
}

private func makePaginated(
    items: [Transaction],
    total: Int = 100,
    page: Int = 1,
    limit: Int = 20
) -> PaginatedTransactions {
    PaginatedTransactions(items: items, total: total, page: page, limit: limit)
}

private func makeSummary() -> TransactionSummary {
    TransactionSummary(
        totalSent: 500.0,
        totalReceived: 300.0,
        transactionCount: 10,
        byCurrency: ["USD": 800.0]
    )
}

// MARK: - TransactionViewModelTests
final class TransactionViewModelTests: XCTestCase {
    private var mockClient: TransactionMockAPIClient!
    private var viewModel: TransactionViewModel!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockClient = TransactionMockAPIClient()
        viewModel = TransactionViewModel(apiClient: mockClient)
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockClient = nil
        super.tearDown()
    }

    // MARK: - Load transactions

    func test_loadTransactions_success_populatesList() {
        let transactions = (0..<5).map { makeTransaction(id: "tx-\($0)") }
        mockClient.listResult = .success(makePaginated(items: transactions, total: 5))

        let expectation = expectation(description: "Transactions loaded")

        viewModel.$transactions
            .dropFirst()
            .sink { txs in
                if !txs.isEmpty { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.loadTransactions(refresh: true)

        wait(for: [expectation], timeout: 3)

        XCTAssertEqual(viewModel.transactions.count, 5)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_loadTransactions_failure_setsError() {
        mockClient.listResult = .failure(.serverError(500))

        let expectation = expectation(description: "Error set")

        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.loadTransactions(refresh: true)

        wait(for: [expectation], timeout: 3)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.transactions.isEmpty)
    }

    func test_loadTransactions_refresh_clearsExisting() {
        // Pre-populate
        let first = (0..<3).map { makeTransaction(id: "old-\($0)") }
        mockClient.listResult = .success(makePaginated(items: first, total: 3))

        let firstExpectation = expectation(description: "First load")
        viewModel.$transactions.dropFirst().first().sink { _ in firstExpectation.fulfill() }.store(in: &cancellables)
        viewModel.loadTransactions(refresh: true)
        wait(for: [firstExpectation], timeout: 3)

        // Refresh with new data
        let fresh = (0..<2).map { makeTransaction(id: "new-\($0)") }
        mockClient.listResult = .success(makePaginated(items: fresh, total: 2))

        let refreshExpectation = expectation(description: "Refresh clears old")
        viewModel.$transactions.dropFirst().first().sink { txs in
            if txs.allSatisfy({ $0.id.hasPrefix("new-") }) {
                refreshExpectation.fulfill()
            }
        }.store(in: &cancellables)
        viewModel.loadTransactions(refresh: true)
        wait(for: [refreshExpectation], timeout: 3)

        XCTAssertEqual(viewModel.transactions.count, 2)
        XCTAssertTrue(viewModel.transactions.allSatisfy { $0.id.hasPrefix("new-") })
    }

    // MARK: - Load summary

    func test_loadSummary_success_setsSummary() {
        mockClient.statsResult = .success(makeSummary())

        let expectation = expectation(description: "Summary loaded")

        viewModel.$summary
            .compactMap { $0 }
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        viewModel.loadSummary()

        wait(for: [expectation], timeout: 3)

        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.totalSent, 500.0)
        XCTAssertEqual(viewModel.summary?.totalReceived, 300.0)
        XCTAssertEqual(viewModel.summary?.transactionCount, 10)
    }

    func test_loadSummary_failure_setsError() {
        mockClient.statsResult = .failure(.networkError(URLError(.notConnectedToInternet)))

        let expectation = expectation(description: "Error set")
        viewModel.$errorMessage.compactMap { $0 }.sink { _ in expectation.fulfill() }.store(in: &cancellables)

        viewModel.loadSummary()
        wait(for: [expectation], timeout: 3)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.summary)
    }

    // MARK: - Create transaction

    func test_createTransaction_success_insertsAtTop() {
        let newTx = makeTransaction(id: "new-tx", amount: 250.0)
        mockClient.createResult = .success(newTx)

        let expectation = expectation(description: "Transaction inserted")

        viewModel.$transactions
            .dropFirst()
            .sink { txs in
                if txs.first?.id == "new-tx" { expectation.fulfill() }
            }
            .store(in: &cancellables)

        viewModel.createTransaction(
            amount: 250.0,
            currency: "USD",
            recipientId: "recipient-1",
            description: "Test"
        )

        wait(for: [expectation], timeout: 3)

        XCTAssertEqual(viewModel.transactions.first?.id, "new-tx")
        XCTAssertEqual(viewModel.transactions.first?.amount, 250.0)
    }

    func test_createTransaction_zeroAmount_setsError() {
        viewModel.createTransaction(amount: 0, currency: "USD", recipientId: "r1", description: nil)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_createTransaction_emptyRecipient_setsError() {
        viewModel.createTransaction(amount: 100, currency: "USD", recipientId: "", description: nil)

        XCTAssertNotNil(viewModel.errorMessage)
    }

    func test_createTransaction_failure_setsError() {
        mockClient.createResult = .failure(.serverError(422))

        let expectation = expectation(description: "Create error set")
        viewModel.$errorMessage.compactMap { $0 }.sink { _ in expectation.fulfill() }.store(in: &cancellables)

        viewModel.createTransaction(amount: 100, currency: "USD", recipientId: "r1", description: nil)
        wait(for: [expectation], timeout: 3)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.transactions.isEmpty)
    }

    // MARK: - Pagination

    func test_pagination_hasMorePages_whenTotalExceedsLoaded() {
        let items = (0..<20).map { makeTransaction(id: "p1-\($0)") }
        // total 100 > 20 loaded → hasMorePages true
        mockClient.listResult = .success(makePaginated(items: items, total: 100, page: 1, limit: 20))

        let expectation = expectation(description: "First page loaded")
        viewModel.$transactions.dropFirst().first().sink { _ in expectation.fulfill() }.store(in: &cancellables)
        viewModel.loadTransactions(refresh: true)
        wait(for: [expectation], timeout: 3)

        XCTAssertTrue(viewModel.hasMorePages)
    }

    func test_pagination_hasNoMorePages_whenAllLoaded() {
        let items = (0..<5).map { makeTransaction(id: "p-\($0)") }
        // total 5 ≤ 20 → hasMorePages false
        mockClient.listResult = .success(makePaginated(items: items, total: 5, page: 1, limit: 20))

        let expectation = expectation(description: "All loaded")
        viewModel.$transactions.dropFirst().first().sink { _ in expectation.fulfill() }.store(in: &cancellables)
        viewModel.loadTransactions(refresh: true)
        wait(for: [expectation], timeout: 3)

        XCTAssertFalse(viewModel.hasMorePages)
    }

    func test_loadMore_appendsNextPage() {
        // Page 1
        let page1 = (0..<20).map { makeTransaction(id: "p1-\($0)") }
        mockClient.listResult = .success(makePaginated(items: page1, total: 40, page: 1, limit: 20))

        let firstLoad = expectation(description: "Page 1 loaded")
        viewModel.$transactions.dropFirst().first().sink { _ in firstLoad.fulfill() }.store(in: &cancellables)
        viewModel.loadTransactions(refresh: true)
        wait(for: [firstLoad], timeout: 3)

        XCTAssertEqual(viewModel.transactions.count, 20)

        // Page 2
        let page2 = (0..<20).map { makeTransaction(id: "p2-\($0)") }
        mockClient.listResult = .success(makePaginated(items: page2, total: 40, page: 2, limit: 20))

        let secondLoad = expectation(description: "Page 2 appended")
        viewModel.$transactions
            .filter { $0.count == 40 }
            .first()
            .sink { _ in secondLoad.fulfill() }
            .store(in: &cancellables)
        viewModel.loadMore()
        wait(for: [secondLoad], timeout: 3)

        XCTAssertEqual(viewModel.transactions.count, 40)
        XCTAssertEqual(mockClient.listCallCount, 2)
    }
}

#endif // canImport(Combine)
