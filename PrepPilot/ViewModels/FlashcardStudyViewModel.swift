import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class FlashcardStudyViewModel {
    var currentIndex = 0
    var isShowingBack = false

    func resetIfNeeded(total: Int) {
        if currentIndex >= total {
            currentIndex = max(0, total - 1)
            isShowingBack = false
        }
    }

    func flip() {
        isShowingBack.toggle()
        Haptics.light()
    }

    func moveForward(total: Int) {
        guard total > 0 else { return }
        currentIndex = min(currentIndex + 1, total - 1)
        isShowingBack = false
        Haptics.light()
    }

    func moveBackward() {
        currentIndex = max(currentIndex - 1, 0)
        isShowingBack = false
        Haptics.light()
    }

    func mark(_ card: Flashcard, masteryDelta: Int, context: ModelContext) {
        card.mastery = min(5, max(0, card.mastery + masteryDelta))
        card.lastStudiedAt = .now
        card.updatedAt = .now
        try? context.save()
        Haptics.success()
    }
}
