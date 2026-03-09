#if canImport(SwiftUI)
import SwiftUI

public struct TransactionDetailView: View {
    let transaction: Transaction

    public init(transaction: Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Amount hero section
                VStack(spacing: 6) {
                    Text(transaction.amount.formatted(asCurrency: transaction.currency))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    StatusBadge(status: transaction.status)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: [transaction.status.color.opacity(0.12), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(16)
                .padding(.horizontal)

                // Details card
                GroupBox {
                    DetailRow(label: "Transaction ID", value: transaction.id)
                    Divider()
                    DetailRow(label: "Sender", value: transaction.senderId)
                    Divider()
                    DetailRow(label: "Recipient", value: transaction.recipientId)
                    Divider()
                    DetailRow(label: "Currency", value: transaction.currency)
                    Divider()
                    DetailRow(label: "Created", value: transaction.createdAt.displayString)
                    Divider()
                    DetailRow(label: "Updated", value: transaction.updatedAt.displayString)

                    if let desc = transaction.description, !desc.isEmpty {
                        Divider()
                        DetailRow(label: "Description", value: desc)
                    }
                } label: {
                    Label("Transaction Details", systemImage: "doc.text")
                        .font(.headline)
                }
                .padding(.horizontal)

                // Fraud risk card
                if let score = transaction.fraudScore {
                    GroupBox {
                        FraudRiskIndicator(score: score)
                    } label: {
                        Label("Fraud Analysis", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - StatusBadge
struct StatusBadge: View {
    let status: TransactionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundColor(status.color)
            .cornerRadius(8)
    }
}

// MARK: - DetailRow
private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 110, alignment: .leading)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - FraudRiskIndicator
struct FraudRiskIndicator: View {
    let score: Double

    private var riskColor: Color {
        switch score {
        case 0..<0.4:  return .green
        case 0.4..<0.7: return .orange
        default:        return .red
        }
    }

    private var riskLabel: String {
        switch score {
        case 0..<0.4:  return "Low Risk"
        case 0.4..<0.7: return "Medium Risk"
        default:        return "High Risk"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(riskLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(riskColor)
                Spacer()
                Text(String(format: "Score: %.2f", score))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(riskColor)
                        .frame(width: geo.size.width * min(score, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#endif // canImport(SwiftUI)
