import Foundation

public enum TransactionStatus: String, Codable, CaseIterable {
    case pending
    case completed
    case failed
    case flagged

    public var displayName: String {
        rawValue.capitalized
    }
}

#if canImport(SwiftUI)
import SwiftUI
extension TransactionStatus {
    public var color: Color {
        switch self {
        case .completed: return .green
        case .pending:   return .yellow
        case .failed:    return .red
        case .flagged:   return .orange
        }
    }
}
#endif

public struct Transaction: Codable, Identifiable {
    public let id: String
    public let senderId: String
    public let recipientId: String
    public let amount: Double
    public let currency: String
    public let status: TransactionStatus
    public let description: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let fraudScore: Double?

    public init(
        id: String,
        senderId: String,
        recipientId: String,
        amount: Double,
        currency: String,
        status: TransactionStatus,
        description: String?,
        createdAt: Date,
        updatedAt: Date,
        fraudScore: Double?
    ) {
        self.id = id
        self.senderId = senderId
        self.recipientId = recipientId
        self.amount = amount
        self.currency = currency
        self.status = status
        self.description = description
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fraudScore = fraudScore
    }

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, status, description
        case senderId    = "sender_id"
        case recipientId = "recipient_id"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
        case fraudScore  = "fraud_score"
    }
}

public struct CurrencyStat: Codable {
    public let currency: String
    public let totalSent: Double
    public let totalReceived: Double

    public init(currency: String, totalSent: Double, totalReceived: Double) {
        self.currency = currency
        self.totalSent = totalSent
        self.totalReceived = totalReceived
    }

    enum CodingKeys: String, CodingKey {
        case currency
        case totalSent     = "total_sent"
        case totalReceived = "total_received"
    }
}

public struct TransactionSummary: Codable {
    public let totalSent: Double
    public let totalReceived: Double
    public let transactionCount: Int
    public let byCurrency: [CurrencyStat]

    public init(totalSent: Double, totalReceived: Double, transactionCount: Int, byCurrency: [CurrencyStat]) {
        self.totalSent = totalSent
        self.totalReceived = totalReceived
        self.transactionCount = transactionCount
        self.byCurrency = byCurrency
    }

    enum CodingKeys: String, CodingKey {
        case totalSent        = "total_sent"
        case totalReceived    = "total_received"
        case transactionCount = "transaction_count"
        case byCurrency       = "by_currency"
    }
}

public struct CreateTransactionRequest: Codable {
    public let amount: Double
    public let currency: String
    public let recipientId: String
    public let description: String?

    public init(amount: Double, currency: String, recipientId: String, description: String?) {
        self.amount = amount
        self.currency = currency
        self.recipientId = recipientId
        self.description = description
    }

    enum CodingKeys: String, CodingKey {
        case amount, currency, description
        case recipientId = "recipient_id"
    }
}

public struct PaginatedTransactions: Codable {
    public let items: [Transaction]
    public let total: Int
    public let page: Int
    public let limit: Int

    public init(items: [Transaction], total: Int, page: Int, limit: Int) {
        self.items = items
        self.total = total
        self.page = page
        self.limit = limit
    }
}
