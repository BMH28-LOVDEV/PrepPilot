import Foundation

extension HTTPStudyAIService {
    // Label-variant stubs to satisfy protocol differences, forwarding to canonical implementations.

    // Some protocols might use `transcript:` instead of `from transcript:`
    func generateNotes(transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        try await generateNotes(from: transcript, lectureTitle: lectureTitle)
    }

    func generateFlashcards(transcript: String, notes: GeneratedNotes) async throws -> [GeneratedFlashcard] {
        try await generateFlashcards(from: transcript, notes: notes)
    }

    func generateQuiz(transcript: String, notes: GeneratedNotes) async throws -> GeneratedQuiz {
        try await generateQuiz(from: transcript, notes: notes)
    }

    func generateStudyGuide(transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        try await generateStudyGuide(from: transcript, notes: notes)
    }

    // Some protocols might use an unlabeled first parameter for `answer`
    func answer(_ question: String, noteContext: String) async throws -> AIAnswer {
        try await answer(question: question, noteContext: noteContext)
    }

    // Some protocols might use `context` instead of `noteContext`
    func answer(question: String, context: String) async throws -> AIAnswer {
        try await answer(question: question, noteContext: context)
    }
}
