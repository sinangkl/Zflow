// ============================================================
// ZFlow — CSV & JSON Export Service
// ============================================================

import Foundation
import UIKit
import SwiftUI

final class CSVExportService {

    // MARK: - CSV Generation

    static func generateCSV(transactions: [Transaction], currency: String) -> String {
        var csv = "Tarih,Tür,Tutar,Para Birimi,Not\n"
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]

        for t in transactions {
            let date = df.string(from: t.date ?? Date())
            let type = t.type == "income" ? "Gelir" : "Gider"
            let amount = String(format: "%.2f", t.amount)
            let note = (t.note ?? "").replacingOccurrences(of: ",", with: ";")
            let cur = t.currency
            csv += "\(date),\(type),\(amount),\(cur),\(note)\n"
        }
        return csv
    }

    // MARK: - Share Sheet (iOS)

    @MainActor
    static func shareCSV(transactions: [Transaction], currency: String) {
        let csv = generateCSV(transactions: transactions, currency: currency)
        guard let data = csv.data(using: .utf8) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZFlow_Transactions_\(timestamp()).csv")
        try? data.write(to: tempURL)
        presentShareSheet(url: tempURL)
    }

    @MainActor
    static func shareJSON(transactions: [Transaction]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(transactions) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZFlow_Transactions_\(timestamp()).json")
        try? data.write(to: tempURL)
        presentShareSheet(url: tempURL)
    }

    // MARK: - Helpers

    @MainActor
    private static func presentShareSheet(url: URL) {
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        scene?.windows.first?.rootViewController?.present(av, animated: true)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - CSV Export Button (SwiftUI reusable)

struct ExportFormatPicker: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @AppStorage("defaultCurrency") var defaultCurrency = "TRY"

    var body: some View {
        Menu {
            Button {
                CSVExportService.shareCSV(
                    transactions: transactionVM.transactions,
                    currency: defaultCurrency
                )
                Haptic.success()
            } label: {
                Label("CSV olarak dışa aktar", systemImage: "tablecells")
            }

            Button {
                CSVExportService.shareJSON(transactions: transactionVM.transactions)
                Haptic.success()
            } label: {
                Label("JSON olarak dışa aktar", systemImage: "curlybraces")
            }
        } label: {
            Label("Dışa Aktar", systemImage: "square.and.arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.baseColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.baseColor.opacity(0.10)))
        }
    }
}
