import Foundation
import UIKit
import Supabase

// MARK: - API Config

enum ZFlowAPIConfig {
    static let webhookBaseURL  = "https://api.zflow.online"
    static let receiptEndpoint = "\(webhookBaseURL)/webhook/receipt-scan"
    static let apiKey          = "21d412ffb2f5b69de6f4dfd1fcddebe5a8d1373628d35ebe52bbef3cdf27136d"
    static let storageBucket   = "receipts"
}

// MARK: - Scanned Receipt Model

struct ScannedReceipt {
    let amount: Double
    let currency: String
    let merchant: String
    let category: String
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
    static let shared = ReceiptScanService()
    private init() {}

    func scan(image: UIImage, userId: String, businessId: String? = nil) async throws -> ScannedReceipt {
        // 1. Görseli sıkıştır — UIImage işlemi actor dışında (nonisolated helper) yapılır
        let resized = zf_resizeImage(image, toMaxDimension: 1024)
        guard let jpegData = resized.jpegData(compressionQuality: 0.7) else {
            throw ScanError.imageProcessingFailed
        }

        // 2. Supabase Storage'a yükle
        let imageUrl = try await uploadToStorage(data: jpegData, userId: userId)
        print("🔍 [ReceiptScan] Image uploaded: \(imageUrl)")

        // 3. Config değerlerini yerel değişkene al (actor isolation sorununu giderir)
        let endpoint = await ZFlowAPIConfig.receiptEndpoint
        let apiKey   = await ZFlowAPIConfig.apiKey

        guard let url = URL(string: endpoint) else {
            throw ScanError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 90

        var payload: [String: Any] = [
            "imageUrl": imageUrl,
            "userId": userId
        ]
        if let bizId = businessId {
            payload["businessId"] = bizId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        // 4. İstek gönder
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ScanError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ScanError.networkError(URLError(.badServerResponse))
        }

        // DEBUG log
        if let rawString = String(data: data, encoding: .utf8) {
            print("🔍 [ReceiptScan] HTTP \(http.statusCode) - Raw response: \(rawString)")
        }

        switch http.statusCode {
        case 200...299:
            return try parseResponse(data, fallbackImageUrl: imageUrl)
        case 401:
            throw ScanError.unauthorized
        case 429:
            throw ScanError.rateLimited
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ScanError.serverError(http.statusCode, body)
        }
    }

    // MARK: - Upload to Supabase Storage

    private func uploadToStorage(data: Data, userId: String) async throws -> String {
        let fileName = "\(userId)/\(Int(Date().timeIntervalSince1970)).jpg"
        let bucket   = await ZFlowAPIConfig.storageBucket

        do {
            // Updated API: upload(_:data:options:)  — path is first arg, no label
            let client = await SupabaseManager.shared.client
            _ = try await client.storage
                .from(bucket)
                .upload(
                    fileName,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
        } catch {
            throw ScanError.uploadFailed(error.localizedDescription)
        }

        // Public URL — must await client access and try getPublicURL
        let client = await SupabaseManager.shared.client
        let publicURL = try client.storage
            .from(bucket)
            .getPublicURL(path: fileName)

        return publicURL.absoluteString
    }

    // MARK: - Parse

    private func parseResponse(_ data: Data, fallbackImageUrl: String) throws -> ScannedReceipt {
        // n8n "Respond to Webhook" tüm itemleri array olarak döner
        let json: [String: Any]
        if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let first = array.first {
            if let output = first["output"] as? [String: Any] {
                json = output
            } else {
                json = first
            }
        } else if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let output = obj["output"] as? [String: Any] {
                json = output
            } else {
                json = obj
            }
        } else {
            throw ScanError.invalidResponse
        }

        // amount Int veya Double gelebilir
        let amount: Double
        if let d = json["amount"] as? Double {
            amount = d
        } else if let i = json["amount"] as? Int {
            amount = Double(i)
        } else {
            amount = 0
        }

        let merchant   = json["store_name"] as? String ?? ""
        let category   = json["category"]   as? String ?? ""
        let type       = json["type"]       as? String ?? "expense"
        let taxNumber  = json["tax_number"] as? String ?? ""
        let imageUrl   = json["image_url"]  as? String ?? fallbackImageUrl
        let salesItems = json["sales_data"] as? [[String: Any]] ?? []

        var date = Date()
        if let dateStr = json["receipt_date"] as? String, !dateStr.isEmpty {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            date = fmt.date(from: dateStr) ?? Date()
        }

        return ScannedReceipt(
            amount: amount,
            currency: "TRY",
            merchant: merchant,
            category: category,
            date: date,
            note: merchant,
            type: type,
            taxNumber: taxNumber,
            salesItems: salesItems,
            imageUrl: imageUrl
        )
    }
}

// MARK: - UIImage Resize Helper (free function — no actor isolation)

/// Resizes a UIImage so its longest side doesn't exceed `maxDim`.
/// Free function avoids @MainActor isolation that would come from a UIImage extension.
nonisolated private func zf_resizeImage(_ image: UIImage, toMaxDimension maxDim: CGFloat) -> UIImage {
    let ratio = min(maxDim / image.size.width, maxDim / image.size.height, 1.0)
    guard ratio < 1.0 else { return image }
    let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
}
