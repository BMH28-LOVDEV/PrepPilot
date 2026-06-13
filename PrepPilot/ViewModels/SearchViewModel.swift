import Foundation
import Observation

struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbolName: String
    let route: AppRoute
}

@Observable
final class SearchViewModel {
    var query = ""

    func results(
        lectures: [Lecture],
        notes: [LectureNote],
        flashcards: [Flashcard],
        quizzes: [Quiz],
        guides: [StudyGuide]
    ) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let term = trimmed.lowercased()

        var output: [SearchResult] = []
        output += lectures.compactMap { lecture in
            matches(term, in: lecture.title, lecture.course, lecture.transcript) ? SearchResult(title: lecture.title, subtitle: lecture.course.isEmpty ? "Lecture" : lecture.course, symbolName: "waveform", route: .lecture(lecture.id)) : nil
        }
        output += notes.compactMap { note in
            matches(term, in: note.title, note.detailedNotes, note.conciseSummary, note.keyTakeaways, note.vocabularyTerms) ? SearchResult(title: note.title, subtitle: "Notes", symbolName: "doc.text", route: .notes(note.lectureID)) : nil
        }
        output += flashcards.compactMap { card in
            matches(term, in: card.front, card.back) ? SearchResult(title: card.front, subtitle: "Flashcard", symbolName: "rectangle.on.rectangle", route: .flashcards(card.lectureID)) : nil
        }
        output += quizzes.compactMap { quiz in
            matches(term, in: quiz.title) ? SearchResult(title: quiz.title, subtitle: "Quiz", symbolName: "checklist", route: .quiz(quiz.lectureID)) : nil
        }
        output += guides.compactMap { guide in
            matches(term, in: guide.title, guide.examReview, guide.topicSummaries, guide.importantConcepts, guide.keyDefinitions) ? SearchResult(title: guide.title, subtitle: "Study guide", symbolName: "book.closed", route: .studyGuide(guide.lectureID)) : nil
        }

        return Array(output.prefix(40))
    }

    private func matches(_ term: String, in values: String...) -> Bool {
        values.contains { $0.lowercased().contains(term) }
    }
}
