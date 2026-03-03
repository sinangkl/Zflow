import SwiftUI
import WatchKit

struct WatchQuickAddView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 0
    @State private var transactionType: String = "expense"
    @State private var amount: Double = 0
    @State private var selectedCategoryIdx = 0

    private var quickCategories: [(name: String, icon: String, color: String)] {
        transactionType == "expense" ? [
            ("Food",       "fork.knife",                   "#FB7185"),
            ("Transport",  "car.fill",                     "#38BDF8"),
            ("Shopping",   "bag.fill",                     "#F87171"),
            ("Coffee",     "cup.and.saucer.fill",          "#92400E"),
            ("Health",     "heart.fill",                   "#4ADE80"),
            ("Other",      "ellipsis.circle.fill",         "#94A3B8"),
        ] : [
            ("Salary",     "banknote.fill",                "#34D399"),
            ("Freelance",  "laptopcomputer",               "#60A5FA"),
            ("Investment", "chart.line.uptrend.xyaxis",    "#A78BFA"),
            ("Other",      "ellipsis.circle.fill",         "#94A3B8"),
        ]
    }

    var body: some View {
        Group {
            switch step {
            case 0: typeStep
            case 1: amountStep
            case 2: categoryStep
            case 3: confirmStep
            default: successView
            }
        }
        .navigationTitle(stepTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stepTitle: String {
        ["Type", "Amount", "Category", "Confirm", "Done"][min(step, 4)]
    }

    // MARK: Step 0 — Type

    private var typeStep: some View {
        VStack(spacing: 12) {
            typeButton("Expense", icon: "arrow.up.circle.fill",
                       color: wColor("#FF7F7F"), value: "expense")
            typeButton("Income",  icon: "arrow.down.circle.fill",
                       color: wColor("#50C878"), value: "income")
        }
        .padding(.horizontal, 4)
    }

    private func typeButton(_ label: String, icon: String, color: Color, value: String) -> some View {
        Button {
            transactionType = value
            WKInterfaceDevice.current().play(.click)
            withAnimation { step = 1 }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.10)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 1 — Amount

    private var amountStep: some View {
        let currency  = store.snapshot.currency
        let typeColor = transactionType == "expense" ? wColor("#FF7F7F") : wColor("#50C878")
        return VStack(spacing: 10) {
            Text(amount > 0
                 ? amount.formattedCurrencySimple(code: currency)
                 : "0 " + currency)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(typeColor)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .focusable()
                .digitalCrownRotation(
                    $amount, from: 0, through: 1_000_000,
                    by: 10, sensitivity: .medium,
                    isHapticFeedbackEnabled: true)

            Text("Turn Digital Crown")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Button("Next →") {
                guard amount > 0 else { return }
                WKInterfaceDevice.current().play(.click)
                withAnimation { step = 2 }
            }
            .buttonStyle(.borderedProminent)
            .tint(typeColor)
            .disabled(amount <= 0)
        }
    }

    // MARK: Step 2 — Category

    private var categoryStep: some View {
        List {
            ForEach(Array(quickCategories.enumerated()), id: \.offset) { idx, cat in
                Button {
                    selectedCategoryIdx = idx
                    WKInterfaceDevice.current().play(.click)
                    withAnimation { step = 3 }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(wColor(cat.color).opacity(0.14))
                                .frame(width: 28, height: 28)
                            Image(systemName: cat.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(wColor(cat.color))
                        }
                        Text(cat.name)
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    // MARK: Step 3 — Confirm

    private var confirmStep: some View {
        let cat = quickCategories[selectedCategoryIdx]
        let catColor  = wColor(cat.color)
        let typeColor = transactionType == "expense" ? wColor("#FF7F7F") : wColor("#50C878")

        let currency = store.snapshot.currency
        return VStack(spacing: 12) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(catColor.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: cat.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(catColor)
                }
                Text(amount.formattedCurrencySimple(code: currency))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(typeColor)
                Text(cat.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Button { sendToPhone() } label: {
                Label("Save", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(typeColor)

            Button("← Edit") { withAnimation { step = 1 } }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: Success

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(wColor("#50C878"))
                .padding(.top, 16)
            Text("Saved!")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text("Sending to iPhone…")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
    }

    // MARK: - Send to iPhone

    private func sendToPhone() {
        let cat = quickCategories[selectedCategoryIdx]
        let currency = store.snapshot.currency
        store.sendQuickAdd(WatchQuickAdd(
            amount:     amount,
            currency:   currency,
            type:       transactionType,
            categoryId: nil,
            note:       cat.name,
            date:       Date()))
        WKInterfaceDevice.current().play(.success)
        withAnimation { step = 99 }
    }
}
