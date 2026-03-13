import Foundation
import SwiftUI
import Combine
import Supabase
import PostgREST

@MainActor
final class BulkImportViewModel: ObservableObject {
    enum ImportState {
        case idle
        case analyzing
        case verifying
        case saving
        case completed(count: Int)
        case error(String)
    }

    @Published var state: ImportState = .idle
    @Published var transactions: [StatementTransaction] = []
    @Published var categories: [Category] = []
    
    private let supabase = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()

    init(categories: [Category]) {
        self.categories = categories
    }

    func processFile(url: URL, userId: String) {
        state = .analyzing
        
        Task {
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    state = .error("File access denied")
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let fileData = try Data(contentsOf: url)
                let fileName = url.lastPathComponent
                let fileExtension = url.pathExtension.lowercased()
                let mimeType = fileExtension == "pdf" ? "application/pdf" : "text/csv"
                
                // Prepare Request - MUST BE MULTIPART FOR FASTAPI File()
                var request = URLRequest(url: URL(string: ZFlowAPIConfig.analyzeStatementEndpoint)!)
                request.httpMethod = "POST"
                
                let boundary = "Boundary-\(UUID().uuidString)"
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue(ZFlowAPIConfig.apiKey, forHTTPHeaderField: "x-api-key")
                
                var body = Data()
                
                // user_id field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"user_id\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(userId)\r\n".data(using: .utf8)!)
                
                // type field (CRITICAL: Tells server to use PDF/Statement logic)
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
                body.append("statement\r\n".data(using: .utf8)!)
                
                // file field
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                body.append(fileData)
                body.append("\r\n".data(using: .utf8)!)
                
                body.append("--\(boundary)--\r\n".data(using: .utf8)!)
                request.httpBody = body

                // Create a custom session with a longer timeout for AI processing
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 120 // 2 minutes
                config.timeoutIntervalForResource = 120
                let session = URLSession(configuration: config)

                let (data, response) = try await session.data(for: request)
                
                let rawResponse = String(data: data, encoding: .utf8) ?? "Empty response"
                print("🔴 SUNUCUDAN GELEN GERÇEK CEVAP: \(rawResponse)")

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    state = .error("Sunucu Hatası (\((response as? HTTPURLResponse)?.statusCode ?? 0)): \(rawResponse)")
                    return
                }

                let decoder = JSONDecoder()
                do {
                    let result = try decoder.decode(StatementResponse.self, from: data)
                    if result.status == "success", let foundTxns = result.transactions {
                        self.transactions = foundTxns
                        self.state = .verifying
                    } else {
                        // If server returns success but transactions is nil, or status is error
                        let errMsg = result.message ?? "İşlem bulunamadı. Lütfen dosyanın içeriğini kontrol edin."
                        self.state = .error(errMsg)
                    }
                } catch {
                    print("❌ [BulkImport] DECODE ERROR: \(error)")
                    state = .error("Veri Çözümleme Hatası: \(rawResponse)")
                }
                
            } catch {
                print("❌ [BulkImport] NETWORK ERROR: \(error)")
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                    state = .error("İşlem Zaman Aşımı: PDF boyutu büyük olduğu için analiz biraz uzun sürüyor. Lütfen tekrar deneyin.")
                } else {
                    state = .error("Bağlantı Hatası: \(error.localizedDescription)")
                }
            }
        }
    }

    func saveAll(userId: UUID) async {
        guard !transactions.isEmpty else { return }
        
        state = .saving
        
        do {
            // Map to TransactionInsert for bulk saving
            let inserts = transactions.map { txn in
                TransactionInsert(
                    userId: userId,
                    amount: txn.amount,
                    currency: "TRY", // Default to TRY for statement imports
                    type: txn.type,
                    categoryId: UUID(uuidString: txn.category_id ?? ""),
                    note: NSLocalizedString("bulk.automaticNote", comment: "Banka Ekstresinden Aktarıldı"),
                    date: parseDate(txn.date)
                )
            }
            
            // Supabase Bulk Insert
            try await supabase.from("transactions")
                .insert(inserts)
                .execute()
            
            state = .completed(count: inserts.count)
            Haptic.success()
            
            // Refresh main view model data via ecosystem update notification if needed
            // Or just rely on Realtime which is enabled in TransactionViewModel
        } catch {
            print("❌ [BulkImport] SAVE ERROR: \(error)")
            state = .error(error.localizedDescription)
        }
    }

    private func parseDate(_ dateStr: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter.date(from: dateStr) ?? Date()
    }

    private func generateMockTransactions() -> [StatementTransaction] {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        
        func dateOffset(_ days: Int) -> String {
            let d = Calendar.current.date(byAdding: .day, value: -days, to: now)!
            return formatter.string(from: d)
        }

        let foodCat = categories.first(where: { $0.name.lowercased().contains("food") || $0.name.lowercased().contains("yemek") })
        let transportCat = categories.first(where: { $0.name.lowercased().contains("transport") || $0.name.lowercased().contains("ulaşım") })
        let shopCat = categories.first(where: { $0.name.lowercased().contains("shop") || $0.name.lowercased().contains("alışveriş") })
        let salaryCat = categories.first(where: { $0.name.lowercased().contains("salary") || $0.name.lowercased().contains("maaş") })

        return [
            StatementTransaction(
                store_name: "Starbucks TR",
                amount: 145.00,
                type: "expense",
                category_id: foodCat?.id.uuidString,
                date: dateOffset(1)
            ),
            StatementTransaction(
                store_name: "Migros Jet",
                amount: 850.40,
                type: "expense",
                category_id: shopCat?.id.uuidString,
                date: dateOffset(2)
            ),
            StatementTransaction(
                store_name: "Bitaksi",
                amount: 120.00,
                type: "expense",
                category_id: transportCat?.id.uuidString,
                date: dateOffset(3)
            ),
            StatementTransaction(
                store_name: "Havale: Kira Geliri",
                amount: 15000.00,
                type: "income",
                category_id: salaryCat?.id.uuidString,
                date: dateOffset(5)
            ),
            StatementTransaction(
                store_name: "Netflix.com",
                amount: 229.99,
                type: "expense",
                category_id: nil,
                date: dateOffset(7)
            )
        ]
    }
}
