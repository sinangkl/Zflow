import Foundation

// MARK: - API Config

enum ZFlowAPIConfig {
    static let webhookBaseURL  = "https://zflow.online/api"
    static let unifiedAIEndpoint = "https://zflow.online/api/chat"
    static let analyzeStatementEndpoint = "https://zflow.online/api/upload" // PDF/CSV analysis endpoint
    static let apiKey          = "21d412ffb2f5b69de6f4dfd1fcddebe5a8d1373628d35ebe52bbef3cdf27136d"
    static let storageBucket   = "receipts"
    static let receiptUploadEndpoint = "https://zflow.online/api/upload"
    nonisolated static let fullUploadURL = "https://zflow.online/api/upload"
}
