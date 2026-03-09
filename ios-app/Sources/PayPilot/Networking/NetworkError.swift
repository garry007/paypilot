import Foundation

public enum NetworkError: LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .unauthorized:
            return "You are not authorized. Please log in again."
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let code):
            return "Server error with status code: \(code)."
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred."
        }
    }
}
