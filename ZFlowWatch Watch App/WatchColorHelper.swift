import SwiftUI

func wColor(_ hex: String) -> Color {
    let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    return Color(
        red:   Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >>  8) & 0xFF) / 255,
        blue:  Double( rgb        & 0xFF) / 255
    )
}

// MARK: - Watch Semantic Palette
// Named tokens mirror ZColor from the main app.
// Use these instead of inline wColor("#hex") calls for consistency.

/// Soft Emerald — income (matches ZColor.income)
let wIncome  = wColor("#50C878")
/// Soft Coral — expense (matches ZColor.expense)
let wExpense = wColor("#FF7F7F")
/// Brand Indigo — accent (matches AppTheme.baseColor)
var wAccent: Color { WatchStore.shared.accentPrimary }
/// Brand Accent Secondary
var wAccentSec: Color { WatchStore.shared.accentSecondary }
/// Orange — warning / upcoming payments (matches ZColor.warning)
let wWarning = wColor("#FF9F0A")
