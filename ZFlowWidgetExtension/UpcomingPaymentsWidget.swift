//
//  UpcomingPaymentsWidget.swift
//  ZFlowWidgetExtension
//
//  Yaklaşan Ödemeler Widget — StandBy, Lock Screen, systemSmall
//  recurring_transactions + scheduled_payments verilerini gösterir.
//
//  Desteklenen aileleler:
//  - accessoryRectangular (Lock Screen + StandBy)
//  - accessoryInline      (Lock Screen tek satır)
//  - systemSmall          (Home Screen küçük widget)
//

import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct ZFlowUpcomingWidget: Widget {
    let kind = "ZFlowUpcomingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            UpcomingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("Yaklaşan Ödemeler")
        .description("Upcoming recurring payments at a glance.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall
        ])
    }
}

// MARK: - Main View Router

struct UpcomingWidgetView: View {
    let entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangularView
        case .accessoryInline:      inlineView
        case .systemSmall:          smallView
        default:                    inlineView
        }
    }

    // ─── Upcoming items (en yakın 3 scheduled payment) ───
    private var upcomingItems: [SnapshotScheduledPayment] {
        let now = Date()
        return entry.snapshot.scheduledPayments
            .filter { $0.status == "pending" && $0.scheduledDate > now }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // MARK: - accessoryRectangular (156×72pt — StandBy + Lock Screen)

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 10, weight: .bold))
                Text("UPCOMING")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
            }
            .foregroundColor(.secondary)
            .widgetAccentable()

            if upcomingItems.isEmpty {
                Text("No upcoming payments")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            } else {
                ForEach(upcomingItems.prefix(2)) { item in
                    HStack(spacing: 6) {
                        // Type indicator
                        Circle()
                            .fill(item.type == "income"
                                  ? Color(hex: "#50C878")
                                  : Color(hex: "#FF7F7F"))
                            .frame(width: 5, height: 5)

                        // Title
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        Spacer()

                        // Amount
                        Text(item.amount.formattedShort(code: item.currency))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - accessoryInline (tek satır — Lock Screen)

    private var inlineView: some View {
        if let next = upcomingItems.first {
            Label(
                "\(next.title) · \(next.amount.formattedShort())",
                systemImage: next.type == "income" ? "arrow.up.circle" : "arrow.down.circle"
            )
            .font(.system(size: 12, weight: .bold))
            .widgetAccentable()
        } else {
            Label("No upcoming", systemImage: "checkmark.circle")
                .font(.system(size: 12, weight: .bold))
                .widgetAccentable()
        }
    }

    // MARK: - systemSmall (Home Screen 155×155pt)

    private var smallView: some View {
        let accentPrimary = Color(hex: entry.snapshot.accentPrimaryHex ?? "#5E5CE6")
        let accentSecondary = Color(hex: entry.snapshot.accentSecondaryHex ?? "#7D7AFF")

        return ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    accentPrimary.opacity(0.10),
                    Color(hex: "#09091E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle glow
            Circle()
                .fill(accentPrimary.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 50)
                .offset(x: -40, y: -30)

            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentPrimary, accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("UPCOMING")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.55))
                        .tracking(1.0)
                    Spacer()
                }

                if upcomingItems.isEmpty {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#34D399"), accentPrimary],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        Text("All clear!")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ForEach(upcomingItems.prefix(3)) { item in
                        upcomingRow(item)
                    }
                    Spacer()
                }
            }
            .padding(14)
        }
    }

    // MARK: - Small Widget Row

    private func upcomingRow(_ item: SnapshotScheduledPayment) -> some View {
        let isIncome = item.type == "income"
        let color = isIncome ? Color(hex: "#34D399") : Color(hex: "#FF7F7F")

        return HStack(spacing: 8) {
            // Type dot
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: isIncome ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(daysUntil(item.scheduledDate))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.45))
            }

            Spacer()

            Text(item.amount.formattedShort())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Helpers

    private func daysUntil(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days"
    }
}

// MARK: - StandBy Widget Upcoming Section
// Bu view mevcut StandbyWidgetView'a entegre edilmek içindir.

struct StandByUpcomingCard: View {
    let payments: [SnapshotScheduledPayment]
    let currency: String

    private var upcoming: [SnapshotScheduledPayment] {
        let now = Date()
        return payments
            .filter { $0.status == "pending" && $0.scheduledDate > now }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var body: some View {
        if upcoming.isEmpty { EmptyView() }
        else {
            VStack(alignment: .leading, spacing: 8) {
                Text("UPCOMING PAYMENTS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.55))
                    .tracking(1.0)

                ForEach(upcoming.prefix(2)) { item in
                    HStack(spacing: 10) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(typeColor(item.type).opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: item.type == "income"
                                  ? "arrow.up.circle.fill"
                                  : "arrow.down.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(typeColor(item.type))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(relativeDateString(item.scheduledDate))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.45))
                        }

                        Spacer()

                        Text(item.amount.formattedShort(code: currency))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(typeColor(item.type))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
            )
        }
    }

    private func typeColor(_ type: String) -> Color {
        type == "income" ? Color(hex: "#34D399") : Color(hex: "#FF7F7F")
    }

    private func relativeDateString(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days <= 7 { return "\(days) days left" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
