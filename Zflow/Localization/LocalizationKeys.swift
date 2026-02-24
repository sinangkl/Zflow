import SwiftUI

// MARK: - Localization Helper
// Telefon dilini otomatik algılar — NSLocalizedString tüm Apple dilleri için

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    func localized(_ args: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), args)
    }
}

// MARK: - String Keys (type-safe enum)

enum L {
    // MARK: Onboarding
    static let onboardingTagline    = "onboarding.tagline"
    static let continue_            = "onboarding.continue"
    static let getStarted           = "onboarding.getStarted"
    static let skip                 = "onboarding.skip"

    // MARK: Auth
    static let signIn               = "auth.signIn"
    static let signUp               = "auth.signUp"
    static let email                = "auth.email"
    static let password             = "auth.password"
    static let fullName             = "auth.fullName"
    static let businessName         = "auth.businessName"
    static let rememberMe           = "auth.rememberMe"
    static let noAccount            = "auth.noAccount"
    static let haveAccount          = "auth.haveAccount"
    static let accountType          = "auth.accountType"
    static let personal             = "auth.personal"
    static let business             = "auth.business"
    static let createAccount        = "auth.createAccount"
    static let welcomeBack          = "auth.welcomeBack"

    // MARK: Tabs
    static let tabHome              = "tab.home"
    static let tabTransactions      = "tab.transactions"
    static let tabCalendar          = "tab.calendar"
    static let tabSettings          = "tab.settings"

    // MARK: Dashboard
    static let netBalance           = "dashboard.netBalance"
    static let income               = "dashboard.income"
    static let expense              = "dashboard.expense"
    static let insights             = "dashboard.insights"
    static let budgets              = "dashboard.budgets"
    static let recent               = "dashboard.recent"
    static let showMore             = "dashboard.showMore"
    static let showLess             = "dashboard.showLess"
    static let seeAll               = "dashboard.seeAll"
    static let noTransactions       = "dashboard.noTransactions"
    static let addFirst             = "dashboard.addFirst"
    static let addTransaction       = "dashboard.addTransaction"
    static let monthlyChange        = "dashboard.monthlyChange"
    static let transactions         = "dashboard.transactions"

    // MARK: Transactions
    static let newTransaction       = "transaction.new"
    static let editTransaction      = "transaction.edit"
    static let saveTransaction      = "transaction.save"
    static let updateTransaction    = "transaction.update"
    static let amount               = "transaction.amount"
    static let currency             = "transaction.currency"
    static let category             = "transaction.category"
    static let note                 = "transaction.note"
    static let date                 = "transaction.date"
    static let sortNewest           = "sort.newest"
    static let sortOldest           = "sort.oldest"
    static let sortHighest          = "sort.highest"
    static let sortLowest           = "sort.lowest"

    // MARK: Common
    static let cancel               = "common.cancel"
    static let done                 = "common.done"
    static let delete               = "common.delete"
    static let edit                 = "common.edit"
    static let save                 = "common.save"
    static let search               = "common.search"
    static let today                = "time.today"
    static let yesterday            = "time.yesterday"

    // MARK: Reports
    static let reports              = "reports.title"
    static let totalIncome          = "reports.totalIncome"
    static let totalExpense         = "reports.totalExpense"
    static let trend                = "reports.trend"
    static let breakdown            = "reports.breakdown"
    static let topCategories        = "reports.topCategories"
    static let comparison           = "reports.comparison"
    static let thisMonth            = "reports.thisMonth"
    static let lastMonth            = "reports.lastMonth"
    static let period7d             = "reports.7d"
    static let period30d            = "reports.30d"
    static let period90d            = "reports.90d"
    static let period1y             = "reports.1y"

    // MARK: Calendar
    static let calendarTitle        = "calendar.title"
    static let addEvent             = "calendar.addEvent"
    static let noEventsToday        = "calendar.noEventsToday"
    static let appleCalendar        = "calendar.apple"
    static let calPermTitle         = "calendar.permTitle"
    static let calPermDesc          = "calendar.permDesc"
    static let allowAccess          = "calendar.allowAccess"

    // MARK: Settings
    static let settings             = "settings.title"
    static let editProfile          = "settings.editProfile"
    static let addPhoto             = "settings.addPhoto"
    static let removePhoto          = "settings.removePhoto"
    static let saveChanges          = "settings.saveChanges"
    static let appearance           = "settings.appearance"
    static let preferences          = "settings.preferences"
    static let theme                = "settings.theme"
    static let themeSystem          = "settings.themeSystem"
    static let themeLight           = "settings.themeLight"
    static let themeDark            = "settings.themeDark"
    static let defaultCurrency      = "settings.defaultCurrency"
    static let staySignedIn         = "settings.staySignedIn"
    static let manageBudgets        = "settings.manageBudgets"
    static let manageCategories     = "settings.manageCategories"
    static let exportData           = "settings.exportData"
    static let signOut              = "settings.signOut"
    static let signOutConfirm       = "settings.signOutConfirm"
    static let version              = "settings.version"

    // MARK: Export
    static let exportTitle          = "export.title"
    static let exportSubtitle       = "export.subtitle"
    static let exportFormat         = "export.format"
    static let exportGenerate       = "export.generate"
    static let exportShare          = "export.share"

    // MARK: VAT / Tax (İşletme)
    static let vatTitle             = "vat.title"
    static let vatPreview           = "vat.preview"
    static let vatRate              = "vat.rate"
    static let vatBase              = "vat.base"
    static let vatAmount            = "vat.amount"
    static let vatTotal             = "vat.total"
    static let vatComingSoon        = "vat.comingSoon"
    static let vatAiIntegration     = "vat.aiIntegration"

    // MARK: Categories
    static let categoryOther        = "category.other"
}
