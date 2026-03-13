import Foundation
import Combine

// MARK: - Language Manager
// App-içi dil değiştirme
// Bundle.main'i override ederek anında dil değişimi sağlar

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            UserDefaults.standard.synchronize()
            
            // Sync to AppGroup for Extensions
            AppGroup.defaults.set(currentLanguage, forKey: AppGroup.Key.language)
            AppGroup.defaults.synchronize()
            
            Bundle.setLanguage(currentLanguage)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage")
        let system = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
        let lang = saved ?? system
        self.currentLanguage = AppLanguage.allLanguages.contains(where: { $0.code == lang }) ? lang : "en"
        Bundle.setLanguage(self.currentLanguage)
    }
}

// MARK: - Supported Languages

struct AppLanguage: Identifiable, Hashable {
    let code: String        // ISO 639-1: "tr", "en", "de" …
    let flag: String        // 🇹🇷, 🇺🇸 …
    let hasTranslation: Bool // .lproj dosyası var mı?

    var id: String { code }

    /// Dilin kendi dilindeki adı: "Türkçe", "English", "Deutsch" …
    var displayName: String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.localizedCapitalized ?? code.uppercased()
    }

    // ─── Languages with complete translations ───

    static let allLanguages: [AppLanguage] = [
        AppLanguage(code: "tr", flag: "🇹🇷", hasTranslation: true),
        AppLanguage(code: "en", flag: "🇺🇸", hasTranslation: true),
        AppLanguage(code: "de", flag: "🇩🇪", hasTranslation: true),
        AppLanguage(code: "fr", flag: "🇫🇷", hasTranslation: true),
        AppLanguage(code: "es", flag: "🇪🇸", hasTranslation: true),
        AppLanguage(code: "it", flag: "🇮🇹", hasTranslation: true),
        AppLanguage(code: "pt", flag: "🇧🇷", hasTranslation: true),
        AppLanguage(code: "nl", flag: "🇳🇱", hasTranslation: true),
        AppLanguage(code: "ru", flag: "🇷🇺", hasTranslation: true),
        AppLanguage(code: "ja", flag: "🇯🇵", hasTranslation: true),
        AppLanguage(code: "ko", flag: "🇰🇷", hasTranslation: true),
        AppLanguage(code: "zh", flag: "🇨🇳", hasTranslation: true),
        AppLanguage(code: "ar", flag: "🇸🇦", hasTranslation: true),
        AppLanguage(code: "hi", flag: "🇮🇳", hasTranslation: true),
        AppLanguage(code: "pl", flag: "🇵🇱", hasTranslation: true),
        AppLanguage(code: "sv", flag: "🇸🇪", hasTranslation: true),
        AppLanguage(code: "da", flag: "��", hasTranslation: true),
        AppLanguage(code: "fi", flag: "�", hasTranslation: true),
        AppLanguage(code: "nb", flag: "🇳🇴", hasTranslation: true),
    ]
}

// MARK: - Bundle Override

private var bundleKey: UInt8 = 0

extension Bundle {
    static func setLanguage(_ language: String) {
        defer { object_setClass(Bundle.main, OverriddenBundle.self) }

        objc_setAssociatedObject(
            Bundle.main,
            &bundleKey,
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

private class OverriddenBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}
