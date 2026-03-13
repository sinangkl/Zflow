import Foundation

/// ZFlow Localizer Shim for Widgets.
/// This file ensures Localizer is in scope for the Widget target.
public final class Localizer {
    public static let shared = Localizer()
    private init() {}

    private var currentBundle: Bundle {
        let code = AppGroup.defaults.string(forKey: AppGroup.Key.language) ?? "en"
        // Try to find the specific language bundle
        if let path = Bundle(for: Localizer.self).path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        // Fallback to base or main bundle
        return Bundle(for: Localizer.self)
    }

    public func l(_ key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: currentBundle, comment: comment)
    }

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
