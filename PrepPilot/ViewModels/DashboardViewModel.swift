import Foundation
import Observation

struct DashboardStats {
    let lectureCount: Int
    let dueTaskCount: Int
    let studiedCards: Int
    let averageQuizScore: Double
}

@Observable
final class DashboardViewModel {
    func stats(lectures: [Lecture], tasks: [StudyTask], flashcards: [Flashcard], quizzes: [Quiz]) -> DashboardStats {
        let dueTasks = tasks.filter { !$0.isComplete && $0.dueDate <= .now.addingTimeInterval(172_800) }
        let studiedCards = flashcards.filter { $0.lastStudiedAt != nil || $0.mastery > 0 }.count
        let attemptedQuizzes = quizzes.filter { $0.attemptCount > 0 }
        let average = attemptedQuizzes.isEmpty ? 0 : attemptedQuizzes.map(\.lastScore).reduce(0, +) / Double(attemptedQuizzes.count)
        return DashboardStats(lectureCount: lectures.count, dueTaskCount: dueTasks.count, studiedCards: studiedCards, averageQuizScore: average)
    }
}
