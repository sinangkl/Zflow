import Foundation

/// ZFlow Localizer Shim for Watch App.
/// This file ensures Localizer is in scope for the Watch target.
public final class Localizer {
    public static let shared = Localizer()
    private init() {}

    private var currentBundle: Bundle {
        // We use AppGroup defaults to sync language with the iPhone app
        let code = AppGroup.defaults.string(forKey: AppGroup.Key.language) ?? "en"
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }

    /// Localizes a key using the AppGroup-synced language.
    public func l(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: comment)
    }

    /// Helper for category names (e.g., "Food" -> "Yemek")
    public func category(_ name: String) -> String {
        let cleanName = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let key = "category.\(cleanName)"
        let localized = l(key)
        if localized == key {
            return name
        }
        return localized
    }
}

public extension String {
    var localized: String {
        Localizer.shared.l(self)
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: Localizer.shared.l(self), arguments: args)
    }
}
