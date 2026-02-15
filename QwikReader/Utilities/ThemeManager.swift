import SwiftUI

enum ReaderTheme: String, CaseIterable, Codable {
    case light
    case sepia
    case gray
    case dark

    var backgroundColor: Color {
        switch self {
        case .light: return Color(.systemBackground)
        case .sepia: return Color(red: 0.97, green: 0.93, blue: 0.85)
        case .gray: return Color(UIColor.systemGray5)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        }
    }

    var textColor: Color {
        switch self {
        case .light: return .primary
        case .sepia: return Color(red: 0.27, green: 0.21, blue: 0.13)
        case .gray: return .primary
        case .dark: return Color(red: 0.9, green: 0.9, blue: 0.9)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: return .secondary
        case .sepia: return Color(red: 0.5, green: 0.42, blue: 0.33)
        case .gray: return .secondary
        case .dark: return Color(red: 0.65, green: 0.65, blue: 0.65)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

enum ArticleListLayout: String, CaseIterable, Codable {
    case large
    case magazine
    case compact

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .large: return "rectangle.grid.1x2"
        case .magazine: return "rectangle.grid.2x2"
        case .compact: return "list.bullet"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("readerTheme") var readerTheme: ReaderTheme = .light
    @AppStorage("articleListLayout") var articleListLayout: ArticleListLayout = .large
    @AppStorage("readerFontSize") var readerFontSize: Double = 17
    @AppStorage("autoNightMode") var autoNightMode: Bool = true
    @AppStorage("autoCacheReaderView") var autoCacheReaderView: Bool = false
    @AppStorage("autoCacheDays") var autoCacheDays: Int = 3

    private init() {}
}
