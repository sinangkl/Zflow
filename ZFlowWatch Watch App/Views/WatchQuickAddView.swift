import SwiftUI
import WatchKit

struct WatchQuickAddView: View {
    @EnvironmentObject var store: WatchStore
    @Environment(\.dismiss) var dismiss

    @State private var step: Int = 0
    @State private var transactionType: String = "expense"
    
    // Amount & Keypad
    @State private var amountString: String = "0"
    private var amount: Double { Double(amountString) ?? 0 }
    
    // Currency
    @State private var selectedCurrencyCode: String = ""
    private var baseCurrency: String { store.snapshot.currency }

    @State private var selectedCategoryIdx = 0

    // Use real categories from snapshot; fall back to hardcoded if empty
    private var availableCategories: [(id: UUID?, name: String, icon: String, color: String)] {
        let snapshotCats = store.snapshot.categories.filter {
            switch transactionType {
            case "expense": return $0.type == "expense" || $0.type == "both"
            case "income":  return $0.type == "income"  || $0.type == "both"
            default:        return true
            }
        }

        if !snapshotCats.isEmpty {
            return snapshotCats.map { (id: $0.id, name: $0.name, icon: $0.icon, color: $0.color) }
        }

        // Fallback
        if transactionType == "expense" {
            return [
                (nil, "Food",       "fork.knife",           "#FB7185"),
                (nil, "Transport",  "car.fill",             "#38BDF8"),
                (nil, "Shopping",   "bag.fill",             "#F87171"),
                (nil, "Coffee",     "cup.and.saucer.fill",  "#92400E"),
                (nil, "Health",     "heart.fill",           "#4ADE80"),
                (nil, "Other",      "ellipsis.circle.fill", "#94A3B8"),
            ]
        } else {
            return [
                (nil, "Salary",     "banknote.fill",             "#34D399"),
                (nil, "Freelance",  "laptopcomputer",            "#60A5FA"),
                (nil, "Investment", "chart.line.uptrend.xyaxis", "#A78BFA"),
                (nil, "Other",      "ellipsis.circle.fill",      "#94A3B8"),
            ]
        }
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
        .onAppear {
            if selectedCurrencyCode.isEmpty {
                selectedCurrencyCode = baseCurrency
            }
        }
    }

    private var stepTitle: String {
        let keys = ["transaction.type", "transaction.amount", "transaction.category", "watch.confirm", "common.done"]
        return Localizer.shared.l(keys[min(step, 4)])
    }

    // MARK: Step 0 — Type

    private var typeStep: some View {
        VStack(spacing: 12) {
            typeButton(Localizer.shared.l("dashboard.income"),  icon: "arrow.up.circle.fill",
                       color: wColor("#50C878"), value: "income")
            typeButton(Localizer.shared.l("dashboard.expense"), icon: "arrow.down.circle.fill",
                       color: wColor("#FF7F7F"), value: "expense")
        }
        .padding(.horizontal, 4)
    }

