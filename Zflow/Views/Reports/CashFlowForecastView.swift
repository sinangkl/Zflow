// ============================================================
// ZFlow — Cash Flow Forecast View
// 30-day income/expense projection based on recurring
// and scheduled payments.
// ============================================================

import SwiftUI
import Charts

struct CashFlowForecastView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @Environment(\.colorScheme) var scheme

    @State private var forecastDays: [ForecastDay] = []
    @State private var netProjection: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        summaryCard
                        chartCard
                        upcomingList
                    }
                    .padding(16)
                    .padding(.bottom, 85)
                }
            }
            .navigationTitle("Nakit Akışı Tahmini")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear { buildForecast() }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        GradientCard(gradient: AppTheme.accentGradient, cornerRadius: 20) {
            VStack(spacing: 8) {
                Text("30 Günlük Net Projeksiyon")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                Text(formatCurrency(netProjection))
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    projectionStat("Beklenen Gelir",
                                   value: forecastDays.map(\.income).reduce(0, +),
                                   color: ZColor.income)
                    projectionStat("Beklenen Gider",
                                   value: forecastDays.map(\.expense).reduce(0, +),
                                   color: ZColor.expense)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func projectionStat(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(formatCurrency(value))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.65))
        }
    }

    // MARK: - Bar Chart (iOS 16+)

    private var chartCard: some View {
        GlassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Günlük Nakit Akışı")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(forecastDays.prefix(14)) { day in
                            BarMark(
                                x: .value("Gün", day.label),
                                y: .value("Gelir", day.income)
                            )
                            .foregroundStyle(ZColor.income.gradient)

                            BarMark(
                                x: .value("Gün", day.label),
                                y: .value("Gider", -day.expense)
                            )
                            .foregroundStyle(ZColor.expense.gradient)
                        }
                        RuleMark(y: .value("Sıfır", 0))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                    }
                    .frame(height: 180)
                    .chartYAxis { AxisMarks(position: .leading) }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                } else {
                    Text("Grafik iOS 16+ gerektirir")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }

    // MARK: - Upcoming List

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YAKLAŞAN ÖDEMELER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            GlassCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    let events = upcomingEvents()
                    if events.isEmpty {
                        Text("Yaklaşan ödeme yok")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                            HStack(spacing: 12) {
                                Image(systemName: event.isIncome
                                      ? "arrow.down.circle.fill"
                                      : "arrow.up.circle.fill")
                                    .foregroundColor(event.isIncome ? ZColor.income : ZColor.expense)
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.name)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(event.date, style: .date)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(event.amount))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(event.isIncome ? ZColor.income : ZColor.expense)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if idx < events.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Forecast Builder

    private func buildForecast() {
        var days: [ForecastDay] = []
        let calendar = Calendar.current
        let today = Date()

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            var income: Double = 0
            var expense: Double = 0

            // Recurring transactions — use nextOccurrence
            for r in recurringVM.activeTransactions where r.isActive {
                if calendar.isDate(r.nextOccurrence, inSameDayAs: day) {
                    if let am = r.expectedAmount {
                        if r.transactionType == "income" { income += am } else { expense += am }
                    }
                }
            }
            // Scheduled payments — use scheduledDate, pending only
            for s in scheduledPaymentVM.scheduledPayments
                where s.status == "pending" || s.status == "ready" {
                if calendar.isDate(s.scheduledDate, inSameDayAs: day) {
                    expense += s.amount
                }
            }

            let df = DateFormatter()
            df.dateFormat = "d MMM"
            days.append(ForecastDay(
                date: day, label: df.string(from: day),
                income: income, expense: expense
            ))
        }

        forecastDays = days
        netProjection = days.map { $0.income - $0.expense }.reduce(0, +)
    }

    private func upcomingEvents() -> [UpcomingEvent] {
        var events: [UpcomingEvent] = []
        let today = Date()
        let thirtyDays = today.addingTimeInterval(86400 * 30)

        for r in recurringVM.activeTransactions where r.isActive {
            let next = r.nextOccurrence
            if next >= today, next <= thirtyDays {
                events.append(UpcomingEvent(
                    name: r.title,
                    date: next,
                    amount: r.expectedAmount ?? 0,
                    isIncome: r.transactionType == "income"
                ))
            }
        }
        for s in scheduledPaymentVM.scheduledPayments
            where s.status == "pending" || s.status == "ready" {
            if s.scheduledDate >= today, s.scheduledDate <= thirtyDays {
                events.append(UpcomingEvent(
                    name: s.title, date: s.scheduledDate,
                    amount: s.amount, isIncome: false
                ))
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    private func formatCurrency(_ value: Double) -> String {
        let code = UserDefaults.standard.string(forKey: "defaultCurrency") ?? "TRY"
        return value.formattedCurrency(code: code)
    }
}

// MARK: - Models

struct ForecastDay: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let income: Double
    let expense: Double
}

struct UpcomingEvent {
    let name: String
    let date: Date
    let amount: Double
    let isIncome: Bool
}
