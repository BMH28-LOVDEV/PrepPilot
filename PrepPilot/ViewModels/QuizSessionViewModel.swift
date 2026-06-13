import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class QuizSessionViewModel {
    var answers: [UUID: String] = [:]
    var isSubmitted = false

    func answer(_ question: QuizQuestion, with value: String) {
        guard !isSubmitted else { return }
        answers[question.id] = value
        Haptics.light()
    }

    func submit(quiz: Quiz, questions: [QuizQuestion], context: ModelContext) {
        guard !questions.isEmpty else { return }
        isSubmitted = true
        let correctCount = questions.filter { question in
            normalized(answers[question.id] ?? "") == normalized(question.correctAnswer)
        }.count
        quiz.lastScore = Double(correctCount) / Double(questions.count)
        quiz.attemptCount += 1
        quiz.updatedAt = .now
        try? context.save()
        Haptics.success()
    }

    func reset() {
        answers.removeAll()
        isSubmitted = false
        Haptics.light()
    }

    func scoreText(for questions: [QuizQuestion]) -> String {
        guard isSubmitted, !questions.isEmpty else { return "" }
        let correctCount = questions.filter { normalized(answers[$0.id] ?? "") == normalized($0.correctAnswer) }.count
        return "\(correctCount) / \(questions.count)"
    }

    func isCorrect(_ question: QuizQuestion) -> Bool {
        normalized(answers[question.id] ?? "") == normalized(question.correctAnswer)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
