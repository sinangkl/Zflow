// ============================================================
// ZFlow Watch — Category Management View
// Uses real categories from snapshot (synced from iPhone)
// ============================================================
import SwiftUI
import WatchKit

struct WatchCategoryView: View {
    @EnvironmentObject var store: WatchStore
    @State private var filter: String = "all"

    private var filteredCategories: [SnapshotCategory] {
        switch filter {
        case "expense": return store.snapshot.categories.filter { $0.type == "expense" || $0.type == "both" }
        case "income":  return store.snapshot.categories.filter { $0.type == "income"  || $0.type == "both" }
        default:        return store.snapshot.categories
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Filter pills
                HStack(spacing: 6) {
                    filterPill(Localizer.shared.l("watch.shortAll"), value: "all")
                    filterPill(Localizer.shared.l("watch.shortExp"), value: "expense")
                    filterPill(Localizer.shared.l("watch.shortInc"), value: "income")
                }

                if filteredCategories.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text(Localizer.shared.l("watch.noCategories"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(Localizer.shared.l("watch.addCategoriesIPhone"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 2)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(filteredCategories) { cat in
                            categoryCard(cat)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .navigationTitle(Localizer.shared.l("transaction.categories"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterPill(_ label: String, value: String) -> some View {
        let active = filter == value
        return Button {
            filter = value
            WKInterfaceDevice.current().play(.click)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: active ? .bold : .medium))
                .foregroundColor(active ? .white : .white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? wColor("#5E5CE6") : Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func categoryCard(_ cat: SnapshotCategory) -> some View {
        let catColor = wColor(cat.color)
        let typeLabel: String = {
            switch cat.type {
            case "income":  return Localizer.shared.l("watch.shortInc")
            case "expense": return Localizer.shared.l("watch.shortExp")
            default:        return Localizer.shared.l("watch.both")
            }
        }()
        let typeColor: Color = {
            switch cat.type {
            case "income":  return wColor("#50C878")
            case "expense": return wColor("#FF7F7F")
            default:        return wColor("#5E5CE6")
            }
        }()

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(catColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: cat.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(catColor)
            }

            VStack(spacing: 1) {
                Text(Localizer.shared.category(cat.name))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(typeLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(typeColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(catColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(catColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
