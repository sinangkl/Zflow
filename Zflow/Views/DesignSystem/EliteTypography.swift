import SwiftUI

public struct EliteTypography: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    var weight: Font.Weight
    var design: Font.Design
    
    init(size: CGFloat, weight: Font.Weight, textStyle: Font.TextStyle, design: Font.Design) {
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }
    
    public func body(content: Content) -> some View {
        content
            // Using ScaledMetric ensures the font scales with Dynamic Type accessibility settings
            .font(.system(size: scaledSize, weight: weight, design: design))
    }
}

public extension View {
    func eliteFont(size: CGFloat, weight: Font.Weight = .regular, textStyle: Font.TextStyle = .body, design: Font.Design = .default) -> some View {
        self.modifier(EliteTypography(size: size, weight: weight, textStyle: textStyle, design: design))
    }
}

// Convenient pre-defined styles
public extension View {
    /// 42pt thin rounded — amount entry fields (AddTransaction hero)
    func eliteHeroBalance() -> some View {
        self.eliteFont(size: 42, weight: .thin, textStyle: .largeTitle, design: .rounded)
    }

    /// 38pt bold rounded — dashboard net balance hero card
    func eliteDashboardBalance() -> some View {
        self.eliteFont(size: 38, weight: .bold, textStyle: .largeTitle, design: .rounded)
    }

    /// 34pt bold — section/screen titles (use sparingly)
    func eliteTitle() -> some View {
        self.eliteFont(size: 34, weight: .bold, textStyle: .title)
    }

    /// 26pt bold rounded — greeting header, large card labels
    func eliteSubheading() -> some View {
        self.eliteFont(size: 26, weight: .bold, textStyle: .title2, design: .rounded)
    }

    /// 24pt semibold — section headers, card titles
    func eliteHeadline() -> some View {
        self.eliteFont(size: 24, weight: .semibold, textStyle: .headline)
    }

    /// 16pt regular — general body text
    func eliteBody() -> some View {
        self.eliteFont(size: 16, weight: .regular, textStyle: .body)
    }

    /// 13pt regular — longer secondary text, insight messages
    func eliteCallout() -> some View {
        self.eliteFont(size: 13, weight: .regular, textStyle: .callout)
    }

    /// 12pt medium + secondary foreground — labels, captions
    func eliteCaption() -> some View {
        self.eliteFont(size: 12, weight: .medium, textStyle: .caption)
            .foregroundStyle(ThemeColors.textSecondary)
    }

    /// 11pt bold — uppercase chip labels, micro labels
    func eliteMicroLabel() -> some View {
        self.eliteFont(size: 11, weight: .bold, textStyle: .caption2)
    }
}
