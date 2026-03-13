import Foundation
import UIKit

class ZFlowNetworkManager {
    static let shared = ZFlowNetworkManager()
    
    // Artık n8n webhook'u değil, KENDİ API'ni kullanıyorsun!
    private let baseURL = "https://zflow.online/api"
    
    private init() {}
    
    // MARK: - 1. Chatbot Mesajı Gönderme
    struct ChatResponse {
        let reply: String
        let action: String?   // "transaction_added", "budget_set", nil
    }

    func sendChatMessage(message: String, userId: String, userName: String? = nil, history: [[String: String]] = [], completion: @escaping (Result<ChatResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/chat") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Fetch current financial context for Phase 5 AI Predictions
        let snap = SnapshotStore.shared.load()
        let budgetContext = snap.budgetStatuses.map { "\($0.categoryName): \($0.spent)/\($0.limit) \($0.currency)" }.joined(separator: ", ")
        let trendContext = snap.weeklyExpenses.map { String($0) }.joined(separator: ", ")

        let categoriesContext = snap.categories.map { "\($0.name)" }.joined(separator: ", ")

        let payload: [String: Any] = [
            "message": message,
            "user_id": userId,
            "user_name": userName ?? "User",
            "history": history,
            "context": [
                "budgets": budgetContext,
                "weekly_trend": trendContext,
                "net_balance": snap.netBalance,
                "currency": snap.currency,
                "available_categories": categoriesContext
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "DataError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Veri alınamadı."])))
                return
            }
            
            // FastAPI'den dönen {"reply": "...", "action": "..."} JSON'ını çözüyoruz
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let reply = json["reply"] as? String {
                    let action = json["action"] as? String
                    DispatchQueue.main.async {
                        completion(.success(ChatResponse(reply: reply, action: action)))
                    }
                } else {
                    let rawString = String(data: data, encoding: .utf8) ?? "Bilinmeyen format"
                    completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Yanıt çözülemedi: \(rawString)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
