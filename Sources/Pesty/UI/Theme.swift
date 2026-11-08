import SwiftUI

enum Theme {
    static let cardWidth: CGFloat = 215
    static let cardSpacing: CGFloat = 28
    static let cornerRadius: CGFloat = 22
    static let cardCorner: CGFloat = 19
    static let headerHeight: CGFloat = 68
    static let fileIconSize: CGFloat = 64
    static let appIconTileSize: CGFloat = 52
    static let appIconSize: CGFloat = 48
    static let footerHeight: CGFloat = 24
    /// Used by the header, the card body and the footer so their text lines up.
    static let contentInset: CGFloat = 14

    static let panelTint = Color.white.opacity(0.10)
    static let cardBody = Color(white: 0.085).opacity(0.94)
    static let cardBorder = Color.white.opacity(0.10)
    /// The plate behind an image. Slightly darker than the card body so the
    /// picture's own edges stay legible without a checkerboard.
    static let imagePlate = Color.black.opacity(0.30)
    static let selection = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let selectedCardRing: CGFloat = 6
    // Leave 43 pt beyond the selected-card ring at either strip edge while
    // preserving the ScrollView's normal clipping behavior.
    static let cardStripHorizontalPadding: CGFloat = selectedCardRing + 43

    static let chromeTextPrimary = Color.white.opacity(0.95)
    static let chromeTextSecondary = Color.white.opacity(0.55)
    static let chromeTextTertiary = Color.white.opacity(0.34)

    static let cardTextPrimary = Color.white.opacity(0.92)
    static let cardTextSecondary = Color.white.opacity(0.58)
    static let cardTextTertiary = Color.white.opacity(0.42)

    static let headerText = Color.white
    static let headerSubText = Color.white.opacity(0.78)

    static let fieldBG = Color.white.opacity(0.09)
    static let pillBG = Color.white.opacity(0.10)
    static let pillSelected = Color.white.opacity(0.18)
}

extension Date {
    var clipRelative: String {
        let secs = -timeIntervalSinceNow
        switch secs {
        case ..<5:        return "Now".localized
        case ..<60:       return "\(Int(secs))s"
        case ..<3600:     return "\(Int(secs / 60))m"
        case ..<86_400:   return "\(Int(secs / 3600))h"
        case ..<604_800:  return "\(Int(secs / 86_400))d"
        default:
            // The cards use clipRelativeLong today, so this branch is currently
            // unreachable, but it should still follow the same language.
            let locale = Self.appLocale
            let f = DateFormatter()
            f.locale = locale
            f.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMd", options: 0, locale: locale) ?? "MMM d"
            return f.string(from: self)
        }
    }

    var clipRelativeLong: String {
        let secs = -timeIntervalSinceNow
        if secs < 8 { return "Just now".localized }
        let f = RelativeDateTimeFormatter()
        f.locale = Self.appLocale
        f.unitsStyle = .full
        return f.localizedString(for: self, relativeTo: Date())
    }

    /// Dates follow the language picked inside the app, not the system one: an
    /// English Mac running the Chinese interface should read 11月8日 and 2小时前.
    private static var appLocale: Locale {
        Locale(identifier: LocalizationManager.shared.language.localeCode)
    }
}
