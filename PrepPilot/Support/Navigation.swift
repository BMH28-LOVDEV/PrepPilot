import Foundation

enum AppTab: Hashable {
    case dashboard
    case search
    case profile
}

enum AppRoute: Hashable {
    case lecture(UUID)
    case recording
    case transcript(UUID)
    case notes(UUID)
    case flashcards(UUID)
    case quiz(UUID)
    case studyGuide(UUID)
    case chat(UUID)
    case search
    case profile
    case paywall
    case settings
}
