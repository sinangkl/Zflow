import SwiftUI

// MARK: - PremiumBackground
// Dark: Deep midnight gradient — Glass efekti için kontrast zemin
// Light: Apple system grouped — temiz ve tutarlı

struct PremiumBackground: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        Group {
            if scheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#000008"), location: 0),
                        .init(color: Color(hex: "#070714"), location: 0.55),
                        .init(color: Color(hex: "#04040E"), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color(.systemGroupedBackground)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - GlassCard

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    var cornerRadius: CGFloat = 16
    let content: Content
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius; self.content = content()
    }
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.glassMaterial(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
            )
            .shadow(color: scheme == .dark ? .clear : .black.opacity(0.04), radius: 10, x: 0, y: 2)
    }
}

// MARK: - GradientCard

struct GradientCard<Content: View>: View {
    var gradient: LinearGradient = AppTheme.accentGradient
    var cornerRadius: CGFloat = 20
    let content: Content
    init(gradient: LinearGradient = AppTheme.accentGradient, cornerRadius: CGFloat = 20,
         @ViewBuilder content: () -> Content) {
        self.gradient = gradient; self.cornerRadius = cornerRadius; self.content = content()
    }
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(gradient))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: ZColor.indigo.opacity(0.28), radius: 16, x: 0, y: 8)
    }
}

// MARK: - TransactionRow

struct TransactionRow: View {
    let transaction: Transaction
    let category: Category?
    @Environment(\.colorScheme) var scheme
    private var isIncome: Bool { transaction.type == "income" }
    private var catColor: Color { Color(hex: category?.color ?? "#8E8E93") }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(catColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: category?.icon ?? "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(catColor)
            }
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(category?.name ?? "Uncategorized")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(ZColor.label)
                if let note = transaction.note, !note.isEmpty {
                    Text(note).font(.system(size: 13)).foregroundColor(ZColor.labelSec).lineLimit(1)
                } else if let date = transaction.date {
                    Text(date.formatted(.dateTime.weekday(.short).month(.abbreviated).day()))
                        .font(.system(size: 13)).foregroundColor(ZColor.labelSec)
                }
            }
            Spacer()
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(isIncome ? "+" : "−")\(transaction.amount.formattedCurrency(code: transaction.currency))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isIncome ? ZColor.income : ZColor.expense)
                if let date = transaction.date {
                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 12)).foregroundColor(ZColor.labelTert)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - InsightCard

struct InsightCard: View {
    let insight: FinancialInsight
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(insight.type.bgColor).frame(width: 44, height: 44)
                Image(systemName: insight.icon).font(.system(size: 17, weight: .semibold))
                    .foregroundColor(insight.type.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.system(size: 14, weight: .semibold)).foregroundColor(ZColor.label)
                Text(insight.message).font(.system(size: 13)).foregroundColor(ZColor.labelSec)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                if let label = insight.actionLabel {
                    Button(label) { onAction?() }
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(insight.type.color).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(insight.type.bgColor.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(insight.type.color.opacity(0.2), lineWidth: 0.5))
    }
}

// MARK: - ShimmerView

struct ShimmerView: View {
    @Environment(\.colorScheme) var scheme
    @State private var phase: CGFloat = -200
    var height: CGFloat = 20; var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.tertiarySystemFill)).frame(height: height)
            .overlay(
                LinearGradient(colors: [.clear, .white.opacity(scheme == .dark ? 0.06 : 0.5), .clear],
                               startPoint: .leading, endPoint: .trailing)
                .frame(width: 160).offset(x: phase).clipped()
            ).clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 360 }
            }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()
            ProgressView().progressViewStyle(.circular).tint(.white).scaleEffect(1.4)
                .padding(22)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial))
        }
    }
}

// MARK: - EmptyStateView

struct EmptyStateView: View {
    var icon: String; var title: String; var message: String
    var actionLabel: String? = nil; var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 46, weight: .medium))
                .foregroundColor(ZColor.labelTert).padding(.bottom, 4)
            Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(ZColor.label)
            Text(message).font(.system(size: 14)).foregroundColor(ZColor.labelSec)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if let label = actionLabel {
                Button { action?() } label: {
                    Text(label).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 28).padding(.vertical, 13)
                        .background(Capsule(style: .continuous).fill(AppTheme.accentGradient))
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 36).frame(maxWidth: .infinity)
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    var title: String; var trailing: String? = nil; var trailingAction: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundColor(ZColor.label)
            Spacer()
            if let label = trailing {
                Button(label) { trailingAction?() }
                    .font(.system(size: 14, weight: .medium)).foregroundColor(ZColor.indigo)
            }
        }
    }
}

// MARK: - BudgetProgressBar

struct BudgetProgressBar: View {
    var spent: Double; var limit: Double
    var color: Color = ZColor.indigo; var height: CGFloat = 6
    private var ratio: Double { limit > 0 ? min(spent/limit, 1.0) : 0 }
    private var barColor: Color {
        if ratio >= 1.0 { return ZColor.expense }
        if ratio >= 0.8 { return ZColor.warning }
        return ZColor.income
    }
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height/2, style: .continuous)
                    .fill(Color(.tertiarySystemFill)).frame(height: height)
                RoundedRectangle(cornerRadius: height/2, style: .continuous)
                    .fill(barColor)
                    .frame(width: max(0, geo.size.width * ratio), height: height)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: ratio)
            }
        }
        .frame(height: height)
    }
}

// MARK: - StatCard

struct StatCard: View {
    var title: String; var value: String; var icon: String
    var iconColor: Color = ZColor.indigo; var valueColor: Color = ZColor.label
    var trend: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.12)).frame(width: 30, height: 30)
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundColor(iconColor)
                }
                Spacer()
                if let t = trend {
                    HStack(spacing: 2) {
                        Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.left")
                        Text("\(String(format: "%.1f", abs(t)))%")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(t >= 0 ? ZColor.expense : ZColor.income)
                }
            }
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(valueColor)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(ZColor.labelSec)
        }
        .padding(14).zFlowCard()
    }
}

// MARK: - PillTag

struct PillTag: View {
    var label: String; var color: Color; var isSelected: Bool = false; var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule(style: .continuous).fill(isSelected ? color.opacity(0.15) : Color(.tertiarySystemFill)))
                .overlay(Capsule(style: .continuous).strokeBorder(isSelected ? color.opacity(0.5) : .clear, lineWidth: 1))
                .foregroundColor(isSelected ? color : ZColor.labelSec)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - FABButtonStyle

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
