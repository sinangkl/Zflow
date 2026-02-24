import Foundation
import Combine

struct DefaultCategory {
    let name: String
    let color: String
    let icon: String
    let type: String        // "income" | "expense" | "both"
    let userType: String?   // nil = both, "personal", "business"
    var localizedKey: String { "category.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))" }
}

// MARK: - Default Categories (20+ per type)
// Her kategori için özenle seçilmiş renk ve ikon

let defaultCategories: [DefaultCategory] = [

    // ─── PERSONAL INCOME (8) ───────────────────────────────────
    DefaultCategory(name: "Salary",        color: "#34D399", icon: "banknote.fill",                type: "income",  userType: "personal"),
    DefaultCategory(name: "Freelance",     color: "#60A5FA", icon: "laptopcomputer",               type: "income",  userType: "personal"),
    DefaultCategory(name: "Investment",    color: "#A78BFA", icon: "chart.line.uptrend.xyaxis",    type: "income",  userType: "personal"),
    DefaultCategory(name: "Rental",        color: "#FBBF24", icon: "key.fill",                     type: "income",  userType: "personal"),
    DefaultCategory(name: "Bonus",         color: "#F9A8D4", icon: "star.circle.fill",             type: "income",  userType: "personal"),
    DefaultCategory(name: "Dividend",      color: "#2DD4BF", icon: "arrow.triangle.2.circlepath",  type: "income",  userType: "personal"),
    DefaultCategory(name: "Side Hustle",   color: "#FB923C", icon: "sparkles",                     type: "income",  userType: "personal"),
    DefaultCategory(name: "Gift Received", color: "#F472B6", icon: "gift.fill",                    type: "income",  userType: "personal"),

    // ─── PERSONAL EXPENSE (20) ────────────────────────────────
    DefaultCategory(name: "Groceries",     color: "#FB923C", icon: "cart.fill",                    type: "expense", userType: "personal"),
    DefaultCategory(name: "Shopping",      color: "#F87171", icon: "bag.fill",                     type: "expense", userType: "personal"),
    DefaultCategory(name: "Dining Out",    color: "#FB7185", icon: "fork.knife",                   type: "expense", userType: "personal"),
    DefaultCategory(name: "Coffee",        color: "#92400E", icon: "cup.and.saucer.fill",          type: "expense", userType: "personal"),
    DefaultCategory(name: "Entertainment", color: "#E879F9", icon: "gamecontroller.fill",          type: "expense", userType: "personal"),
    DefaultCategory(name: "Streaming",     color: "#EC4899", icon: "tv.fill",                      type: "expense", userType: "personal"),
    DefaultCategory(name: "Housing",       color: "#FBBF24", icon: "house.fill",                   type: "expense", userType: "personal"),
    DefaultCategory(name: "Transport",     color: "#38BDF8", icon: "car.fill",                     type: "expense", userType: "personal"),
    DefaultCategory(name: "Health",        color: "#4ADE80", icon: "heart.fill",                   type: "expense", userType: "personal"),
    DefaultCategory(name: "Pharmacy",      color: "#86EFAC", icon: "cross.case.fill",              type: "expense", userType: "personal"),
    DefaultCategory(name: "Education",     color: "#818CF8", icon: "book.fill",                    type: "expense", userType: "personal"),
    DefaultCategory(name: "Clothing",      color: "#F9A8D4", icon: "tshirt.fill",                  type: "expense", userType: "personal"),
    DefaultCategory(name: "Travel",        color: "#06B6D4", icon: "airplane",                     type: "expense", userType: "personal"),
    DefaultCategory(name: "Subscriptions", color: "#C084FC", icon: "repeat.circle.fill",           type: "expense", userType: "personal"),
    DefaultCategory(name: "Pets",          color: "#84CC16", icon: "pawprint.fill",                type: "expense", userType: "personal"),
    DefaultCategory(name: "Personal Care", color: "#FDA4AF", icon: "comb.fill",                    type: "expense", userType: "personal"),
    DefaultCategory(name: "Sports & Gym",  color: "#22D3EE", icon: "figure.run",                   type: "expense", userType: "personal"),
    DefaultCategory(name: "Electronics",   color: "#64748B", icon: "iphone",                       type: "expense", userType: "personal"),
    DefaultCategory(name: "Home & Garden", color: "#A3E635", icon: "leaf.fill",                    type: "expense", userType: "personal"),
    DefaultCategory(name: "Tax",           color: "#EF4444", icon: "percent",                      type: "expense", userType: "personal"),

    // ─── BUSINESS INCOME (8) ─────────────────────────────────
    DefaultCategory(name: "Product Sales", color: "#10B981", icon: "shippingbox.fill",             type: "income",  userType: "business"),
    DefaultCategory(name: "Service Fee",   color: "#3B82F6", icon: "wrench.and.screwdriver.fill",  type: "income",  userType: "business"),
    DefaultCategory(name: "Commission",    color: "#8B5CF6", icon: "handshake.fill",               type: "income",  userType: "business"),
    DefaultCategory(name: "Consulting",    color: "#14B8A6", icon: "person.2.fill",                type: "income",  userType: "business"),
    DefaultCategory(name: "Licensing",     color: "#34D399", icon: "doc.badge.gearshape.fill",     type: "income",  userType: "business"),
    DefaultCategory(name: "Grant / Fund",  color: "#F59E0B", icon: "rosette",                      type: "income",  userType: "business"),
    DefaultCategory(name: "Partnership",   color: "#60A5FA", icon: "link.circle.fill",             type: "income",  userType: "business"),
    DefaultCategory(name: "Return",        color: "#2DD4BF", icon: "arrow.uturn.left.circle.fill", type: "income",  userType: "business"),

    // ─── BUSINESS EXPENSE (20) ───────────────────────────────
    DefaultCategory(name: "Payroll",       color: "#F59E0B", icon: "person.badge.plus.fill",       type: "expense", userType: "business"),
    DefaultCategory(name: "Office Rent",   color: "#FBBF24", icon: "building.2.fill",              type: "expense", userType: "business"),
    DefaultCategory(name: "Raw Materials", color: "#FB923C", icon: "cube.fill",                    type: "expense", userType: "business"),
    DefaultCategory(name: "Manufacturing", color: "#F87171", icon: "gearshape.2.fill",             type: "expense", userType: "business"),
    DefaultCategory(name: "Marketing",     color: "#F472B6", icon: "megaphone.fill",               type: "expense", userType: "business"),
    DefaultCategory(name: "Advertising",   color: "#E879F9", icon: "display",                      type: "expense", userType: "business"),
    DefaultCategory(name: "Utilities",     color: "#38BDF8", icon: "bolt.fill",                    type: "expense", userType: "business"),
    DefaultCategory(name: "Insurance",     color: "#4ADE80", icon: "shield.fill",                  type: "expense", userType: "business"),
    DefaultCategory(name: "Software/SaaS", color: "#818CF8", icon: "app.badge.fill",               type: "expense", userType: "business"),
    DefaultCategory(name: "Logistics",     color: "#06B6D4", icon: "truck.box.fill",               type: "expense", userType: "business"),
    DefaultCategory(name: "Corporate Tax", color: "#EF4444", icon: "building.columns.fill",        type: "expense", userType: "business"),
    DefaultCategory(name: "Legal & Admin", color: "#94A3B8", icon: "doc.badge.gearshape.fill",     type: "expense", userType: "business"),
    DefaultCategory(name: "R&D",           color: "#7C3AED", icon: "flask.fill",                   type: "expense", userType: "business"),
    DefaultCategory(name: "Equipment",     color: "#64748B", icon: "desktopcomputer",              type: "expense", userType: "business"),
    DefaultCategory(name: "Office Supplies",color: "#A3E635",icon: "tray.full.fill",               type: "expense", userType: "business"),
    DefaultCategory(name: "Training",      color: "#22D3EE", icon: "graduationcap.fill",           type: "expense", userType: "business"),
    DefaultCategory(name: "Bank Charges",  color: "#64748B", icon: "creditcard.fill",              type: "expense", userType: "business"),
    DefaultCategory(name: "KDV / VAT",     color: "#DC2626", icon: "percent",                      type: "expense", userType: "business"),
    DefaultCategory(name: "Travel (Biz)",  color: "#0EA5E9", icon: "airplane.circle.fill",         type: "expense", userType: "business"),
    DefaultCategory(name: "Subcontracting",color: "#C084FC", icon: "person.crop.rectangle.fill",  type: "expense", userType: "business"),

    // ─── SHARED / BOTH ────────────────────────────────────────
    DefaultCategory(name: "Gift",          color: "#F472B6", icon: "gift.fill",                    type: "both",    userType: nil),
    DefaultCategory(name: "Other",         color: "#94A3B8", icon: "ellipsis.circle.fill",         type: "both",    userType: nil),
]

func defaultCategories(for userType: String) -> [DefaultCategory] {
    defaultCategories.filter { $0.userType == nil || $0.userType == userType }
}

let incomeCategoryNames: Set<String>  = Set(defaultCategories.filter { $0.type == "income"  || $0.type == "both" }.map { $0.name })
let expenseCategoryNames: Set<String> = Set(defaultCategories.filter { $0.type == "expense" || $0.type == "both" }.map { $0.name })
