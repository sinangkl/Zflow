import Foundation

struct CurrencyConverter {

    // Static fallback rates (USD base). In production, fetch from an API.
    private static var ratesToUSD: [String: Double] = [
        "USD": 1.0, "TRY": 36.5, "EUR": 0.92, "GBP": 0.79,
        "CHF": 0.88, "JPY": 152.0, "AED": 3.67, "SAR": 3.75,
        "RUB": 92.0, "CNY": 7.25,
    ]

    static func convert(amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        let fromRate = ratesToUSD[from] ?? 1.0
        let toRate   = ratesToUSD[to]   ?? 1.0
        return (amount / fromRate) * toRate
    }

    static func symbol(for code: String) -> String {
        Currency(rawValue: code)?.symbol ?? code
    }

    static func flag(for code: String) -> String {
        Currency(rawValue: code)?.flag ?? "💱"
    }

    /// Update rates at runtime (e.g. from a live exchange-rate API)
    static func updateRates(_ newRates: [String: Double]) {
        for (k, v) in newRates { ratesToUSD[k] = v }
    }
}
