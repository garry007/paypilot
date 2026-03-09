import Foundation
#if canImport(Combine)
import Combine

public final class DashboardViewModel: ObservableObject {
    @Published public var summary: TransactionSummary? = nil
    @Published public var recentTransactions: [Transaction] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let apiClient: APIClientProtocol

    public init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    // MARK: - Load all dashboard data
    public func loadDashboardData() {
        isLoading = true
        errorMessage = nil

        let summaryPub: AnyPublisher<TransactionSummary, NetworkError> =
            apiClient.request(.transactionStats, body: nil as String?)

        let recentPub: AnyPublisher<PaginatedTransactions, NetworkError> =
            apiClient.request(.listTransactions(page: 1, limit: 5), body: nil as String?)

        summaryPub
            .zip(recentPub)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.errorDescription
                }
            } receiveValue: { [weak self] summary, paginated in
                self?.summary = summary
                self?.recentTransactions = paginated.items
            }
            .store(in: &cancellables)
    }
}
#endif // canImport(Combine)
