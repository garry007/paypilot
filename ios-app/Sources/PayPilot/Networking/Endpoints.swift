import Foundation

public enum Endpoint {
    // Auth
    case login
    case register
    case refreshToken
    case me
    case logout

    // Transactions
    case createTransaction
    case listTransactions(page: Int, limit: Int)
    case getTransaction(id: String)
    case transactionStats

    // Fraud
    case analyzeFraud
    case fraudAlerts

    public var path: String {
        switch self {
        case .login:                         return "/auth/login"
        case .register:                      return "/auth/register"
        case .refreshToken:                  return "/auth/refresh"
        case .me:                            return "/auth/me"
        case .logout:                        return "/auth/logout"
        case .createTransaction:             return "/transactions"
        case .listTransactions(let page, let limit):
            return "/transactions?page=\(page)&limit=\(limit)"
        case .getTransaction(let id):        return "/transactions/\(id)"
        case .transactionStats:              return "/transactions/stats"
        case .analyzeFraud:                  return "/fraud/analyze"
        case .fraudAlerts:                   return "/fraud/alerts"
        }
    }

    public var method: String {
        switch self {
        case .login, .register, .refreshToken, .logout, .createTransaction, .analyzeFraud:
            return "POST"
        case .me, .listTransactions, .getTransaction, .transactionStats, .fraudAlerts:
            return "GET"
        }
    }
}
