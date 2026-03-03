import SwiftUI

public struct EliteTextFieldStyle: TextFieldStyle {
    public init() {}
    
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ThemeColors.glassBackground)
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ThemeColors.glassBorder, lineWidth: 1)
            )
            .foregroundColor(ThemeColors.textPrimary)
            .font(.system(size: 16, weight: .medium, design: .default))
            // Inner shadow illusion
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}
