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