    private func typeButton(_ label: String, icon: String, color: Color, value: String) -> some View {
        Button {
            transactionType = value
            selectedCategoryIdx = 0
            WKInterfaceDevice.current().play(.directionUp)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step = 1 }
        } label: {
            HStack(spacing: 12) {
                if #available(watchOS 11.0, iOS 18.0, *) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                        .symbolEffect(.bounce, options: .nonRepeating, value: transactionType == value)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 1 — Amount (Keypad)

    private var amountStep: some View {
        let typeColor = transactionType == "expense" ? wColor("#FF7F7F") : wColor("#50C878")
        let currencies = WatchCurrencyConverter.supportedCurrencies
        
        return ScrollView {
            VStack(spacing: 6) {
                // Header: Amount & Currency Picker
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(amountString)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(typeColor)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                        
                        // Kur Farkı (Converted amount)
                        if selectedCurrencyCode != baseCurrency {
                            let converted = WatchCurrencyConverter.convert(amount: amount, from: selectedCurrencyCode, to: baseCurrency)
                            Text("≈ \(converted.formattedCurrencySimple(code: baseCurrency))")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $selectedCurrencyCode) {
                        ForEach(currencies, id: \.code) { c in
                            Text(c.code).tag(c.code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 55, height: 32)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
                
                // Keypad
                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"], id: \.self) { key in
                        Button {
                            handleKeypad(key)
                        } label: {
                            Text(key)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                }
                
                Button("\(Localizer.shared.l("watch.next")) →") {
                    guard amount > 0 else { return }
                    WKInterfaceDevice.current().play(.click)
                    withAnimation { step = 2 }
                }
                .buttonStyle(.borderedProminent)
                .tint(typeColor)
                .disabled(amount <= 0)
                .frame(height: 38) // Slightly taller for better hit target
                .padding(.top, 10) // More separation from "0" button
                .padding(.bottom, 4)
            }
        }
    }
    
    private func handleKeypad(_ key: String) {
        WKInterfaceDevice.current().play(.click)
        if key == "⌫" {
            if amountString.count > 1 {
                amountString.removeLast()
            } else {
                amountString = "0"
            }
        } else if key == "." {
            if !amountString.contains(".") {
                amountString += "."
            }
        } else {
            if amountString == "0" {
                amountString = key
            } else {
                if let dotIdx = amountString.firstIndex(of: ".") {
                    let decimals = amountString.distance(from: dotIdx, to: amountString.endIndex) - 1
                    if decimals < 2 {
                        amountString += key
                    }
                } else {
                    amountString += key
                }
            }
        }
    }

    // MARK: Step 2 — Category (Grid)

    private var categoryStep: some View {
        let cats = availableCategories
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
        
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(cats.enumerated()), id: \.offset) { idx, cat in
                    Button {
                        selectedCategoryIdx = idx
                        WKInterfaceDevice.current().play(.directionUp)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { step = 3 }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(wColor(cat.color).opacity(0.18))
                                    .frame(width: 38, height: 38)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(wColor(cat.color))
                            }
                            Text(Localizer.shared.category(cat.name))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(wColor(cat.color).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
    }

    // MARK: Step 3 — Confirm

    private var confirmStep: some View {
        let cats = availableCategories
        let cat = cats[min(selectedCategoryIdx, cats.count - 1)]
        let catColor  = wColor(cat.color)
        let typeColor = transactionType == "expense" ? wColor("#FF7F7F") : wColor("#50C878")

        return VStack(spacing: 12) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(catColor.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: cat.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(catColor)
                }
                
                VStack(spacing: 2) {
                    Text(amount.formattedCurrencySimple(code: selectedCurrencyCode))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(typeColor)
                    
                    if selectedCurrencyCode != baseCurrency {
                        let converted = WatchCurrencyConverter.convert(amount: amount, from: selectedCurrencyCode, to: baseCurrency)
                        Text("≈ \(converted.formattedCurrencySimple(code: baseCurrency))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(Localizer.shared.category(cat.name))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Button { sendToPhone() } label: {
                Label(Localizer.shared.l("common.save"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(typeColor)

            Button("← \(Localizer.shared.l("common.edit"))") { withAnimation { step = 1 } }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: Success

    private var successView: some View {
        VStack(spacing: 12) {
            if #available(watchOS 11.0, iOS 18.0, *) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(wColor("#50C878"))
                    .symbolEffect(.bounce, options: .nonRepeating)
                    .padding(.top, 16)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(wColor("#50C878"))
                    .padding(.top, 16)
            }
            Text(Localizer.shared.l("watch.saved"))
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text(Localizer.shared.l("watch.sendingToPhone"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
    }

    // MARK: - Send to iPhone

    private func sendToPhone() {
        let cats = availableCategories
        let cat = cats[min(selectedCategoryIdx, cats.count - 1)]
        
        let quickAdd = WatchQuickAdd(
            amount:     amount,
            currency:   selectedCurrencyCode,
            type:       transactionType,
            categoryId: cat.id,
            note:       cat.name,
            date:       Date()
        )
        
        store.sendQuickAdd(quickAdd)
        WKInterfaceDevice.current().play(.success)
        withAnimation { step = 99 }
    }
}
