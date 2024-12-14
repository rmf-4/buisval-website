import Foundation

enum APIConfig {
    // API Keys
    static let finnhubKey = "ct9nk81r01quh43ogj30ct9nk81r01quh43ogj3g"
    
    // Base URLs
    static let finnhubBaseURL = "https://finnhub.io/api/v1"
    static let finnhubWSURL = "wss://ws.finnhub.io"
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case noData
    case rateLimitExceeded
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data parsing error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please try again in a minute."
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
} 