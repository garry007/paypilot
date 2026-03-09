import Foundation

public enum RiskLevel: String, Codable {
    case low
    case medium
    case high

    public var displayName: String {
        rawValue.capitalized
    }
}

public struct FraudAnalysis: Codable {
    public let transactionId: String
    public let fraudScore: Double
    public let riskLevel: RiskLevel
    public let flags: [String]
    public let recommendation: String

    public init(
        transactionId: String,
        fraudScore: Double,
        riskLevel: RiskLevel,
        flags: [String],
        recommendation: String
    ) {
        self.transactionId = transactionId
        self.fraudScore = fraudScore
        self.riskLevel = riskLevel
        self.flags = flags
        self.recommendation = recommendation
    }

    enum CodingKeys: String, CodingKey {
        case fraudScore    = "fraud_score"
        case riskLevel     = "risk_level"
        case transactionId = "transaction_id"
        case flags, recommendation
    }
}
