import SwiftUI

public struct EliteTypography: ViewModifier {
    var size: CGFloat
    var weight: Font.Weight
    
    public func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .default))
    }
}

public extension View {
    func eliteFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(EliteTypography(size: size, weight: weight))
    }
}

// Convenient pre-defined styles
public extension View {
    func eliteTitle() -> some View {
        self.eliteFont(size: 34, weight: .bold)
    }
    
    func eliteHeadline() -> some View {
        self.eliteFont(size: 24, weight: .semibold)
    }
    
    func eliteBody() -> some View {
        self.eliteFont(size: 16, weight: .regular)
    }
    
    func eliteCaption() -> some View {
        self.eliteFont(size: 12, weight: .medium)
            .foregroundStyle(ThemeColors.textSecondary)
    }
}
