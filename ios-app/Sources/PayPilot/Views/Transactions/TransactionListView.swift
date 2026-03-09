#if canImport(SwiftUI)
import SwiftUI

public struct TransactionListView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var selectedStatus: TransactionStatus? = nil

    public init() {}

    private var filtered: [Transaction] {
        guard let status = selectedStatus else { return viewModel.transactions }
        return viewModel.transactions.filter { $0.status == status }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Status filter picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: selectedStatus == nil) {
                        selectedStatus = nil
                    }
                    ForEach(TransactionStatus.allCases, id: \.self) { status in
                        FilterChip(
                            label: status.displayName,
                            isSelected: selectedStatus == status,
                            color: status.color
                        ) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))

            Divider()

            if viewModel.isLoading && viewModel.transactions.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.transactions.isEmpty {
                ErrorView(message: error) {
                    viewModel.loadTransactions(refresh: true)
                }
            } else {
                List {
                    ForEach(filtered) { tx in
                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                            TransactionRowView(transaction: tx)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .onAppear {
                            if tx.id == filtered.last?.id {
                                viewModel.loadMore()
                            }
                        }
                    }

                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }

                    if !viewModel.hasMorePages && !filtered.isEmpty {
                        Text("No more transactions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewModel.loadTransactions(refresh: true)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel.transactions.isEmpty {
                viewModel.loadTransactions(refresh: true)
            }
        }
    }
}

// MARK: - FilterChip
private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var color: Color = .payPilotBlue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
                .foregroundColor(isSelected ? color : .secondary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
    }
}

#endif // canImport(SwiftUI)
