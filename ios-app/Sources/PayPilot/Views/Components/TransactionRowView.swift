#if canImport(SwiftUI)
import SwiftUI

public struct TransactionRowView: View {
    let transaction: Transaction

    public init(transaction: Transaction) {
        self.transaction = transaction
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(transaction.status.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon)
                    .foregroundColor(transaction.status.color)
                    .font(.system(size: 18))
            }

            // Center info
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.recipientId)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(transaction.createdAt.shortDateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Right side: amount + status
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.formatted(asCurrency: transaction.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(amountColor)

                StatusBadge(status: transaction.status)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private var statusIcon: String {
        switch transaction.status {
        case .completed: return "checkmark.circle.fill"
        case .pending:   return "clock.fill"
        case .failed:    return "xmark.circle.fill"
        case .flagged:   return "exclamationmark.shield.fill"
        }
    }

    private var amountColor: Color {
        switch transaction.status {
        case .completed: return .payPilotGreen
        case .failed:    return .red
        default:         return .primary
        }
    }
}

#endif // canImport(SwiftUI)
