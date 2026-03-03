import SwiftUI

// MARK: - PremiumBackground
// Dark: Deep midnight gradient — Glass efekti için kontrast zemin
// Light: Apple system grouped — temiz ve tutarlı

struct PremiumBackground: View {
    var body: some View {
        MeshGradientBackground()
    }
}

// MARK: - GlassCard

struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    var cornerRadius: CGFloat = 24
    let content: Content
    init(cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius; self.content = content()
    }
    var body: some View {
        content
            .liquidGlass(cornerRadius: cornerRadius)
    }
}

// MARK: - GradientCard

struct GradientCard<Content: View>: View {
    var gradient: LinearGradient = AppTheme.accentGradient
    var cornerRadius: CGFloat = 24
    let content: Content
    init(gradient: LinearGradient = AppTheme.accentGradient, cornerRadius: CGFloat = 24,
         @ViewBuilder content: () -> Content) {
        self.gradient = gradient; self.cornerRadius = cornerRadius; self.content = content()
    }
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - TransactionRow

struct TransactionRow: View {
    let transaction: Transaction
    let category: Category?
    var isStandalone: Bool = false
    @Environment(\.colorScheme) var scheme
    private var isIncome: Bool { transaction.type == "income" }
    private var catColor: Color { Color(hex: category?.color ?? "#8E8E93") }

    var body: some View {
        let rowContent = HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(catColor.opacity(0.12))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category?.name ?? "Uncategorized") - \(isIncome ? "Income" : "Expense") \(transaction.amount.formattedCurrency(code: transaction.currency))")
        
        Group {
            if isStandalone {
                rowContent
                    .liquidGlass(cornerRadius: 16)
            } else {
                rowContent
                    .background(Color.clear)
            }
        }
    }
}

// MARK: - Liquid Scroll Transform

struct ScrollTransformModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.visualEffect { view, proxy in
                let frame = proxy.frame(in: .global)
                let estimatedScreenHeight: CGFloat = 850.0
                let position = frame.midY
                let distanceFromCenter = abs(estimatedScreenHeight / 2 - position)
                let scale = max(0.9, 1 - (distanceFromCenter / (estimatedScreenHeight * 1.5)))
                
                return view.scaleEffect(scale)
            }
        } else {
            content
        }
    }
}

extension View {
    func liquidScrollTransform() -> some View {
        modifier(ScrollTransformModifier())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(iconColor)
                }
                Spacer()
                if let t = trend {
                    HStack(spacing: 3) {
                        Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.left")
                        Text("\(String(format: "%.1f", abs(t)))%")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(t >= 0 ? ZColor.expense : ZColor.income)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((t >= 0 ? ZColor.expense : ZColor.income).opacity(0.1)))
                }
            }
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(valueColor)
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.system(size: 12, weight: .medium)).foregroundColor(ZColor.labelSec)
        }
        .padding(16).liquidGlass(cornerRadius: 24)
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

// MARK: - AccessibleButton

struct AccessibleButton<Content: View>: View {
    let action: () -> Void
    let label: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        Button(action: action, label: content)
            .accessibilityLabel(label)
    }
}

// MARK: - ErrorBanner

struct ErrorBanner: View {
    let message: String
    let icon: String = "exclamationmark.circle.fill"
    var dismissAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.red.opacity(0.8)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Error").font(.system(size: 13, weight: .semibold)).foregroundColor(.white)
                Text(message).font(.system(size: 12)).foregroundColor(.white.opacity(0.9))
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
            
            if let action = dismissAction {
                Button { action(); Haptic.light() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white).frame(width: 24, height: 24)
                }.accessibilityLabel("Dismiss error")
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.red.opacity(0.15))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)))
    }
}

// MARK: - Icon Grid Picker

struct IconGridPicker: View {
    @Binding var selectedIcon: String
    var columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)
    
    let categoryIcons = [
        ("Income", ["banknote.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "percent", "arrow.triangle.2.circlepath"]),
        ("Food & Dining", ["fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill"]),
        ("Shopping", ["bag.fill", "cart.fill", "shippingbox.fill", "tag.fill"]),
        ("Transport", ["car.fill", "airplane", "bicycle", "tram.fill"]),
        ("Home & Living", ["house.fill", "bolt.fill", "leaf.fill", "water.circle.fill"]),
        ("Health & Fitness", ["heart.fill", "cross.case.fill", "figure.run", "dumbbell.fill"]),
        ("Entertainment", ["gamecontroller.fill", "tv.fill", "music.note", "film.fill"]),
        ("Work & Education", ["briefcase.fill", "book.fill", "graduationcap.fill", "laptopcomputer"]),
        ("Other", ["ellipsis.circle.fill", "giftbox.fill", "pawprint.fill"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(categoryIcons, id: \.0) { category, icons in
                VStack(alignment: .leading, spacing: 8) {
                    Text(category).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                    
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            let isSelected = selectedIcon == icon
                            Button {
                                selectedIcon = icon
                                Haptic.selection()
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(height: 44)
                                    .frame(maxWidth: .infinity)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isSelected ? ZColor.indigo.opacity(0.15) : Color(.tertiarySystemFill)))
                                    .foregroundColor(isSelected ? ZColor.indigo : ZColor.label)
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(isSelected ? ZColor.indigo.opacity(0.5) : .clear, lineWidth: 1.5))
                            }.accessibilityLabel("Select \(icon) icon")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Layout Padding Constants

enum LayoutPadding {
    static let screen: CGFloat = 16
    static let section: CGFloat = 20
    static let component: CGFloat = 14
    static let compact: CGFloat = 8
}
// MARK: - ReadyPaymentCard

/// Scheduled payment awaiting user approval
/// Shows payment details and Approve/Reject buttons
struct ReadyPaymentCard: View {
    @Environment(\.colorScheme) var scheme
    let payment: ScheduledPayment
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Payment Awaiting Approval")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(UIColor.systemOrange))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text(payment.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ZColor.label)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(payment.type == "income" ? "+" : "-")\(String(format: "%.0f", payment.amount))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(ZColor.label)
                    
                    Text(payment.currency)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ZColor.labelSec)
                }
            }

            // Approve/Reject Buttons
            HStack(spacing: 10) {
                Button(action: onReject) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                        Text(NSLocalizedString("common.reject", comment: ""))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(ZColor.expense.opacity(0.85))
                    .clipShape(Capsule())
                }

                Button(action: onApprove) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(NSLocalizedString("common.approve", comment: ""))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(.white)
                    .background(ZColor.income.opacity(0.85))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.orange.opacity(scheme == .dark ? 0.12 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}