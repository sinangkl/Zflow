import Foundation
import Combine

// MARK: - Transaction Enums

enum TransactionType: String, Codable, CaseIterable {
    case income, expense
    var displayName: String { rawValue.capitalized }
}

enum Currency: String, Codable, CaseIterable, Identifiable {
    case try_ = "TRY", USD, EUR, GBP, CHF, JPY, AED, SAR, RUB, CNY
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .try_: "₺"; case .USD: "$"; case .EUR: "€"; case .GBP: "£"
        case .CHF: "Fr"; case .JPY: "¥"; case .AED: "د.إ"; case .SAR: "﷼"
        case .RUB: "₽"; case .CNY: "¥"
        }
    }
    var name: String {
        switch self {
        case .try_: "Turkish Lira"; case .USD: "US Dollar"; case .EUR: "Euro"
        case .GBP: "British Pound"; case .CHF: "Swiss Franc"; case .JPY: "Japanese Yen"
        case .AED: "UAE Dirham"; case .SAR: "Saudi Riyal"; case .RUB: "Russian Ruble"
        case .CNY: "Chinese Yuan"
        }
    }
    var flag: String {
        switch self {
        case .try_: "🇹🇷"; case .USD: "🇺🇸"; case .EUR: "🇪🇺"; case .GBP: "🇬🇧"
        case .CHF: "🇨🇭"; case .JPY: "🇯🇵"; case .AED: "🇦🇪"; case .SAR: "🇸🇦"
        case .RUB: "🇷🇺"; case .CNY: "🇨🇳"
        }
    }
}

// MARK: - Transaction Models

struct Transaction: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID?
    var amount: Double
    var currency: String
    var type: String?
    var categoryId: UUID?
    var note: String?
    var date: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount, currency, type, note, date
        case userId = "user_id"
        case categoryId = "category_id"
        case createdAt = "created_at"
    }
}

struct TransactionInsert: Codable {
    let userId: UUID
    let amount: Double
    let currency: String
    let type: String
    let categoryId: UUID?
    let note: String?
    let date: Date

    enum CodingKeys: String, CodingKey {
        case amount, currency, type, note, date
        case userId = "user_id"
        case categoryId = "category_id"
    }
}

// MARK: - Category Models

struct Category: Codable, Identifiable, Hashable, Equatable {
    let id: UUID
    let userId: UUID?
    let name: String
    let color: String
    let icon: String?
    let type: String?      // "income" | "expense" | "both"
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon, type
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct CategoryInsert: Codable {
    let userId: UUID
    let name: String
    let color: String
    let icon: String?
    let type: String?
    enum CodingKeys: String, CodingKey {
        case name, color, icon, type; case userId = "user_id"
    }
}

// MARK: - Profile Models

enum UserType: String, Codable, CaseIterable {
    case personal, business
    var displayName: String { rawValue.capitalized }
    var icon: String { self == .personal ? "person.fill" : "building.2.fill" }
}

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var fullName: String?
    var userType: String?
    var businessName: String?
    var avatarURL: String? // EKLEDİĞİMİZ KISIM
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case userType = "user_type"
        case businessName = "business_name"
        case avatarURL = "avatar_url" // EKLEDİĞİMİZ KISIM
        case createdAt = "created_at"
    }

    var isBusiness: Bool { userType == UserType.business.rawValue }
    var displayName: String { businessName ?? fullName ?? "User" }
    var initials: String {
        let n = fullName ?? businessName ?? "U"
        let parts = n.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(n.prefix(2)).uppercased()
    }
}

struct ProfileInsert: Codable {
    let id: UUID
    let fullName: String
    let userType: String
    let businessName: String?
    var avatarURL: String? // EKLEDİĞİMİZ KISIM

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case userType = "user_type"
        case businessName = "business_name"
        case avatarURL = "avatar_url" // EKLEDİĞİMİZ KISIM
    }
}

// MARK: - Budget Model

struct Budget: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID?
    let categoryId: UUID?
    var limitAmount: Double
    var budgetType: String?
    var currency: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, currency
        case userId = "user_id"
        case categoryId = "category_id"
        case limitAmount = "limit_amount"
        case budgetType = "budget_type"
        case createdAt = "created_at"
    }
}

