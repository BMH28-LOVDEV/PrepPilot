import Foundation

struct BackendStudyAIService: StudyAIProviding {
    private let baseURL: URL
    private let clientKey: String
    private let session: URLSession

    init(baseURL: URL, clientKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.clientKey = clientKey
        self.session = session
    }

    // MARK: - StudyAIProviding

    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        struct Req: Encodable { let transcript: String; let lectureTitle: String }
        struct Res: Decodable {
            let title: String
            let detailedNotes: String
            let conciseSummary: String
            let keyTakeaways: String
            let vocabularyTerms: String
            let importantConcepts: String
        }
        let res: Res = try await post("/notes", body: Req(transcript: transcript, lectureTitle: lectureTitle))
        return GeneratedNotes(
            title: res.title,
            detailedNotes: res.detailedNotes,
            conciseSummary: res.conciseSummary,
            keyTakeaways: res.keyTakeaways,
            vocabularyTerms: res.vocabularyTerms,
            importantConcepts: res.importantConcepts
        )
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes) async throws -> [GeneratedFlashcard] {
        struct Req: Encodable { let transcript: String; let notes: GeneratedNotes }
        struct Card: Decodable { let front: String; let back: String }
        let cards: [Card] = try await post("/flashcards", body: Req(transcript: transcript, notes: notes))
        return cards.map { GeneratedFlashcard(front: $0.front, back: $0.back) }
    }

    func generateQuiz(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedQuiz {
        struct Req: Encodable { let transcript: String; let notes: GeneratedNotes }
        struct Question: Decodable {
            let kind: String
            let prompt: String
            let options: [String]?
            let correctAnswer: String
            let explanation: String
        }
        struct Res: Decodable { let title: String; let questions: [Question] }
        let res: Res = try await post("/quiz", body: Req(transcript: transcript, notes: notes))
        let questions: [GeneratedQuizQuestion] = res.questions.map { q in
            let kind: QuizQuestionKind
            switch q.kind.lowercased() {
            case "multiplechoice": kind = .multipleChoice
            case "truefalse": kind = .trueFalse
            default: kind = .shortAnswer
            }
            return GeneratedQuizQuestion(
                kind: kind,
                prompt: q.prompt,
                options: q.options ?? [],
                correctAnswer: q.correctAnswer,
                explanation: q.explanation
            )
        }
        return GeneratedQuiz(title: res.title, questions: questions)
    }

    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        struct Req: Encodable { let transcript: String; let notes: GeneratedNotes }
        struct Res: Decodable {
            let title: String
            let examReview: String
            let topicSummaries: String
            let importantConcepts: String
            let keyDefinitions: String
        }
        let res: Res = try await post("/study-guide", body: Req(transcript: transcript, notes: notes))
        return GeneratedStudyGuide(
            title: res.title,
            examReview: res.examReview,
            topicSummaries: res.topicSummaries,
            importantConcepts: res.importantConcepts,
            keyDefinitions: res.keyDefinitions
        )
    }

    func answer(question: String, noteContext: String) async throws -> AIAnswer {
        struct Req: Encodable { let question: String; let noteContext: String }
        struct Res: Decodable { let content: String; let sources: [String] }
        let res: Res = try await post("/answer", body: Req(question: question, noteContext: noteContext))
        return AIAnswer(content: res.content, sources: res.sources)
    }

    // MARK: - Networking

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(clientKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "BackendStudyAIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
