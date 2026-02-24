import SwiftUI

// MARK: - VAT / KDV Preview Component
// İşletme kullanıcıları için KDV hesaplama — Yapay Zeka entegrasyonu yakında

struct VATPreviewCard: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.colorScheme) var scheme
    @State private var baseAmount: String = ""
    @State private var selectedRate: TurkishVATRate = .standard
    @State private var isExpanded = false
    @FocusState private var amountFocused: Bool

    private var vatCalc: VATCalculation? {
        guard let amount = Double(baseAmount.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return VATCalculation(baseAmount: amount, vatRate: selectedRate.rawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
                Haptic.selection()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(ZColor.expense.opacity(0.13))
                            .frame(width: 34, height: 34)
                        Image(systemName: "percent")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ZColor.expense)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("vat.title", comment: ""))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(ZColor.label)
                        HStack(spacing: 5) {
                            Text(NSLocalizedString("vat.aiIntegration", comment: ""))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(ZColor.labelSec)
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(ZColor.indigo)
                        }
                    }

                    Spacer()

                    // Coming soon badge
                    Text(NSLocalizedString("vat.comingSoon", comment: ""))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(ZColor.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(ZColor.indigo.opacity(0.10))
                        )

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ZColor.labelTert)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(spacing: 14) {
                    // Amount input
                    HStack(spacing: 12) {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ZColor.labelSec)
                            .frame(width: 18)

                        TextField(NSLocalizedString("vat.base", comment: ""), text: $baseAmount)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                            .font(.system(size: 15, weight: .semibold))

                        Text(transactionVM.primaryCurrency)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(ZColor.labelSec)
                    }
                    .padding(.horizontal, 14)

                    Divider().padding(.horizontal, 14)

                    // VAT rate picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("vat.rate", comment: ""))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(ZColor.labelSec)
                            .textCase(.uppercase)
                            .tracking(0.4)
                            .padding(.horizontal, 14)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(TurkishVATRate.allCases, id: \.self) { rate in
                                    vatRateChip(rate)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }

                    // Result
                    if let calc = vatCalc, !baseAmount.isEmpty {
                        Divider().padding(.horizontal, 14)
                        vatResultRow(calc: calc)
                            .padding(.horizontal, 14)
                    }

                    // AI Preview banner
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#5E5CE6"), Color(hex: "#BF5AF2")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI-Powered VAT")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(ZColor.label)
                            Text("Automatic invoice categorization & VAT reconciliation — coming soon")
                                .font(.system(size: 11))
                                .foregroundColor(ZColor.labelSec)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(ZColor.indigo.opacity(0.07))
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.cardBorder(for: scheme), lineWidth: 0.5)
        )
    }

    private func vatRateChip(_ rate: TurkishVATRate) -> some View {
        let sel = selectedRate == rate
        return Button {
            selectedRate = rate
            Haptic.selection()
        } label: {
            Text(rate.displayName)
                .font(.system(size: 13, weight: sel ? .bold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(sel
                              ? ZColor.expense.opacity(0.14)
                              : Color(.tertiarySystemFill))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(sel ? ZColor.expense.opacity(0.45) : .clear, lineWidth: 1.5)
                )
                .foregroundColor(sel ? ZColor.expense : ZColor.labelSec)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: sel)
    }

    private func vatResultRow(calc: VATCalculation) -> some View {
        VStack(spacing: 8) {
            resultItem(
                label: NSLocalizedString("vat.base", comment: ""),
                value: calc.baseAmount,
                color: ZColor.label)
            Divider()
            resultItem(
                label: NSLocalizedString("vat.amount", comment: "") + " (\(selectedRate.displayName))",
                value: calc.vatAmount,
                color: ZColor.expense)
            Divider()
            resultItem(
                label: NSLocalizedString("vat.total", comment: ""),
                value: calc.totalAmount,
                color: ZColor.indigo,
                isBold: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.05) : Color(.tertiarySystemFill))
        )
    }

    private func resultItem(label: String, value: Double, color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: isBold ? .bold : .regular))
                .foregroundColor(isBold ? ZColor.label : ZColor.labelSec)
            Spacer()
            Text(value.formattedCurrency(code: transactionVM.primaryCurrency))
                .font(.system(size: 14, weight: isBold ? .black : .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - VAT Settings Section
// SettingsView içinde işletme kullanıcıları için gösterilir

struct BusinessVATSection: View {
    var body: some View {
        VATPreviewCard()
    }
}
