import Foundation
#if canImport(Combine)
import Combine

public final class TransactionViewModel: ObservableObject {
    @Published public var transactions: [Transaction] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var summary: TransactionSummary? = nil
    @Published public var hasMorePages: Bool = true

    private var currentPage = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()

    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - Load transactions (paginated)
    public func loadTransactions(refresh: Bool = false) {
        guard !isLoading else { return }

        if refresh {
            currentPage = 1
            hasMorePages = true
            transactions = []
        }

        guard hasMorePages else { return }

        isLoading = true
        errorMessage = nil

        apiClient.request(.listTransactions(page: currentPage, limit: pageSize), body: nil as String?)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] (paginated: PaginatedTransactions) in
                guard let self = self else { return }
                if refresh {
                    self.transactions = paginated.items
                } else {
                    self.transactions.append(contentsOf: paginated.items)
                }
                self.hasMorePages = (self.currentPage * self.pageSize) < paginated.total
                self.currentPage += 1
            }
            .store(in: &cancellables)
    }

    // MARK: - Load summary / stats
    public func loadSummary() {
        apiClient.request(.transactionStats, body: nil as String?)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] (summary: TransactionSummary) in
                self?.summary = summary
            }
            .store(in: &cancellables)
    }

    // MARK: - Create transaction
    public func createTransaction(
        amount: Double,
        currency: String,
        recipientId: String,
        description: String?
    ) {
        guard amount > 0 else {
            errorMessage = "Amount must be greater than zero."
            return
        }
        guard !recipientId.isEmpty else {
            errorMessage = "Recipient ID is required."
            return
        }

        isLoading = true
        errorMessage = nil

        let body = CreateTransactionRequest(
            amount: amount,
            currency: currency,
            recipientId: recipientId,
            description: description
        )

        apiClient.request(.createTransaction, body: body)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] (newTx: Transaction) in
                self?.transactions.insert(newTx, at: 0)
            }
            .store(in: &cancellables)
    }

    // MARK: - Load more (pagination)
    public func loadMore() {
        loadTransactions(refresh: false)
    }
}
#endif // canImport(Combine)