// MARK: - Recurring Transaction

enum RecurringInterval: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly
    var displayName: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .daily: "sun.max"; case .weekly: "calendar.badge.clock"
        case .monthly: "calendar"; case .yearly: "star.circle"
        }
    }
}

// MARK: - Calendar Event (Apple Calendar sync)

struct CalendarEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let transactionId: UUID?
    let title: String
    let amount: Double
    let currency: String
    let eventType: String   // "income" | "expense" | "reminder"
    let eventDate: Date
    let appleEventId: String?   // EKEvent identifier
    let note: String?
    let isRecurring: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, note
        case userId       = "user_id"
        case transactionId = "transaction_id"
        case eventType    = "event_type"
        case eventDate    = "event_date"
        case appleEventId = "apple_event_id"
        case isRecurring  = "is_recurring"
        case createdAt    = "created_at"
    }
}

struct CalendarEventInsert: Codable {
    let userId: UUID
    let transactionId: UUID?
    let title: String
    let amount: Double
    let currency: String
    let eventType: String
    let eventDate: Date
    let appleEventId: String?
    let note: String?
    let isRecurring: Bool

    enum CodingKeys: String, CodingKey {
        case title, amount, currency, note
        case userId       = "user_id"
        case transactionId = "transaction_id"
        case eventType    = "event_type"
        case eventDate    = "event_date"
        case appleEventId = "apple_event_id"
        case isRecurring  = "is_recurring"
    }
}

// MARK: - VAT / Tax Model (İşletme kullanıcıları için)

struct VATCalculation: Identifiable {
    let id = UUID()
    var baseAmount: Double      // KDV hariç
    var vatRate: Double         // 0.18 = %18
    var vatAmount: Double { baseAmount * vatRate }
    var totalAmount: Double { baseAmount + vatAmount }
}

enum TurkishVATRate: Double, CaseIterable {
    case zero     = 0.00   // %0
    case low      = 0.01   // %1
    case reduced  = 0.10   // %10
    case standard = 0.20   // %20 (2024 sonrası yeni oran)
    case special  = 0.18   // %18 (eski oran)

    var displayName: String {
        switch self {
        case .zero:     return "%0"
        case .low:      return "%1"
        case .reduced:  return "%10"
        case .standard: return "%20"
        case .special:  return "%18"
        }
    }
}

// MARK: - Profile Photo
// Supabase Storage'da saklanır

extension Profile {
    var avatarStoragePath: String { "avatars/\(id.uuidString).jpg" }
}
// MARK: - Scheduled Payment Models

enum ScheduledPaymentStatus: String, Codable {
    case pending     // Henüz tarih gelmedi, bekliyor
    case ready       // Tarih geldi, onay bekliyor
    case completed   // Kullanıcı onayladı, transaction oluşturuldu
    case cancelled   // İptal edildi
}
struct ScheduledPayment: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID?
    var title: String
    var amount: Double
    var currency: String
    var type: String?           // "income" | "expense"
    var categoryId: UUID?
    var note: String?
    var scheduledDate: Date     // Ödeme planı tarihi
    var status: String          // pending, ready, completed, cancelled
    var calendarEventId: String? // Apple Calendar event ID (opsiyonel)
    let createdAt: Date?
    var completedAt: Date?      // Onaylandığı tarih
    var transactionId: UUID?    // Oluşturulan transaction ID

    enum CodingKeys: String, CodingKey {
        case id, title, amount, currency, type, note, status
        case userId = "user_id"
        case categoryId = "category_id"
        case scheduledDate = "scheduled_date"
        case calendarEventId = "calendar_event_id"
        case createdAt = "created_at"
        case completedAt = "completed_at"
        case transactionId = "transaction_id"
    }
}

struct ScheduledPaymentInsert: Codable {
    let userId: UUID
    let title: String
    let amount: Double
    let currency: String
    let type: String
    let categoryId: UUID?
    let note: String?
    let scheduledDate: Date
    let status: String
    let calendarEventId: String?

    enum CodingKeys: String, CodingKey {
        case title, amount, currency, type, note, status
        case userId = "user_id"
        case categoryId = "category_id"
        case scheduledDate = "scheduled_date"
        case calendarEventId = "calendar_event_id"
    }
}


