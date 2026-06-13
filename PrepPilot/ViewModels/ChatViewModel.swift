import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    var draft = ""
    var isResponding = false
    var errorMessage: String?

    private let aiService: StudyAIProviding

    init(aiService: StudyAIProviding) {
        self.aiService = aiService
    }

    func send(lectureID: UUID, noteContext: String, context: ModelContext) async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isResponding else { return }

        draft = ""
        errorMessage = nil
        isResponding = true
        context.insert(AIChatMessage(lectureID: lectureID, role: .user, content: question))
        try? context.save()

        do {
            let answer = try await aiService.answer(question: question, noteContext: noteContext)
            context.insert(AIChatMessage(lectureID: lectureID, role: .assistant, content: answer.content, sources: answer.sources))
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        isResponding = false
    }
}
