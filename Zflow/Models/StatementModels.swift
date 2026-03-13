import Foundation

// API'den dönen ana yanıt
struct StatementResponse: Codable {
    let status: String
    let transactions: [StatementTransaction]?
    let message: String?
}

// Bulunan her bir işlemin modeli
struct StatementTransaction: Codable, Identifiable {
    var id = UUID() // SwiftUI Listesinde göstermek için gerekli
    var store_name: String
    var amount: Double
    var type: String // "expense" veya "income"
    var category_id: String?
    var date: String

    // JSON'dan gelirken id'yi bekleme, biz UUID() ile atadık
    enum CodingKeys: String, CodingKey {
        case store_name, amount, type, category_id, date
    }
}
