import Foundation
import UIKit
import Supabase

// MARK: - Scanned Receipt Model

struct ScannedReceipt: Identifiable {
    let id = UUID()
    let amount: Double
    let currency: String
    let merchant: String
    let category: String
    let categoryId: String? // "groceries", "shopping" etc.
    let date: Date
    let note: String
    let type: String // "expense" | "income"
    let taxNumber: String
    let salesItems: [[String: Any]]
    let imageUrl: String // Supabase Storage public URL
}

// MARK: - Scan Error

enum ScanError: LocalizedError {
    case invalidURL
    case imageProcessingFailed
    case uploadFailed(String)
    case networkError(Error)
    case unauthorized
    case rateLimited
    case serverError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return NSLocalizedString("scan.error.invalidURL", comment: "")
        case .imageProcessingFailed:  return NSLocalizedString("scan.error.imageProcessing", comment: "")
        case .uploadFailed(let msg):  return "Upload failed: \(msg)"
        case .networkError(let e):    return String(format: NSLocalizedString("scan.error.network", comment: ""), e.localizedDescription)
        case .unauthorized:           return NSLocalizedString("scan.error.unauthorized", comment: "")
        case .rateLimited:            return NSLocalizedString("scan.error.rateLimited", comment: "")
        case .serverError(let c, _):  return String(format: NSLocalizedString("scan.error.server", comment: ""), c)
        case .invalidResponse:        return NSLocalizedString("scan.error.invalidResponse", comment: "")
        }
    }
}

// MARK: - Receipt Scan Service

actor ReceiptScanService {
    struct ReceiptResponse: Codable {
        let status: String
        let receipt_data: ReceiptInfo?
    }

    struct ReceiptInfo: Codable {
        let market: String?
        let total: Double?
        let category_id: String?
        let note: String?
        let image_url: String?
        let date: String?
    }
    
    static let shared = ReceiptScanService()
    private init() {}

    func scan(image: UIImage, userId: String, businessId: String? = nil) async throws -> ScannedReceipt {
        guard let url = URL(string: ZFlowAPIConfig.fullUploadURL) else {
            throw ScanError.invalidURL
        }

        // Prepare image
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            throw ScanError.imageProcessingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        // user_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userId)\r\n".data(using: .utf8)!)

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScanError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            throw ScanError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown Error")
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(ReceiptResponse.self, from: data)

        if result.status == "success", let info = result.receipt_data {
            let merchant = info.market ?? ""
            let amount = info.total ?? 0.0
            let catId = info.category_id ?? "other"
            let note = info.note ?? merchant
            let imgUrl = info.image_url ?? ""
            
            // Parse date if possible
            var scanDate = Date()
            let isoFormatter = ISO8601DateFormatter()
            let ymdFormatter = DateFormatter()
            ymdFormatter.dateFormat = "yyyy-MM-dd"

            if let dateStr = info.date, let d = isoFormatter.date(from: dateStr) {
                scanDate = d
            } else if let dateStr = info.date, let d = ymdFormatter.date(from: dateStr) {
                // If it's today's date, we use the current exact time so it appears at the top of lists.
                if Calendar.current.isDateInToday(d) {
                    scanDate = Date()
                } else {
                    scanDate = d
                }
            } else {
                scanDate = .now
            }

            return ScannedReceipt(
                amount: amount,
                currency: "TRY",
                merchant: merchant,
                category: catId,
                categoryId: catId,
                date: scanDate,
                note: note,
                type: "expense",
                taxNumber: "",
                salesItems: [],
                imageUrl: imgUrl
            )
        } else {
            throw ScanError.invalidResponse
        }
    }
}
