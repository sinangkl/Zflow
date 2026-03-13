import SwiftUI

// MARK: - Transaction Detail Sheet

struct TransactionDetailView: View {
    private let initialTransaction: Transaction
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    // Computed property to ensure UI always shows the "current" state in the VM
    private var transaction: Transaction {
        transactionVM.transactions.first(where: { $0.id == initialTransaction.id }) ?? initialTransaction
    }

    private var category: Category? {
        transactionVM.category(for: transaction.categoryId)
    }

    init(transaction: Transaction, category: Category?) {
        self.initialTransaction = transaction
    }

    @State private var showEdit   = false
    @State private var showDelete = false

    private var isIncome: Bool { transaction.type == "income" }
    private var catColor: Color { Color(hex: category?.color ?? "#8E8E93") }
    private var amountSign: String { isIncome ? "+" : "−" }

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // ── Hero amount card ──────────────────────────────
                        heroCard

                        // ── Details card ──────────────────────────────────
                        detailsCard

                        // ── Actions ───────────────────────────────────────
                        actionsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(NSLocalizedString("transaction.detail", comment: "Transaction Detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("common.close", comment: "")) { dismiss() }
                        .foregroundColor(AppTheme.baseColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showEdit = true
                            Haptic.light()
                        } label: {
                            Label(NSLocalizedString("common.edit", comment: ""), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDelete = true
                            Haptic.medium()
                        } label: {
                            Label(NSLocalizedString("common.delete", comment: ""), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.baseColor)
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                EditTransactionView(transaction: transaction)
                    .environmentObject(transactionVM)
                    .environmentObject(authVM)
            }
            .alert(
                NSLocalizedString("common.delete", comment: ""),
                isPresented: $showDelete
            ) {
                Button(NSLocalizedString("common.delete", comment: ""), role: .destructive) {
                    if let uid = authVM.currentUserId {
                        Task {
                            await transactionVM.deleteTransaction(id: transaction.id, userId: uid)
                            Haptic.success()
                            dismiss()
                        }
                    }
                }
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("common.deleteWarning", comment: ""))
            }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        GradientCard(
            gradient: isIncome ? AppTheme.incomeGradient : AppTheme.expenseGradient,
            cornerRadius: 22
        ) {
            VStack(spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 60, height: 60)
                    Image(systemName: category?.icon ?? "creditcard")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Category name
                Text(category?.localizedName ?? NSLocalizedString("category.other", comment: ""))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.82))
                    .textCase(.uppercase)
                    .tracking(0.6)

                // Amount
                Text("\(amountSign)\(transaction.amount.formattedCurrency(code: transaction.currency))")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                // Date
                if let date = transaction.date {
                    Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.70))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            if let note = transaction.note, !note.isEmpty {
                detailRow(
                    icon: "note.text",
                    iconColor: AppTheme.baseColor,
                    label: NSLocalizedString("transaction.note", comment: ""),
                    value: note
                )
                Divider().padding(.leading, 52)
            }

            detailRow(
                icon: isIncome ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                iconColor: isIncome ? ZColor.income : ZColor.expense,
                label: NSLocalizedString("transaction.type", comment: ""),
                value: isIncome
                    ? NSLocalizedString("dashboard.income", comment: "")
                    : NSLocalizedString("dashboard.expense", comment: "")
            )
            Divider().padding(.leading, 52)

            detailRow(
                icon: "coloncurrencysign.circle.fill",
                iconColor: ZColor.purple,
                label: NSLocalizedString("transaction.currency", comment: ""),
                value: transaction.currency
            )
            Divider().padding(.leading, 52)

            // Converted amount (if different currency)
            if transaction.currency != transactionVM.primaryCurrency {
                let converted = CurrencyConverter.convert(
                    amount: transaction.amount,
                    from: transaction.currency,
                    to: transactionVM.primaryCurrency)
                detailRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: ZColor.warning,
                    label: "≈ \(transactionVM.primaryCurrency)",
                    value: converted.formattedCurrency(code: transactionVM.primaryCurrency)
                )
                Divider().padding(.leading, 52)
            }

            if let date = transaction.date {
                detailRow(
                    icon: "calendar",
                    iconColor: Color(hex: "#0EA5E9"),
                    label: NSLocalizedString("transaction.date", comment: ""),
                    value: date.formatted(.dateTime.day().month(.wide).year())
                )
            }
        }
        .zFlowCard()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(iconColor)
            }

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(ZColor.labelSec)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ZColor.label)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button {
                showEdit = true
                Haptic.light()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 18))
                    Text(NSLocalizedString("common.edit", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppTheme.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                showDelete = true
                Haptic.medium()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                    Text(NSLocalizedString("common.delete", comment: ""))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(ZColor.expense)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(ZColor.expense.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(ZColor.expense.opacity(0.25), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
