// ============================================================
// ZFlow Watch — Currency Converter View
// ============================================================
import SwiftUI
import WatchKit

struct WatchCurrencyView: View {
    @EnvironmentObject var store: WatchStore
    
    @State private var amountString: String = "100"
    private var amount: Double { Double(amountString) ?? 0 }
    
    @State private var fromIdx = 0
    @State private var toIdx   = 1

    private let currencies = WatchCurrencyConverter.supportedCurrencies

    private var fromCode: String { currencies[fromIdx].code }
    private var toCode: String   { currencies[toIdx].code }
    private var converted: Double {
        WatchCurrencyConverter.convert(amount: amount, from: fromCode, to: toCode)
    }
    private var rate: Double {
        WatchCurrencyConverter.rate(from: fromCode, to: toCode)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header: Swapper
                HStack(spacing: 6) {
                    currencyPill(label: Localizer.shared.l("watch.from"), idx: $fromIdx)
                    Button {
                        let tmp = fromIdx
                        fromIdx = toIdx
                        toIdx = tmp
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "arrow.right.arrow.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(wColor("#5E5CE6"))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    currencyPill(label: Localizer.shared.l("watch.to"), idx: $toIdx)
                }

                HStack {
                    Text(amountString)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Spacer()
                    Text(fromCode)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal, 4)

                // Result card
                VStack(spacing: 4) {
                    Text(converted.formattedCurrencySimple(code: toCode))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(wColor("#50C878"))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)

                    Text("1 \(fromCode) = \(String(format: "%.4f", rate)) \(toCode)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(wColor("#50C878").opacity(0.3), lineWidth: 1)
                )

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
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(Localizer.shared.l("watch.convert"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let idx = currencies.firstIndex(where: { $0.code == store.snapshot.currency }) {
                fromIdx = idx
                toIdx = idx == 0 ? 1 : 0
            }
        }
    }

    private func currencyPill(label: String, idx: Binding<Int>) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
            Picker(label, selection: idx) {
                ForEach(0..<currencies.count, id: \.self) { i in
                    Text("\(currencies[i].flag) \(currencies[i].code)")
                        .font(.system(size: 11))
                        .tag(i)
                }
            }
            .labelsHidden()
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.1))
            )
        }
        .frame(maxWidth: .infinity)
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
}
