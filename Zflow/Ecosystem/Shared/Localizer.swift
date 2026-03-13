import Foundation

// MARK: - Bundle Override for NSLocalizedString
// Makes NSLocalizedString() respect the in-app language selection,
// not just the device system language.
// Call Localizer.setupBundleOverride() once at app startup.
private final class BundleLocalizationOverride: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let lang = AppGroup.defaults.string(forKey: AppGroup.Key.language) ?? "en"
        if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            return langBundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Localizer

/// ZFlow Localizer: Shared utility for main app, Widgets, and Watch.
/// Uses AppGroup defaults to synchronize the user's selected language.
public final class Localizer {
    public static let shared = Localizer()
    private init() {}

    /// Call once at app startup to make NSLocalizedString() respect
    /// the in-app language selection instead of the device language.
    public static func setupBundleOverride() {
        object_setClass(Bundle.main, BundleLocalizationOverride.self)
    }

    private var currentBundle: Bundle {
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
    /// Checks for "category.name" pattern.
    public func category(_ name: String) -> String {
        let cleanName = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let key = "category.\(cleanName)"
        let localized = l(key)
        
        // If translation is missing (returns key itself), return original name
        if localized == key {
            return name
        }
        return localized
    }
}

// MARK: - Localizer Convenience String Extension
public extension String {
    var localized: String {
        Localizer.shared.l(self)
    }
    
    func localized(_ args: CVarArg...) -> String {
        String(format: Localizer.shared.l(self), arguments: args)
    }
}
