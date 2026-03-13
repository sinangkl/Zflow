import WidgetKit
import SwiftUI
import AppIntents

struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZFlowProvider()) { entry in
            QuickAddWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetGradientBackground(snapshot: entry.snapshot) }
        }
        .configurationDisplayName("Quick Add")
        .description("One-tap transaction entry for your categories.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Quick Add View

struct QuickAddWidgetView: View {
    var entry: ZFlowEntry
    @Environment(\.widgetFamily) var family

    // Snapshot'tan gelen harcama kategorileri (ilk 4 tane)
    private var categories: [SnapshotCategory] {
        let expenseCategories = entry.snapshot.categories.filter { $0.type == "expense" || $0.type == "both" }
        if expenseCategories.isEmpty {
            // Fallback: varsayılan kategoriler
            return [
                SnapshotCategory(id: UUID(), name: "Yemek",     icon: "fork.knife",          color: "#FB923C", type: "expense"),
                SnapshotCategory(id: UUID(), name: "Ulaşım",    icon: "bus.fill",             color: "#60A5FA", type: "expense"),
                SnapshotCategory(id: UUID(), name: "Market",    icon: "cart.fill",            color: "#34D399", type: "expense"),
                SnapshotCategory(id: UUID(), name: "Kahve",     icon: "cup.and.saucer.fill",  color: "#A78BFA", type: "expense"),
            ]
        }
        return Array(expenseCategories.prefix(family == .systemSmall ? 2 : 4))
    }

    var body: some View {
        VStack(spacing: 6) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary.opacity(0.7))
                Text("Quick Add")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 2)

            // Category Buttons
            HStack(spacing: 8) {
                ForEach(categories) { cat in
                    quickAddButton(for: cat)
                }
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func quickAddButton(for cat: SnapshotCategory) -> some View {
        let encodedName = cat.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cat.name
        let url = URL(string: "zflow://addTransaction?category=\(encodedName)") ?? URL(string: "zflow://addTransaction")!
        Link(destination: url) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: cat.color).opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: cat.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: cat.color))
                }
                Text(cat.name)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
