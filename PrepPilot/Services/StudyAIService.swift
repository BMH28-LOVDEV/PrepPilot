import Foundation

struct GeneratedNotes {
    let title: String
    let detailedNotes: String
    let conciseSummary: String
    let keyTakeaways: String
    let vocabularyTerms: String
    let importantConcepts: String
}

struct GeneratedFlashcard {
    let front: String
    let back: String
}

struct GeneratedQuizQuestion {
    let kind: QuizQuestionKind
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
}

struct GeneratedQuiz {
    let title: String
    let questions: [GeneratedQuizQuestion]
}

struct GeneratedStudyGuide {
    let title: String
    let examReview: String
    let topicSummaries: String
    let importantConcepts: String
    let keyDefinitions: String
}

struct AIAnswer {
    let content: String
    let sources: [String]
}

protocol StudyAIProviding {
    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes
    func generateFlashcards(from transcript: String, notes: GeneratedNotes) async throws -> [GeneratedFlashcard]
    func generateQuiz(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedQuiz
    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide
    func answer(question: String, noteContext: String) async throws -> AIAnswer
}

struct MockStudyAIService: StudyAIProviding {
    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        await simulateLatency()
        let sentences = meaningfulSentences(from: transcript)
        let keywords = keywords(from: transcript)
        let title = lectureTitle.isEmpty ? "Lecture Notes" : "\(lectureTitle) Notes"
        let primary = sentences.prefix(5).joined(separator: " ")
        let takeaways = sentences.prefix(4).map { "- \($0)" }.joined(separator: "\n")
        let vocabulary = keywords.prefix(6).map { word in
            "\(word.capitalized): A key concept mentioned in the lecture context."
        }.joined(separator: "\n")
        let concepts = keywords.prefix(8).map(\.capitalized).joined(separator: ", ")

        return GeneratedNotes(
            title: title,
            detailedNotes: primary.isEmpty ? fallbackDetailedNotes : primary,
            conciseSummary: sentences.first.map(String.init) ?? "This lecture introduces the main ideas, definitions, and exam-relevant relationships from the recording.",
            keyTakeaways: takeaways.isEmpty ? "- Review the core definitions.\n- Connect each concept to an example.\n- Revisit unclear sections before the quiz." : takeaways,
            vocabularyTerms: vocabulary.isEmpty ? fallbackVocabulary : vocabulary,
            importantConcepts: concepts.isEmpty ? "Core definitions, examples, applications, and likely assessment prompts" : concepts
        )
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes) async throws -> [GeneratedFlashcard] {
        await simulateLatency()
        let concepts = keywords(from: notes.importantConcepts + " " + transcript).prefix(8)
        var cards = concepts.map { concept in
            GeneratedFlashcard(front: "Explain \(concept.capitalized).", back: "Use the lecture notes to define \(concept), explain why it matters, and connect it to an example.")
        }
        if cards.isEmpty {
            cards = [
                GeneratedFlashcard(front: "What is the central idea from this lecture?", back: notes.conciseSummary),
                GeneratedFlashcard(front: "Name two key takeaways.", back: notes.keyTakeaways)
            ]
        }
        return Array(cards.prefix(10))
    }

    func generateQuiz(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedQuiz {
        await simulateLatency()
        let concepts = Array(keywords(from: transcript + " " + notes.importantConcepts).prefix(4))
        let focus = concepts.first ?? "the lecture topic"
        let second = concepts.dropFirst().first ?? "supporting evidence"

        let questions = [
            GeneratedQuizQuestion(
                kind: .multipleChoice,
                prompt: "Which concept is most central to this lecture?",
                options: [focus.capitalized, "Unrelated dates", "Formatting rules", "Attendance policy"],
                correctAnswer: focus.capitalized,
                explanation: "The generated notes identify \(focus) as a recurring concept."
            ),
            GeneratedQuizQuestion(
                kind: .trueFalse,
                prompt: "The lecture connects \(focus) with \(second).",
                options: ["True", "False"],
                correctAnswer: "True",
                explanation: "The notes group these terms as related study concepts."
            ),
            GeneratedQuizQuestion(
                kind: .shortAnswer,
                prompt: "Summarize the lecture's main takeaway in one sentence.",
                correctAnswer: notes.conciseSummary,
                explanation: "Short answers are graded against the note summary and supporting details."
            )
        ]

        return GeneratedQuiz(title: "\(focus.capitalized) Quiz", questions: questions)
    }

    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        await simulateLatency()
        return GeneratedStudyGuide(
            title: "Exam Review Sheet",
            examReview: "Prioritize the summary, then test yourself on every key takeaway. Rebuild the explanation for each concept without looking at the transcript.",
            topicSummaries: notes.detailedNotes,
            importantConcepts: notes.importantConcepts,
            keyDefinitions: notes.vocabularyTerms
        )
    }

    func answer(question: String, noteContext: String) async throws -> AIAnswer {
        await simulateLatency()
        let evidence = matchingEvidence(for: question, in: noteContext)
        guard !noteContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AIAnswer(content: "I do not have enough note context to answer that yet.", sources: [])
        }

        if evidence.isEmpty {
            return AIAnswer(
                content: "I do not see a direct answer in these notes. Based only on the available context, review the summary and key takeaways before treating this as exam-ready.",
                sources: ["Lecture notes"]
            )
        }

        return AIAnswer(
            content: "Based on your notes: \(evidence.prefix(2).joined(separator: " "))",
            sources: evidence.prefix(2).map { String($0.prefix(90)) }
        )
    }

    private func simulateLatency() async {
        try? await Task.sleep(nanoseconds: 450_000_000)
    }

    private func meaningfulSentences(from transcript: String) -> [String] {
        transcript
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 24 }
    }

    private func keywords(from text: String) -> [String] {
        let stopWords: Set<String> = ["about", "after", "again", "also", "because", "before", "between", "could", "every", "first", "from", "have", "into", "lecture", "notes", "that", "their", "there", "these", "this", "through", "today", "under", "using", "what", "when", "where", "which", "while", "with"]
        let words = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 4 && !stopWords.contains($0) }

        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    private func matchingEvidence(for question: String, in context: String) -> [String] {
        let questionTerms = Set(keywords(from: question))
        let lines = context
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.filter { line in
            let lineTerms = Set(keywords(from: line))
            return !questionTerms.isDisjoint(with: lineTerms)
        }
    }

    private var fallbackDetailedNotes: String {
        "The transcript was short, so PrepPilot created a study scaffold. Add details from class, then regenerate flashcards and quizzes for more targeted practice."
    }

    private var fallbackVocabulary: String {
        "Concept: A major idea from the lecture.\nEvidence: Details that support an answer.\nApplication: A way the concept appears in practice."
    }
}
