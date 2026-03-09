#if canImport(SwiftUI)
import SwiftUI

public struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showSendMoney = false
    @State private var showTransactionList = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if viewModel.isLoading && viewModel.summary == nil {
                    LoadingView()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Welcome header
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Welcome back,")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(appState.currentUser?.username ?? "User")
                                        .font(.title2.bold())
                                }
                                Spacer()
                                Button(role: .none) {
                                    appState.signOut()
                                } label: {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // Balance cards
                            if let summary = viewModel.summary {
                                HStack(spacing: 12) {
                                    BalanceCard(
                                        title: "Total Sent",
                                        amount: summary.totalSent,
                                        icon: "arrow.up.circle.fill",
                                        color: .red
                                    )
                                    BalanceCard(
                                        title: "Total Received",
                                        amount: summary.totalReceived,
                                        icon: "arrow.down.circle.fill",
                                        color: .payPilotGreen
                                    )
                                }
                                .padding(.horizontal)

                                // Transaction count chip
                                HStack {
                                    Label(
                                        "\(summary.transactionCount) total transactions",
                                        systemImage: "list.bullet.rectangle"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }

                            // Error
                            if let error = viewModel.errorMessage {
                                ErrorView(message: error) {
                                    viewModel.loadDashboardData()
                                }
                                .padding(.horizontal)
                            }

                            // Send Money button
                            Button {
                                showSendMoney = true
                            } label: {
                                Label("Send Money", systemImage: "paperplane.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.payPilotBlue)
                            .padding(.horizontal)

                            // Recent transactions
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent Transactions")
                                        .font(.headline)
                                    Spacer()
                                    Button("See All") {
                                        showTransactionList = true
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.payPilotBlue)
                                }
                                .padding(.horizontal)

                                if viewModel.recentTransactions.isEmpty && !viewModel.isLoading {
                                    Text("No transactions yet.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                } else {
                                    ForEach(viewModel.recentTransactions) { tx in
                                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                                            TransactionRowView(transaction: tx)
                                                .padding(.horizontal)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                    .refreshable {
                        viewModel.loadDashboardData()
                    }
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showTransactionList) {
                TransactionListView()
            }
            .sheet(isPresented: $showSendMoney, onDismiss: {
                viewModel.loadDashboardData()
            }) {
                SendMoneyView()
            }
            .onAppear {
                viewModel.loadDashboardData()
            }
        }
    }
}

// MARK: - BalanceCard
private struct BalanceCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(amount.formatted(asCurrency: "USD"))
                .font(.title3.bold())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }
}

#endif // canImport(SwiftUI)
