import Foundation

/// Helper for pre-defined categories in widgets
public struct WidgetCategory: Identifiable {
    public let id = UUID()
    public let name: String
    public let icon: String
    public let type: String
    
    public init(name: String, icon: String, type: String) {
        self.name = name
        self.icon = icon
        self.type = type
    }
}
