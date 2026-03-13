// ============================================================
// ZFlow Watch — Currency Converter
// Standalone converter for watchOS (same rates as main app)
// ============================================================
import Foundation

struct WatchCurrencyConverter {

    // Static fallback rates (USD base) — mirrors CurrencyConverter.swift
    private static let ratesToUSD: [String: Double] = [
        "USD": 1.0, "TRY": 36.5, "EUR": 0.92, "GBP": 0.79,
        "CHF": 0.88, "JPY": 152.0, "AED": 3.67, "SAR": 3.75,
        "RUB": 92.0, "CNY": 7.25,
    ]

    static let supportedCurrencies: [(code: String, symbol: String, flag: String, name: String)] = [
        ("TRY", "\u{20BA}", "\u{1F1F9}\u{1F1F7}", "Turkish Lira"),
        ("USD", "$",  "\u{1F1FA}\u{1F1F8}", "US Dollar"),
        ("EUR", "\u{20AC}",  "\u{1F1EA}\u{1F1FA}", "Euro"),
        ("GBP", "\u{00A3}",  "\u{1F1EC}\u{1F1E7}", "British Pound"),
        ("CHF", "Fr", "\u{1F1E8}\u{1F1ED}", "Swiss Franc"),
        ("JPY", "\u{00A5}",  "\u{1F1EF}\u{1F1F5}", "Japanese Yen"),
        ("AED", "AED", "\u{1F1E6}\u{1F1EA}", "UAE Dirham"),
        ("SAR", "SAR", "\u{1F1F8}\u{1F1E6}", "Saudi Riyal"),
        ("RUB", "\u{20BD}",  "\u{1F1F7}\u{1F1FA}", "Russian Ruble"),
        ("CNY", "\u{00A5}",  "\u{1F1E8}\u{1F1F3}", "Chinese Yuan"),
    ]

    static func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        let fromRate = ratesToUSD[from] ?? 1.0
        let toRate   = ratesToUSD[to]   ?? 1.0
        return (amount / fromRate) * toRate
    }

    static func symbol(for code: String) -> String {
        supportedCurrencies.first { $0.code == code }?.symbol ?? code
    }

    static func flag(for code: String) -> String {
        supportedCurrencies.first { $0.code == code }?.flag ?? "\u{1F4B1}"
    }

    static func rate(from: String, to: String) -> Double {
        guard from != to else { return 1.0 }
        let fromRate = ratesToUSD[from] ?? 1.0
        let toRate   = ratesToUSD[to]   ?? 1.0
        return toRate / fromRate
    }
}
