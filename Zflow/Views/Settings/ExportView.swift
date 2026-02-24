import SwiftUI
import UIKit

struct ZFlowExportView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var scheme

    @State private var isGenerating = false
    @State private var shareItem: ExportItem? = nil
    @State private var showShare   = false
    @State private var selectedFormat: ExportFormat = .csv

    enum ExportFormat: String, CaseIterable {
        case csv = "CSV", pdf = "PDF"
        var icon: String { self == .csv ? "doc.text.fill" : "doc.richtext.fill" }
        var color: Color { self == .csv ? ZColor.income : ZColor.expense }
        var desc: String {
            self == .csv
            ? "For Excel, Numbers or Google Sheets"
            : "Formatted report for printing or sharing"
        }
    }

    struct ExportItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundStyle(AppTheme.accentGradient)
                            Text(L.exportTitle.localized)
                                .font(.system(size: 24, weight: .bold))
                            Text("\(transactionVM.transactions.count) transactions available")
                                .font(.system(size: 14))
                                .foregroundColor(ZColor.labelSec)
                        }
                        .padding(.top, 32)

                        // Format picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export Format")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(ZColor.labelSec)
                                .textCase(.uppercase)
                                .tracking(0.4)
                                .padding(.horizontal, 4)

                            ForEach(ExportFormat.allCases, id: \.rawValue) { fmt in
                                Button {
                                    withAnimation(.spring(response: 0.25)) { selectedFormat = fmt }
                                    Haptic.selection()
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(fmt.color.opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: fmt.icon)
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(fmt.color)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(fmt.rawValue)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(ZColor.label)
                                            Text(fmt.desc)
                                                .font(.system(size: 13))
                                                .foregroundColor(ZColor.labelSec)
                                        }
                                        Spacer()
                                        Image(systemName: selectedFormat == fmt ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedFormat == fmt ? ZColor.indigo : ZColor.labelTert)
                                            .font(.system(size: 20))
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                selectedFormat == fmt ? ZColor.indigo.opacity(0.5) : Color.clear,
                                                lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Export button
                        Button {
                            generate()
                        } label: {
                            Group {
                                if isGenerating {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: selectedFormat.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(selectedFormat == .csv ? L.exportCSV.localized : L.exportPDF.localized)
                                            .font(.system(size: 17, weight: .bold))
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.accentGradient))
                        }
                        .disabled(isGenerating || transactionVM.transactions.isEmpty)
                        .opacity(transactionVM.transactions.isEmpty ? 0.5 : 1)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.done.localized) { dismiss() }
                        .foregroundColor(ZColor.indigo)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private func generate() {
        isGenerating = true
        Haptic.medium()
        Task {
            let url: URL?
            if selectedFormat == .csv {
                url = generateCSV()
            } else {
                url = generatePDF()
            }
            await MainActor.run {
                isGenerating = false
                if let url {
                    shareItem = ExportItem(url: url)
                }
            }
        }
    }

    private func generateCSV() -> URL? {
        var csv = "Date,Type,Amount,Currency,Category,Note\n"
        let sorted = transactionVM.transactions.sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }
        for t in sorted {
            let date = t.date?.formatted(.dateTime.year().month().day()) ?? ""
            let cat  = transactionVM.category(for: t.categoryId)?.name ?? ""
            let note = (t.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(date)\",\"\(t.type ?? "")\",\(t.amount),\(t.currency),\"\(cat)\",\"\(note)\"\n"
        }
        return writeTemp(data: csv.data(using: .utf8) ?? Data(), name: "ZFlow_export_\(todayStr()).csv")
    }

    private func generatePDF() -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            drawPDF(in: ctx.cgContext)
        }
        return writeTemp(data: data, name: "ZFlow_report_\(todayStr()).pdf")
    }

    private func drawPDF(in ctx: CGContext) {
        let accentUIColor = UIColor(ZColor.indigo)
        let sorted = transactionVM.transactions.sorted {
            ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
        }

        // Header
        let headerRect = CGRect(x: 0, y: 0, width: 595, height: 80)
        ctx.setFillColor(UIColor(ZColor.indigo).cgColor)
        ctx.fill(headerRect)

        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        "ZFlow — Financial Report".draw(at: CGPoint(x: 24, y: 24), withAttributes: titleAttr)

        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.white.withAlphaComponent(0.75)
        ]
        "Generated \(Date().formatted(.dateTime.day().month(.wide).year()))".draw(at: CGPoint(x: 24, y: 52), withAttributes: subAttr)

        // Summary row
        var y: CGFloat = 100
        let summaryAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        "Total Income: \(transactionVM.thisMonthIncome.formattedCurrency(code: transactionVM.primaryCurrency))    Total Expense: \(transactionVM.thisMonthExpense.formattedCurrency(code: transactionVM.primaryCurrency))    Net Balance: \(transactionVM.netBalance.formattedCurrency(code: transactionVM.primaryCurrency))"
            .draw(at: CGPoint(x: 24, y: y), withAttributes: summaryAttr)
        y += 28

        // Separator
        ctx.setStrokeColor(UIColor.separator.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 24, y: y)); ctx.addLine(to: CGPoint(x: 571, y: y))
        ctx.strokePath()
        y += 12

        // Table header
        let colAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor(ZColor.indigo)
        ]
        ["Date", "Type", "Category", "Amount", "Note"].enumerated().forEach { i, title in
            let x: CGFloat = [24, 104, 174, 334, 424][i]
            title.draw(at: CGPoint(x: x, y: y), withAttributes: colAttrs)
        }
        y += 18

        // Rows
        let rowAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.label
        ]
        for (i, t) in sorted.prefix(60).enumerated() {
            if i % 2 == 0 {
                ctx.setFillColor(UIColor.tertiarySystemFill.cgColor)
                ctx.fill(CGRect(x: 20, y: y - 3, width: 555, height: 16))
            }
            let date = t.date?.formatted(.dateTime.day().month(.abbreviated).year()) ?? ""
            let cat  = transactionVM.category(for: t.categoryId)?.name ?? ""
            let amt  = t.amount.formattedCurrency(code: t.currency)
            let note = String((t.note ?? "").prefix(22))

            date.draw(at: CGPoint(x: 24, y: y), withAttributes: rowAttr)
            (t.type?.capitalized ?? "").draw(at: CGPoint(x: 104, y: y), withAttributes: rowAttr)
            cat.draw(at: CGPoint(x: 174, y: y), withAttributes: rowAttr)
            amt.draw(at: CGPoint(x: 334, y: y), withAttributes: rowAttr)
            note.draw(at: CGPoint(x: 424, y: y), withAttributes: rowAttr)
            y += 16
            if y > 800 { break }
        }

        // Footer
        let footerAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.tertiaryLabel
        ]
        "ZFlow — Exported \(Date().formatted())  |  \(sorted.count) transactions".draw(
            at: CGPoint(x: 24, y: 820), withAttributes: footerAttr)
    }

    private func writeTemp(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: url)
        return url
    }

    private func todayStr() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: Date())
    }
}
