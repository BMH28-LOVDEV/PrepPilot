import AuthenticationServices
import AVFAudio
import AVFoundation
import CloudKit
import Foundation
import Observation
import PhotosUI
import Speech
import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import Vision
import UserNotifications

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Domain Models

enum LectureStatus: String, Codable, CaseIterable {
    case recording
    case transcribing
    case generating
    case ready
    case archived
}

enum QuizQuestionKind: String, Codable, CaseIterable, Identifiable {
    case multipleChoice
    case trueFalse
    case matching
    case shortAnswer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .multipleChoice: return "Multiple choice"
        case .trueFalse: return "True or false"
        case .matching: return "Matching"
        case .shortAnswer: return "Written answer"
        }
    }
}

enum StudyTaskKind: String, Codable, CaseIterable {
    case review
    case flashcards
    case quiz
    case notes
}

enum ChatRole: String, Codable, CaseIterable {
    case user
    case assistant
}

enum SubscriptionPlan: String, Codable, CaseIterable {
    case free
    case monthly
    case yearly
}

enum CourseIconKind: String, Codable, CaseIterable, Identifiable {
    case symbol
    case emoji
    case photo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .symbol: return "Default"
        case .emoji: return "Emoji"
        case .photo: return "Photo"
        }
    }
}

struct CourseClass: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var instructor: String
    var term: String
    var accentName: String
    var createdAt: Date
    var iconKindRaw: String?
    var iconValue: String?

    var displayTitle: String {
        name
    }

    var iconKind: CourseIconKind {
        get { CourseIconKind(rawValue: iconKindRaw ?? "") ?? .symbol }
        set { iconKindRaw = newValue == .symbol ? nil : newValue.rawValue }
    }

    init(id: UUID = UUID(), name: String, instructor: String = "", term: String = "", accentName: String = "indigo", createdAt: Date = .now, iconKindRaw: String? = nil, iconValue: String? = nil) {
        self.id = id
        self.name = name
        self.instructor = instructor
        self.term = term
        self.accentName = accentName
        self.createdAt = createdAt
        self.iconKindRaw = iconKindRaw
        self.iconValue = iconValue
    }
}

enum CourseCatalogStorage {
    static func decode(_ value: String) -> [CourseClass] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([CourseClass].self, from: data)) ?? []
    }

    static func encode(_ courses: [CourseClass]) -> String {
        guard let data = try? JSONEncoder().encode(courses) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    static func course(matching courseName: String, in courses: [CourseClass]) -> CourseClass? {
        let normalizedName = normalized(courseName)
        guard !normalizedName.isEmpty else { return nil }
        return courses.first { course in
            let candidate = normalized(course.name)
            return candidate == normalizedName || candidate.contains(normalizedName) || normalizedName.contains(candidate)
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum PinnedLectureStorage {
    static func decode(_ value: String) -> Set<UUID> {
        let ids = value.split(separator: "\n").compactMap { UUID(uuidString: String($0)) }
        return Set(ids)
    }

    static func encode(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: "\n")
    }

    static func toggled(_ lectureID: UUID, in value: String) -> String {
        var ids = decode(value)
        if ids.contains(lectureID) {
            ids.remove(lectureID)
        } else {
            ids.insert(lectureID)
        }
        return encode(ids)
    }
}

@Model
final class Lecture {
    var id: UUID = UUID()
    var title: String = ""
    var course: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var duration: TimeInterval = 0
    var audioFileName: String = ""
    var transcript: String = ""
    var statusRaw: String = LectureStatus.ready.rawValue
    var isFavorite: Bool = false
    var accentName: String = "indigo"

    var status: LectureStatus {
        get { LectureStatus(rawValue: statusRaw) ?? .ready }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        course: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        audioFileName: String = "",
        transcript: String = "",
        status: LectureStatus = .ready,
        isFavorite: Bool = false,
        accentName: String = "indigo"
    ) {
        self.id = id
        self.title = title
        self.course = course
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.transcript = transcript
        self.statusRaw = status.rawValue
        self.isFavorite = isFavorite
        self.accentName = accentName
    }
}

@Model
final class LectureNote {
    var id: UUID = UUID()
    var lectureID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = ""
    var detailedNotes: String = ""
    var conciseSummary: String = ""
    var keyTakeaways: String = ""
    var vocabularyTerms: String = ""
    var importantConcepts: String = ""

    init(
        id: UUID = UUID(),
        lectureID: UUID,
        title: String,
        detailedNotes: String,
        conciseSummary: String,
        keyTakeaways: String,
        vocabularyTerms: String,
        importantConcepts: String
    ) {
        self.id = id
        self.lectureID = lectureID
        self.title = title
        self.detailedNotes = detailedNotes
        self.conciseSummary = conciseSummary
        self.keyTakeaways = keyTakeaways
        self.vocabularyTerms = vocabularyTerms
        self.importantConcepts = importantConcepts
    }
}

@Model
final class Flashcard {
    var id: UUID = UUID()
    var lectureID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var front: String = ""
    var back: String = ""
    var mastery: Int = 0
    var lastStudiedAt: Date?

    init(id: UUID = UUID(), lectureID: UUID, front: String, back: String, mastery: Int = 0, lastStudiedAt: Date? = nil) {
        self.id = id
        self.lectureID = lectureID
        self.front = front
        self.back = back
        self.mastery = mastery
        self.lastStudiedAt = lastStudiedAt
    }
}

@Model
final class Quiz {
    var id: UUID = UUID()
    var lectureID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = ""
    var lastScore: Double = 0
    var attemptCount: Int = 0

    init(id: UUID = UUID(), lectureID: UUID, title: String, lastScore: Double = 0, attemptCount: Int = 0) {
        self.id = id
        self.lectureID = lectureID
        self.title = title
        self.lastScore = lastScore
        self.attemptCount = attemptCount
    }
}

@Model
final class QuizQuestion {
    var id: UUID = UUID()
    var quizID: UUID = UUID()
    var createdAt: Date = Date()
    var kindRaw: String = QuizQuestionKind.multipleChoice.rawValue
    var prompt: String = ""
    var optionsData: String = ""
    var correctAnswer: String = ""
    var explanation: String = ""

    var kind: QuizQuestionKind {
        get { QuizQuestionKind(rawValue: kindRaw) ?? .multipleChoice }
        set { kindRaw = newValue.rawValue }
    }

    var options: [String] {
        get { optionsData.split(separator: "\n").map(String.init) }
        set { optionsData = newValue.joined(separator: "\n") }
    }

    init(
        id: UUID = UUID(),
        quizID: UUID,
        kind: QuizQuestionKind,
        prompt: String,
        options: [String] = [],
        correctAnswer: String,
        explanation: String
    ) {
        self.id = id
        self.quizID = quizID
        self.kindRaw = kind.rawValue
        self.prompt = prompt
        self.optionsData = options.joined(separator: "\n")
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
}

@Model
final class StudyGuide {
    var id: UUID = UUID()
    var lectureID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = ""
    var examReview: String = ""
    var topicSummaries: String = ""
    var importantConcepts: String = ""
    var keyDefinitions: String = ""

    init(
        id: UUID = UUID(),
        lectureID: UUID,
        title: String,
        examReview: String,
        topicSummaries: String,
        importantConcepts: String,
        keyDefinitions: String
    ) {
        self.id = id
        self.lectureID = lectureID
        self.title = title
        self.examReview = examReview
        self.topicSummaries = topicSummaries
        self.importantConcepts = importantConcepts
        self.keyDefinitions = keyDefinitions
    }
}

@Model
final class StudyTask {
    var id: UUID = UUID()
    var lectureID: UUID?
    var createdAt: Date = Date()
    var dueDate: Date = Date()
    var title: String = ""
    var subtitle: String = ""
    var kindRaw: String = StudyTaskKind.review.rawValue
    var isComplete: Bool = false

    var kind: StudyTaskKind {
        get { StudyTaskKind(rawValue: kindRaw) ?? .review }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), lectureID: UUID? = nil, dueDate: Date, title: String, subtitle: String, kind: StudyTaskKind, isComplete: Bool = false) {
        self.id = id
        self.lectureID = lectureID
        self.dueDate = dueDate
        self.title = title
        self.subtitle = subtitle
        self.kindRaw = kind.rawValue
        self.isComplete = isComplete
    }
}

@Model
final class AIChatMessage {
    var id: UUID = UUID()
    var lectureID: UUID = UUID()
    var roleRaw: String = ChatRole.user.rawValue
    var content: String = ""
    var sourcesData: String = ""
    var createdAt: Date = Date()

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    var sources: [String] {
        get { sourcesData.split(separator: "\n").map(String.init) }
        set { sourcesData = newValue.joined(separator: "\n") }
    }

    init(id: UUID = UUID(), lectureID: UUID, role: ChatRole, content: String, sources: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.lectureID = lectureID
        self.roleRaw = role.rawValue
        self.content = content
        self.sourcesData = sources.joined(separator: "\n")
        self.createdAt = createdAt
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var displayName: String = "Student"
    var email: String = ""
    var appleUserIdentifier: String = ""
    var createdAt: Date = Date()
    var lastSeenAt: Date = Date()
    var planRaw: String = SubscriptionPlan.free.rawValue

    var plan: SubscriptionPlan {
        get { SubscriptionPlan(rawValue: planRaw) ?? .free }
        set { planRaw = newValue.rawValue }
    }

    init(displayName: String = "Student", email: String = "", appleUserIdentifier: String = "", plan: SubscriptionPlan = .free) {
        self.displayName = displayName
        self.email = email
        self.appleUserIdentifier = appleUserIdentifier
        self.planRaw = plan.rawValue
    }
}

enum PrepPilotSchema {
    static let models: [any PersistentModel.Type] = [
        Lecture.self,
        LectureNote.self,
        Flashcard.self,
        Quiz.self,
        QuizQuestion.self,
        StudyGuide.self,
        StudyTask.self,
        AIChatMessage.self,
        UserProfile.self
    ]
}

// MARK: - Services

enum GradingStrictness: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var shortAnswerThreshold: Double {
        switch self {
        case .easy: return 0.35
        case .medium: return 0.55
        case .hard: return 0.72
        }
    }
}

struct StudyGenerationPreferences: Codable {
    var flashcardCount: Int = 12
    var quizQuestionCount: Int = 8
    var quizKinds: [QuizQuestionKind] = QuizQuestionKind.allCases
}

#if canImport(ActivityKit)
struct PrepPilotRecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isPaused: Bool
        var audioLevel: Double
        var waveformLevels: [Double]
        var statusText: String
    }

    var lectureTitle: String
    var courseName: String
}

@MainActor
final class RecordingLiveActivityController {
    private var activity: Activity<PrepPilotRecordingActivityAttributes>?

    func start(lectureTitle: String, courseName: String) async {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PrepPilotRecordingActivityAttributes(
            lectureTitle: lectureTitle,
            courseName: courseName.isEmpty ? "Lecture recording" : courseName
        )
        let state = PrepPilotRecordingActivityAttributes.ContentState(
            elapsedSeconds: 0,
            isPaused: false,
            audioLevel: 0.08,
            waveformLevels: Array(repeating: 0.08, count: 24),
            statusText: "Recording"
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60),
            relevanceScore: 100
        )

        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
        }
    }

    func update(elapsedSeconds: Int, isPaused: Bool, audioLevel: Double, waveformLevels: [Double], statusText: String) async {
        guard #available(iOS 16.2, *), let activity else { return }
        let state = PrepPilotRecordingActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused,
            audioLevel: audioLevel,
            waveformLevels: waveformLevels,
            statusText: statusText
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(15 * 60),
            relevanceScore: 100
        )
        await activity.update(content)
    }

    func end(elapsedSeconds: Int, statusText: String) async {
        guard #available(iOS 16.2, *), let activity else { return }
        let state = PrepPilotRecordingActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            isPaused: false,
            audioLevel: 0.08,
            waveformLevels: Array(repeating: 0.08, count: 24),
            statusText: statusText
        )
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(8)))
        self.activity = nil
    }
}
#endif

struct GeneratedNotes: Codable {
    let title: String
    let detailedNotes: String
    let conciseSummary: String
    let keyTakeaways: String
    let vocabularyTerms: String
    let importantConcepts: String
}

struct GeneratedFlashcard: Codable {
    let front: String
    let back: String
}

struct GeneratedQuizQuestion: Codable {
    let kind: QuizQuestionKind
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let explanation: String
}

struct GeneratedQuiz: Codable {
    let title: String
    let questions: [GeneratedQuizQuestion]
}

struct GeneratedStudyGuide: Codable {
    let title: String
    let examReview: String
    let topicSummaries: String
    let importantConcepts: String
    let keyDefinitions: String
}

#if canImport(UIKit)
struct NoteImageAttachment: Identifiable {
    let id = UUID()
    let image: UIImage
    var recognizedText: String = ""
    var isProcessing = true
}

enum ImageTextExtractor {
    static func recognizedText(from image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
#endif

struct AIAnswer: Codable {
    let content: String
    let sources: [String]
}

protocol StudyAIProviding {
    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes
    func generateFlashcards(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> [GeneratedFlashcard]
    func generateQuiz(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> GeneratedQuiz
    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide
    func answer(question: String, noteContext: String) async throws -> AIAnswer
}

struct BackendStudyAIService: StudyAIProviding {
    private let baseURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    init(baseURL: URL = URL(string: "https://preppilot-official-dockersetup.onrender.com/api")!) {
        self.baseURL = baseURL
        #if DEBUG
        print("[BackendStudyAIService] Using base URL:", baseURL.absoluteString)
        #endif
    }

    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        try await post("generate-notes", body: NotesRequest(transcript: transcript, lectureTitle: lectureTitle))
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> [GeneratedFlashcard] {
        try await post("generate-flashcards", body: MaterialRequest(transcript: transcript, notes: notes, preferences: preferences))
    }

    func generateQuiz(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> GeneratedQuiz {
        try await post("generate-quiz", body: MaterialRequest(transcript: transcript, notes: notes, preferences: preferences))
    }

    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        try await post("generate-study-guide", body: MaterialRequest(transcript: transcript, notes: notes, preferences: StudyGenerationPreferences()))
    }

    func answer(question: String, noteContext: String) async throws -> AIAnswer {
        try await post("answer", body: ChatRequest(question: question, noteContext: noteContext))
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(_ endpoint: String, body: RequestBody) async throws -> ResponseBody {
        var request = URLRequest(url: baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(Secrets.clientAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.clientAPIKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try encoder.encode(body)

        #if DEBUG
        print("[BackendStudyAIService] POST", request.url?.absoluteString ?? endpoint)
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "PrepPilot.BackendAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend returned an invalid response."])
        }

        #if DEBUG
        print("[BackendStudyAIService] Status:", httpResponse.statusCode)
        #endif

        guard (200..<300).contains(httpResponse.statusCode) else {
            let error = try? decoder.decode(BackendErrorResponse.self, from: data)
            throw NSError(domain: "PrepPilot.BackendAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: error?.error ?? "Backend request failed."])
        }

        return try decoder.decode(ResponseBody.self, from: data)
    }

    private struct NotesRequest: Encodable {
        let transcript: String
        let lectureTitle: String
    }

    private struct MaterialRequest: Encodable {
        let transcript: String
        let notes: GeneratedNotes
        let preferences: StudyGenerationPreferences
    }

    private struct ChatRequest: Encodable {
        let question: String
        let noteContext: String
    }

    private struct BackendErrorResponse: Decodable {
        let error: String
    }
}

struct MockStudyAIService: StudyAIProviding {
    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        await simulateLatency()
        let sentences = meaningfulSentences(from: transcript)
        let terms = keywords(from: transcript)
        let title = lectureTitle.isEmpty ? "Lecture Notes" : "\(lectureTitle) Notes"
        let detailed = sentences.prefix(5).joined(separator: " ")
        let takeaways = sentences.prefix(4).map { "- \($0)" }.joined(separator: "\n")
        let vocabulary = terms.prefix(6).map { "\($0.capitalized): A key concept mentioned in the lecture context." }.joined(separator: "\n")
        let concepts = terms.prefix(8).map(\.capitalized).joined(separator: ", ")

        return GeneratedNotes(
            title: title,
            detailedNotes: detailed.isEmpty ? "Add more transcript detail to improve generated notes. PrepPilot created a starter study scaffold for this recording." : detailed,
            conciseSummary: sentences.first ?? "This lecture introduces the main ideas, definitions, and exam-relevant relationships from the recording.",
            keyTakeaways: takeaways.isEmpty ? "- Review the core definitions.\n- Connect each concept to an example.\n- Revisit unclear sections before the quiz." : takeaways,
            vocabularyTerms: vocabulary.isEmpty ? "Concept: A major idea from the lecture.\nEvidence: Details that support an answer.\nApplication: A way the concept appears in practice." : vocabulary,
            importantConcepts: concepts.isEmpty ? "Core definitions, examples, applications, and likely assessment prompts" : concepts
        )
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> [GeneratedFlashcard] {
        await simulateLatency()
        let concepts = keywords(from: notes.importantConcepts + " " + transcript).prefix(8)
        let cards = concepts.map { concept in
            GeneratedFlashcard(front: "Explain \(concept.capitalized).", back: "Define \(concept), explain why it matters, and connect it to a lecture example.")
        }
        return cards.isEmpty ? [GeneratedFlashcard(front: "What is the central idea?", back: notes.conciseSummary)] : Array(cards.prefix(preferences.flashcardCount))
    }

    func generateQuiz(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> GeneratedQuiz {
        await simulateLatency()
        let concepts = Array(keywords(from: transcript + " " + notes.importantConcepts).prefix(4))
        let focus = concepts.first ?? "the lecture topic"
        let second = concepts.dropFirst().first ?? "supporting evidence"
        let availableQuestions = [
            GeneratedQuizQuestion(kind: .multipleChoice, prompt: "Which concept is most central to this lecture?", options: [focus.capitalized, "Unrelated dates", "Formatting rules", "Attendance policy"], correctAnswer: focus.capitalized, explanation: "The notes identify \(focus) as a recurring concept."),
            GeneratedQuizQuestion(kind: .trueFalse, prompt: "The lecture connects \(focus) with \(second).", options: ["True", "False"], correctAnswer: "True", explanation: "The generated notes group these terms as related study concepts."),
            GeneratedQuizQuestion(kind: .matching, prompt: "Which term best matches this definition: a key concept repeatedly used in the lecture?", options: [focus.capitalized, second.capitalized, "Unrelated policy", "Formatting"], correctAnswer: focus.capitalized, explanation: "Matching questions pair definitions with lecture terms."),
            GeneratedQuizQuestion(kind: .shortAnswer, prompt: "Summarize the main takeaway in one sentence.", options: [], correctAnswer: notes.conciseSummary, explanation: "Written answers are graded by similarity to the answer key, not exact wording.")
        ]
        let requestedKinds = Set(preferences.quizKinds)
        let questions = availableQuestions.filter { requestedKinds.contains($0.kind) }
        return GeneratedQuiz(title: "\(focus.capitalized) Quiz", questions: Array((questions.isEmpty ? availableQuestions : questions).prefix(preferences.quizQuestionCount)))
    }

    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        await simulateLatency()
        return GeneratedStudyGuide(title: "Exam Review Sheet", examReview: "Prioritize the summary, then test yourself on every key takeaway. Rebuild each explanation without looking at the transcript.", topicSummaries: notes.detailedNotes, importantConcepts: notes.importantConcepts, keyDefinitions: notes.vocabularyTerms)
    }

    func answer(question: String, noteContext: String) async throws -> AIAnswer {
        await simulateLatency()
        guard !noteContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return AIAnswer(content: "I do not have enough note context to answer that yet.", sources: [])
        }
        let evidence = matchingEvidence(for: question, in: noteContext)
        if evidence.isEmpty {
            return AIAnswer(content: "I do not see a direct answer in these notes. Based only on the available context, review the summary and key takeaways before treating this as exam-ready.", sources: ["Lecture notes"])
        }
        return AIAnswer(content: "Based on your notes: \(evidence.prefix(2).joined(separator: " "))", sources: evidence.prefix(2).map { String($0.prefix(90)) })
    }

    private func simulateLatency() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    private func meaningfulSentences(from text: String) -> [String] {
        text.replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 24 }
    }

    private func keywords(from text: String) -> [String] {
        let stopWords: Set<String> = ["about", "after", "again", "also", "because", "before", "between", "could", "every", "first", "from", "have", "into", "lecture", "notes", "that", "their", "there", "these", "this", "through", "today", "under", "using", "what", "when", "where", "which", "while", "with"]
        let words = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 4 && !stopWords.contains($0) }
        var seen = Set<String>()
        return words.filter { seen.insert($0).inserted }
    }

    private func matchingEvidence(for question: String, in context: String) -> [String] {
        let questionTerms = Set(keywords(from: question))
        return context.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !questionTerms.isDisjoint(with: Set(keywords(from: $0))) }
    }
}

@MainActor
protocol SpeechTranscribing {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
    func transcribeAudio(at url: URL) async throws -> String
}

@MainActor
final class SpeechTranscriptionService: SpeechTranscribing {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        guard Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil else {
            return .denied
        }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribeAudio(at url: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw NSError(domain: "PrepPilot.Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission was not granted."])
        }
        guard let recognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent), recognizer.isAvailable else {
            throw NSError(domain: "PrepPilot.Speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is unavailable for the current locale."])
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        let box = SpeechContinuationBox()
        return try await withCheckedThrowingContinuation { continuation in
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    box.complete(continuation, result: .success(result.bestTranscription.formattedString))
                } else if let error {
                    box.complete(continuation, result: .failure(error))
                }
            }
            box.retain(task)
        }
    }
}

private final class SpeechContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private var task: SFSpeechRecognitionTask?

    func retain(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func complete(_ continuation: CheckedContinuation<String, Error>, result: Result<String, Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        task = nil
        lock.unlock()
        switch result {
        case .success(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continuation.resume(throwing: NSError(domain: "PrepPilot.Speech", code: 3, userInfo: [NSLocalizedDescriptionKey: "No transcript was produced for this recording."]))
            } else {
                continuation.resume(returning: trimmed)
            }
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

struct RecordingResult {
    let url: URL
    let duration: TimeInterval
}

@MainActor
@Observable
final class AudioRecorderService {
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTimer: Timer?
    @ObservationIgnored var meterUpdateHandler: (() -> Void)?

    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var duration: TimeInterval = 0
    private(set) var powerLevels: [CGFloat] = Array(repeating: 0.08, count: 44)
    private(set) var recordingURL: URL?

    func start() async throws {
        guard try await requestMicrophoneAccess() else {
            throw NSError(domain: "PrepPilot.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access is disabled. Enable it in Settings, then try recording again."])
        }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let directory = try recordingsDirectory()
        let url = directory.appendingPathComponent("lecture-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
        recordingURL = url
        duration = 0
        isRecording = true
        isPaused = false
        startMetering()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        isPaused = true
        Haptics.light()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        recorder?.record()
        isPaused = false
        Haptics.light()
    }

    func stop() throws -> RecordingResult {
        guard let recorder, let recordingURL else {
            throw NSError(domain: "PrepPilot.Audio", code: 2, userInfo: [NSLocalizedDescriptionKey: "The recorder is not available."])
        }
        let finalDuration = recorder.currentTime
        recorder.stop()
        meterTimer?.invalidate()
        meterTimer = nil
        self.recorder = nil
        isRecording = false
        isPaused = false
        duration = finalDuration
        powerLevels = Array(repeating: 0.08, count: 44)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Haptics.success()
        return RecordingResult(url: recordingURL, duration: finalDuration)
    }

    private func requestMicrophoneAccess() async throws -> Bool {
        guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else {
            throw NSError(domain: "PrepPilot.Audio", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing NSMicrophoneUsageDescription in the app target. Add a microphone privacy description in Target > Info before recording."])
        }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let recorderService = self else { return }
            Task { @MainActor in
                recorderService.refreshMeters()
            }
        }
    }

    private func refreshMeters() {
        guard let recorder else { return }
        recorder.updateMeters()
        duration = recorder.currentTime
        let power = recorder.averagePower(forChannel: 0)
        let normalized = max(0.06, min(1, CGFloat(pow(10, power / 35))))
        powerLevels.append(isPaused ? 0.06 : normalized)
        if powerLevels.count > 44 { powerLevels.removeFirst(powerLevels.count - 44) }
        meterUpdateHandler?()
    }

    private func recordingsDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
@Observable
final class CloudSyncService {
    private(set) var statusDescription = "iCloud not configured"
    private(set) var isAvailable = false

    func refresh() async {
        isAvailable = false
        statusDescription = "iCloud not configured"
    }
}

enum StudyNotificationScheduler {
    static func scheduleStudyReminders() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["review-flashcards", "retry-quiz", "weekly-plan", "upload-notes"])
        try await addReminder(id: "review-flashcards", title: "Flashcard review", body: "A short review session keeps your newest cards fresh.", hour: 18, weekday: nil)
        try await addReminder(id: "retry-quiz", title: "Quiz retry", body: "Retake a quiz and see whether your score improved.", hour: 19, weekday: nil)
        try await addReminder(id: "weekly-plan", title: "Plan your study week", body: "Pick the lectures and classes you want to review this week.", hour: 10, weekday: 1)
        try await addReminder(id: "upload-notes", title: "Add missing notes", body: "Upload class notes so PrepPilot can turn them into review materials.", hour: 16, weekday: 3)
    }

    private static func addReminder(id: String, title: String, body: String, hour: Int, weekday: Int?) async throws {
        var date = DateComponents()
        date.hour = hour
        date.minute = 0
        if let weekday {
            date.weekday = weekday
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "STUDY_REMINDER"

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
@Observable
final class SubscriptionStore {
    static let monthlyProductID = "com.preppilot.premium.monthly"
    static let yearlyProductID = "com.preppilot.premium.yearly"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID]

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isPremium = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in StoreKit.Transaction.updates {
                await self.handle(result)
            }
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: Self.productIDs)
            await refreshEntitlements()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = Set<String>()
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID) {
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
        isPremium = !active.isEmpty
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            await handle(verification)
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func displayPrice(for productID: String) -> String {
        products.first(where: { $0.id == productID })?.displayPrice ?? (productID == Self.yearlyProductID ? "$59.99 / year" : "$7.99 / month")
    }

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if Self.productIDs.contains(transaction.productID) {
            purchasedProductIDs.insert(transaction.productID)
            isPremium = true
        }
        await transaction.finish()
    }
}

@MainActor
@Observable
final class AppEnvironment {
    let aiService: StudyAIProviding
    let speechService: SpeechTranscribing
    let subscriptionStore: SubscriptionStore
    let cloudSyncService: CloudSyncService
    let recordingViewModel: RecordingViewModel

    init() {
        self.aiService = BackendStudyAIService()
        self.speechService = SpeechTranscriptionService()
        self.subscriptionStore = SubscriptionStore()
        self.cloudSyncService = CloudSyncService()
        self.recordingViewModel = RecordingViewModel(speechService: speechService, aiService: aiService)
    }

    init(aiService: StudyAIProviding, speechService: SpeechTranscribing, subscriptionStore: SubscriptionStore, cloudSyncService: CloudSyncService) {
        self.aiService = aiService
        self.speechService = speechService
        self.subscriptionStore = subscriptionStore
        self.cloudSyncService = cloudSyncService
        self.recordingViewModel = RecordingViewModel(speechService: speechService, aiService: aiService)
    }
}

// MARK: - View Models

enum AppTab: Hashable {
    case dashboard
    case recording
    case materials
    case profile
}

enum AppRoute: Hashable {
    case lecture(UUID)
    case recording
    case importNotes
    case coursesClasses
    case addCourseClass
    case transcript(UUID)
    case notes(UUID)
    case flashcards(UUID)
    case quiz(UUID)
    case studyGuide(UUID)
    case chat(UUID)
    case paywall
    case settings
}

enum MaterialSort: String, CaseIterable, Identifiable {
    case dateRecorded
    case course
    case contentAmount
    case title

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateRecorded: return "Date Recorded"
        case .course: return "Course"
        case .contentAmount: return "Amount of Content"
        case .title: return "Title"
        }
    }
}

@MainActor
@Observable
final class RecordingViewModel {
    enum Phase: Equatable {
        case idle
        case recording
        case paused
        case processing(String)
        case completed(UUID)
    }

    let recorder = AudioRecorderService()
    var phase: Phase = .idle
    var title = ""
    var course = ""
    var preferences = StudyGenerationPreferences()
    var errorMessage: String?
    var warningMessage: String?
    var generatedLectureID: UUID?
    var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechService: SpeechTranscribing
    private let aiService: StudyAIProviding
    @ObservationIgnored private var lastLiveActivityUpdate = Date.distantPast
    #if canImport(ActivityKit)
    private let liveActivityController = RecordingLiveActivityController()
    #endif

    init(speechService: SpeechTranscribing, aiService: StudyAIProviding) {
        self.speechService = speechService
        self.aiService = aiService
        recorder.meterUpdateHandler = { [weak self] in
            self?.refreshLiveActivity()
        }
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Lecture" : trimmed
    }

    func start() async {
        errorMessage = nil
        warningMessage = nil
        do {
            speechAuthorizationStatus = await speechService.requestAuthorization()
            try await recorder.start()
            phase = .recording
            #if canImport(ActivityKit)
            await liveActivityController.start(lectureTitle: displayTitle, courseName: course.trimmingCharacters(in: .whitespacesAndNewlines))
            #endif
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
        }
    }

    func pauseOrResume() {
        switch phase {
        case .recording:
            recorder.pause()
            phase = .paused
            refreshLiveActivity(force: true)
        case .paused:
            recorder.resume()
            phase = .recording
            refreshLiveActivity(force: true)
        default:
            break
        }
    }

    func pauseForNavigationAway() {
        guard phase == .recording else { return }
        recorder.pause()
        phase = .paused
        warningMessage = "Recording paused. Return to this screen to resume or finish the saved session."
        refreshLiveActivity(force: true)
        Haptics.light()
    }

    func refreshLiveActivity(force: Bool = false) {
        #if canImport(ActivityKit)
        let now = Date()
        guard force || now.timeIntervalSince(lastLiveActivityUpdate) >= 0.5 else { return }
        lastLiveActivityUpdate = now

        let status = phase == .paused ? "Paused" : "Recording"
        let waveformLevels = Array(recorder.powerLevels.suffix(24)).map { Double($0) }
        let level = waveformLevels.last ?? 0.08
        let elapsedSeconds = max(0, Int(recorder.duration.rounded()))
        Task { @MainActor in
            await liveActivityController.update(
                elapsedSeconds: elapsedSeconds,
                isPaused: phase == .paused,
                audioLevel: level,
                waveformLevels: waveformLevels,
                statusText: status
            )
        }
        #endif
    }

    func stopAndSave(in context: ModelContext) async -> UUID? {
        guard phase == .recording || phase == .paused else { return nil }
        errorMessage = nil
        warningMessage = nil
        do {
            let result = try recorder.stop()
            #if canImport(ActivityKit)
            await liveActivityController.end(elapsedSeconds: max(0, Int(result.duration.rounded())), statusText: "Saved")
            #endif
            phase = .processing("Transcribing lecture")
            let transcript = await transcriptText(for: result.url)
            let lecture = Lecture(title: displayTitle, course: course.trimmingCharacters(in: .whitespacesAndNewlines), duration: result.duration, audioFileName: result.url.lastPathComponent, transcript: transcript, status: .generating, accentName: ["indigo", "teal", "coral", "amber", "blue"].randomElement() ?? "indigo")
            context.insert(lecture)
            try context.save()

            if let transcriptWarning = transcriptQualityWarning(for: transcript) {
                lecture.status = .ready
                lecture.updatedAt = .now
                try context.save()
                generatedLectureID = lecture.id
                warningMessage = transcriptWarning
                phase = .completed(lecture.id)
                Haptics.warning()
                return nil
            }

            phase = .processing("Generating notes")
            let notes = try await aiService.generateNotes(from: transcript, lectureTitle: lecture.title)
            context.insert(LectureNote(lectureID: lecture.id, title: notes.title, detailedNotes: notes.detailedNotes, conciseSummary: notes.conciseSummary, keyTakeaways: notes.keyTakeaways, vocabularyTerms: notes.vocabularyTerms, importantConcepts: notes.importantConcepts))

            phase = .processing("Building flashcards")
            for card in try await aiService.generateFlashcards(from: transcript, notes: notes, preferences: preferences) {
                context.insert(Flashcard(lectureID: lecture.id, front: card.front, back: card.back))
            }

            phase = .processing("Creating quiz")
            let generatedQuiz = try await aiService.generateQuiz(from: transcript, notes: notes, preferences: preferences)
            let quiz = Quiz(lectureID: lecture.id, title: generatedQuiz.title)
            context.insert(quiz)
            for question in generatedQuiz.questions {
                context.insert(QuizQuestion(quizID: quiz.id, kind: question.kind, prompt: question.prompt, options: question.options, correctAnswer: question.correctAnswer, explanation: question.explanation))
            }

            phase = .processing("Preparing study guide")
            let guide = try await aiService.generateStudyGuide(from: transcript, notes: notes)
            context.insert(StudyGuide(lectureID: lecture.id, title: guide.title, examReview: guide.examReview, topicSummaries: guide.topicSummaries, importantConcepts: guide.importantConcepts, keyDefinitions: guide.keyDefinitions))
            context.insert(StudyTask(lectureID: lecture.id, dueDate: .now.addingTimeInterval(86_400), title: "Review \(lecture.title)", subtitle: lecture.course.isEmpty ? "New lecture" : lecture.course, kind: .flashcards))

            lecture.status = .ready
            lecture.updatedAt = .now
            try context.save()
            generatedLectureID = lecture.id
            phase = .completed(lecture.id)
            return lecture.id
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
            return nil
        }
    }

    private func transcriptText(for url: URL) async -> String {
        guard speechAuthorizationStatus == .authorized else {
            return "Speech recognition was not authorized. Add or paste a transcript to generate more accurate study materials."
        }
        do {
            return try await speechService.transcribeAudio(at: url)
        } catch {
            return "Transcript unavailable: \(error.localizedDescription). Add the transcript manually, then regenerate study materials."
        }
    }

    private func transcriptQualityWarning(for transcript: String) -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let words = trimmed
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)

        if lowered.hasPrefix("speech recognition was not authorized") {
            return "Recording saved, but speech recognition was not authorized. Add the transcript or upload notes before generating AI materials."
        }

        if lowered.hasPrefix("transcript unavailable") {
            return "Recording saved, but PrepPilot could not build a usable transcript from this audio. Try recording again closer to the speaker or upload notes for this class."
        }

        if words.count < 12 || Set(words.map { $0.lowercased() }).count < 6 {
            return "Recording saved, but the transcript is too short for reliable AI study materials. Try recording again or upload notes for this lecture."
        }

        return nil
    }
}

@MainActor
@Observable
final class NoteImportViewModel {
    var title = ""
    var course = ""
    var notesText = ""
    var preferences = StudyGenerationPreferences()
    var isImporting = false
    var errorMessage: String?

    var canImport: Bool {
        !notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isImporting
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Uploaded Notes" : trimmed
    }

    func importNotes(in context: ModelContext, aiService: StudyAIProviding) async -> UUID? {
        let transcript = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            errorMessage = "Paste notes or import a text file before creating materials."
            return nil
        }

        errorMessage = nil
        isImporting = true
        defer { isImporting = false }

        do {
            let lecture = Lecture(
                title: displayTitle,
                course: course.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: 0,
                audioFileName: "",
                transcript: transcript,
                status: .generating,
                accentName: ["indigo", "teal", "coral", "amber", "blue"].randomElement() ?? "indigo"
            )
            context.insert(lecture)
            try context.save()

            let notes = try await aiService.generateNotes(from: transcript, lectureTitle: lecture.title)
            context.insert(LectureNote(lectureID: lecture.id, title: notes.title, detailedNotes: notes.detailedNotes, conciseSummary: notes.conciseSummary, keyTakeaways: notes.keyTakeaways, vocabularyTerms: notes.vocabularyTerms, importantConcepts: notes.importantConcepts))

            for card in try await aiService.generateFlashcards(from: transcript, notes: notes, preferences: preferences) {
                context.insert(Flashcard(lectureID: lecture.id, front: card.front, back: card.back))
            }

            let generatedQuiz = try await aiService.generateQuiz(from: transcript, notes: notes, preferences: preferences)
            let quiz = Quiz(lectureID: lecture.id, title: generatedQuiz.title)
            context.insert(quiz)
            for question in generatedQuiz.questions {
                context.insert(QuizQuestion(quizID: quiz.id, kind: question.kind, prompt: question.prompt, options: question.options, correctAnswer: question.correctAnswer, explanation: question.explanation))
            }

            let guide = try await aiService.generateStudyGuide(from: transcript, notes: notes)
            context.insert(StudyGuide(lectureID: lecture.id, title: guide.title, examReview: guide.examReview, topicSummaries: guide.topicSummaries, importantConcepts: guide.importantConcepts, keyDefinitions: guide.keyDefinitions))
            context.insert(StudyTask(lectureID: lecture.id, dueDate: .now.addingTimeInterval(86_400), title: "Review \(lecture.title)", subtitle: lecture.course.isEmpty ? "Uploaded notes" : lecture.course, kind: .notes))

            lecture.status = .ready
            lecture.updatedAt = .now
            try context.save()
            Haptics.success()
            return lecture.id
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

@Observable
final class DashboardViewModel {
    func averageQuizScore(_ quizzes: [Quiz]) -> Double {
        let attempted = quizzes.filter { $0.attemptCount > 0 }
        return attempted.isEmpty ? 0 : attempted.map(\.lastScore).reduce(0, +) / Double(attempted.count)
    }
}

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

    func results(lectures: [Lecture], notes: [LectureNote], flashcards: [Flashcard], quizzes: [Quiz], guides: [StudyGuide]) -> [SearchResult] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return [] }
        var output: [SearchResult] = []
        output += lectures.compactMap { matches(term, $0.title, $0.course, $0.transcript) ? SearchResult(title: $0.title, subtitle: $0.course.isEmpty ? "Lecture" : $0.course, symbolName: "waveform", route: .lecture($0.id)) : nil }
        output += notes.compactMap { matches(term, $0.title, $0.detailedNotes, $0.conciseSummary, $0.keyTakeaways, $0.vocabularyTerms) ? SearchResult(title: $0.title, subtitle: "Notes", symbolName: "doc.text", route: .notes($0.lectureID)) : nil }
        output += flashcards.compactMap { matches(term, $0.front, $0.back) ? SearchResult(title: $0.front, subtitle: "Flashcard", symbolName: "rectangle.on.rectangle", route: .flashcards($0.lectureID)) : nil }
        output += quizzes.compactMap { matches(term, $0.title) ? SearchResult(title: $0.title, subtitle: "Quiz", symbolName: "checklist", route: .quiz($0.lectureID)) : nil }
        output += guides.compactMap { matches(term, $0.title, $0.examReview, $0.topicSummaries, $0.importantConcepts, $0.keyDefinitions) ? SearchResult(title: $0.title, subtitle: "Study guide", symbolName: "book.closed", route: .studyGuide($0.lectureID)) : nil }
        return Array(output.prefix(40))
    }

    private func matches(_ term: String, _ values: String...) -> Bool {
        values.contains { $0.lowercased().contains(term) }
    }
}

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

    func flip() { isShowingBack.toggle(); Haptics.light() }
    func moveForward(total: Int) { guard total > 0 else { return }; currentIndex = min(currentIndex + 1, total - 1); isShowingBack = false; Haptics.light() }
    func moveBackward() { currentIndex = max(currentIndex - 1, 0); isShowingBack = false; Haptics.light() }

    func mark(_ card: Flashcard, masteryDelta: Int, context: ModelContext) {
        card.mastery = min(5, max(0, card.mastery + masteryDelta))
        card.lastStudiedAt = .now
        card.updatedAt = .now
        try? context.save()
        Haptics.success()
    }
}

@MainActor
@Observable
final class QuizSessionViewModel {
    var answers: [UUID: String] = [:]
    var isSubmitted = false

    var gradingStrictness: GradingStrictness = .medium

    func answer(_ question: QuizQuestion, with value: String) { guard !isSubmitted else { return }; answers[question.id] = value; Haptics.light() }

    func isCorrect(_ question: QuizQuestion) -> Bool {
        let userAnswer = answers[question.id] ?? ""
        switch question.kind {
        case .shortAnswer:
            return similarityScore(userAnswer, question.correctAnswer) >= gradingStrictness.shortAnswerThreshold
        case .multipleChoice, .trueFalse, .matching:
            return normalized(userAnswer) == normalized(question.correctAnswer)
        }
    }

    func submit(quiz: Quiz, questions: [QuizQuestion], context: ModelContext) {
        guard !questions.isEmpty else { return }
        isSubmitted = true
        let correctCount = questions.filter { isCorrect($0) }.count
        quiz.lastScore = Double(correctCount) / Double(questions.count)
        quiz.attemptCount += 1
        quiz.updatedAt = .now
        try? context.save()
        Haptics.success()
    }

    func reset() { answers.removeAll(); isSubmitted = false; Haptics.light() }
    func scoreText(for questions: [QuizQuestion]) -> String { "\(questions.filter { isCorrect($0) }.count) / \(questions.count)" }
    private func normalized(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private func similarityScore(_ userAnswer: String, _ correctAnswer: String) -> Double {
        let user = normalized(userAnswer)
        let correct = normalized(correctAnswer)
        guard !user.isEmpty, !correct.isEmpty else { return 0 }
        if user == correct || user.contains(correct) || correct.contains(user) { return 1 }

        let userTokens = Set(tokens(from: user))
        let correctTokens = Set(tokens(from: correct))
        guard !userTokens.isEmpty, !correctTokens.isEmpty else { return 0 }

        let overlap = userTokens.intersection(correctTokens).count
        let recall = Double(overlap) / Double(correctTokens.count)
        let precision = Double(overlap) / Double(userTokens.count)
        return (recall * 0.7) + (precision * 0.3)
    }

    private func tokens(from value: String) -> [String] {
        let stopWords: Set<String> = ["a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "is", "it", "of", "on", "or", "that", "the", "to", "with"]
        return value.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }
}

@MainActor
@Observable
final class ChatViewModel {
    var draft = ""
    var isResponding = false
    var errorMessage: String?
    private let aiService: StudyAIProviding

    init(aiService: StudyAIProviding) { self.aiService = aiService }

    func send(lectureID: UUID, noteContext: String, context: ModelContext) async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isResponding else { return }
        draft = ""
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

// MARK: - Design System

enum PrepPilotTheme {
    static let cornerRadius: CGFloat = 8
    static let studyGradient = LinearGradient(colors: [.indigo, .teal, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let recordingRed = Color(red: 1.00, green: 0.28, blue: 0.36)
    static let recordingPaused = Color(red: 1.00, green: 0.65, blue: 0.24)
    static let recordingGradient = LinearGradient(colors: [recordingRed, .indigo, .teal], startPoint: .bottomLeading, endPoint: .topTrailing)

    static func accent(_ name: String) -> Color {
        switch name {
        case "teal": return .teal
        case "mint": return .mint
        case "coral": return .pink
        case "amber": return .orange
        case "blue": return .blue
        default: return .indigo
        }
    }
}

enum PrepPilotFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static let duration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    static func durationString(_ interval: TimeInterval) -> String {
        duration.string(from: interval) ?? "0:00"
    }
}

enum Haptics {
    static func light() { impact(.light) }
    static func medium() { impact(.medium) }
    static func success() { notify(.success) }
    static func warning() { notify(.warning) }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }
}

struct PremiumBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            LinearGradient(colors: [.indigo.opacity(0.18), .clear, .teal.opacity(0.10), .pink.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            content
        }
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1) }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading { ProgressView().tint(.white) } else { Image(systemName: systemImage).font(.headline) }
                Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(PrepPilotTheme.studyGradient, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
    }
}

struct CompactGradientButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(PrepPilotTheme.studyGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

enum KeyboardDismissal {
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

extension View {
    @ViewBuilder
    func dismissKeyboardOnTap() -> some View {
        #if canImport(UIKit)
        self.onTapGesture {
            KeyboardDismissal.dismiss()
        }
        #else
        self
        #endif
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    let title: String
    var tint: Color = .indigo
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

struct CourseIconView: View {
    let course: CourseClass?
    var accent: Color
    var size: CGFloat
    var fallbackSystemImage = "books.vertical"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(PrepPilotTheme.cornerRadius, size * 0.28), style: .continuous)
                .fill(accent.opacity(0.14))

            iconContent
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var iconContent: some View {
        if let course, course.iconKind == .emoji, let emoji = course.iconValue, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size * 0.48))
                .minimumScaleFactor(0.7)
        } else if let course, course.iconKind == .photo, let image = decodedIconImage(from: course.iconValue) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: min(PrepPilotTheme.cornerRadius, size * 0.28), style: .continuous))
        } else {
            Image(systemName: fallbackSystemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private func decodedIconImage(from encodedValue: String?) -> Image? {
        #if canImport(UIKit)
        guard let encodedValue,
              let data = Data(base64Encoded: encodedValue),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
enum CourseIconImageRenderer {
    static func encodedThumbnail(from image: UIImage, maxPixelSize: CGFloat = 320) -> String? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        let size = CGSize(width: maxPixelSize, height: maxPixelSize)
        let renderer = UIGraphicsImageRenderer(size: size)
        let data = renderer.jpegData(withCompressionQuality: 0.78) { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let drawOrigin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
            image.draw(in: CGRect(origin: drawOrigin, size: drawSize))
        }

        return data.base64EncodedString()
    }
}
#endif

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var actionSystemImage = "arrow.right"
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage).font(.system(size: 42, weight: .semibold)).foregroundStyle(PrepPilotTheme.studyGradient).symbolRenderingMode(.hierarchical)
            VStack(spacing: 6) {
                Text(title).font(.title3.weight(.semibold)).multilineTextAlignment(.center)
                Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                PrimaryActionButton(title: actionTitle, systemImage: actionSystemImage, action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 20)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage).font(.title3.weight(.semibold)).foregroundStyle(tint).frame(width: 34, height: 34).background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(value).font(.title2.weight(.bold)).monospacedDigit()
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.headline)
            Spacer()
            if let actionTitle, let action { Button(actionTitle, action: action).font(.subheadline.weight(.semibold)) }
        }
    }
}

struct WaveformView: View {
    let levels: [CGFloat]
    var tint: Color = .indigo

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: barWidth, height: max(6, proxy.size.height * max(0.06, min(level, 1))))
                        .animation(.spring(response: 0.22, dampingFraction: 0.76), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

struct RecordingFlowWaveformView: View {
    let levels: [CGFloat]
    var isPaused = false

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(PrepPilotTheme.recordingGradient)
                        .frame(width: barWidth, height: max(6, proxy.size.height * max(0.06, min(level, 1))))
                        .opacity(isPaused ? 0.48 : 1)
                        .animation(.spring(response: 0.22, dampingFraction: 0.76), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

struct LectureRow: View {
    let lecture: Lecture
    var noteCount: Int
    var cardCount: Int
    var quizCount: Int
    var isPinned = false
    var course: CourseClass? = nil

    var body: some View {
        HStack(spacing: 14) {
            CourseIconView(course: course, accent: PrepPilotTheme.accent(lecture.accentName), size: 52, fallbackSystemImage: "waveform")
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(lecture.title).font(.headline).lineLimit(1).layoutPriority(1)
                    if lecture.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow) }
                    if isPinned {
                        PinnedLectureBadge(tint: PrepPilotTheme.accent(lecture.accentName))
                    }
                }
                Text(rowSubtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(noteCount)", systemImage: "doc.text")
                    Label("\(cardCount)", systemImage: "rectangle.on.rectangle")
                    Label("\(quizCount)", systemImage: "checklist")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
    }

    private var rowSubtitle: String {
        let date = PrepPilotFormatters.shortDate.string(from: lecture.createdAt)
        let duration = PrepPilotFormatters.durationString(lecture.duration)
        return lecture.course.isEmpty ? "\(date) • \(duration)" : "\(lecture.course) • \(duration)"
    }
}

private struct PinnedLectureBadge: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "pin.fill")
            Text("Pinned")
        }
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
            .accessibilityLabel("Pinned lecture")
    }
}

struct StudyTaskRow: View {
    let task: StudyTask
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(task.isComplete ? .green : .indigo)
                    .frame(width: 34, height: 34)
                    .background((task.isComplete ? Color.green : Color.indigo).opacity(0.12), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                    Text("\(task.subtitle) • Due \(PrepPilotFormatters.relative.localizedString(for: task.dueDate, relativeTo: .now))").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch task.kind {
        case .review: return "book.closed"
        case .flashcards: return "rectangle.on.rectangle"
        case .quiz: return "checklist"
        case .notes: return "doc.text"
        }
    }
}

struct LoadingStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) { ProgressView().controlSize(.large); Text(message).font(.headline).multilineTextAlignment(.center) }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
    }
}

// MARK: - Root App Views

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("isSignedIn") private var isSignedIn = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if !isSignedIn {
                AuthenticationView()
            } else {
                MainTabView()
            }
        }
        .tint(.indigo)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: hasCompletedOnboarding)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSignedIn)
    }
}

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection = 0

    private let pages: [OnboardingStepContent] = [
        OnboardingStepContent(symbol: "waveform", title: "Capture the lecture", message: "Record, pause, resume, and keep every class session organized from the first minute."),
        OnboardingStepContent(symbol: "sparkles.rectangle.stack", title: "Turn audio into study material", message: "PrepPilot drafts notes, summaries, flashcards, quizzes, and review guides from each transcript."),
        OnboardingStepContent(symbol: "graduationcap", title: "Prepare with context", message: "Ask focused questions and get answers grounded in your own lecture notes.")
    ]

    private var currentIndex: Int {
        min(max(selection, 0), pages.count - 1)
    }

    private var currentPage: OnboardingStepContent {
        pages[currentIndex]
    }

    var body: some View {
        PremiumBackground {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 8) {
                    Text("PrepPilot")
                        .font(.largeTitle.weight(.bold))
                    Text("Study materials from every lecture")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                OnboardingStepView(page: currentPage)
                    .frame(maxHeight: 430)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.indigo : Color.secondary.opacity(0.25))
                            .frame(width: index == currentIndex ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selection)
                    }
                }
                .accessibilityLabel("Onboarding step \(currentIndex + 1) of \(pages.count)")

                PrimaryActionButton(
                    title: currentIndex == pages.count - 1 ? "Get Started" : "Continue",
                    systemImage: currentIndex == pages.count - 1 ? "arrow.right" : "chevron.right"
                ) {
                    Haptics.medium()
                    if currentIndex >= pages.count - 1 {
                        hasCompletedOnboarding = true
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            selection = currentIndex + 1
                        }
                    }
                }
                .padding(.horizontal)
                .zIndex(1)

                Spacer(minLength: 24)
            }
        }
    }
}

private struct OnboardingStepContent: Hashable {
    let symbol: String
    let title: String
    let message: String
}

private struct OnboardingStepView: View {
    let page: OnboardingStepContent

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.symbol)
                .font(.system(size: 68, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PrepPilotTheme.studyGradient)
                .frame(width: 150, height: 150)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

struct AuthenticationView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    var body: some View {
        PremiumBackground {
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 18) {
                    Image(systemName: "person.badge.key").font(.system(size: 56, weight: .semibold)).foregroundStyle(PrepPilotTheme.studyGradient).frame(width: 116, height: 116).background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                    VStack(spacing: 8) {
                        Text("Sign in to PrepPilot").font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                        Text("Keep lectures, notes, flashcards, and quiz progress synced across your devices.").font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success:
                            Haptics.success()
                            isSignedIn = true
                        case .failure(let error):
                            Haptics.warning()
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                    Button("Continue in Development") { Haptics.success(); isSignedIn = true }
                        .font(.headline)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
                .padding(.horizontal)
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal) }
                Spacer()
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var path = NavigationPath()
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selectedTab) {
                DashboardView(path: $path)
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                    .tag(AppTab.dashboard)

                RecordingView(path: $path)
                    .tabItem { Label("Record", systemImage: "mic.circle.fill") }
                    .tag(AppTab.recording)

                MaterialsView(path: $path)
                    .tabItem { Label("Materials", systemImage: "rectangle.stack.fill") }
                    .tag(AppTab.materials)

                ProfileView(path: $path)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(AppTab.profile)
            }
            .navigationDestination(for: AppRoute.self) { route in
                AppDestinationView(route: route, path: $path)
            }
        }
    }
}

private struct AppDestinationView: View {
    let route: AppRoute
    @Binding var path: NavigationPath
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        switch route {
        case .lecture(let id): LectureDetailView(lectureID: id, path: $path)
        case .recording: RecordingView(path: $path)
        case .importNotes: ImportNotesView(path: $path, aiService: environment.aiService)
        case .coursesClasses: CoursesClassesView(path: $path)
        case .addCourseClass: AddCourseClassView(path: $path)
        case .transcript(let id): TranscriptView(lectureID: id)
        case .notes(let id): NotesView(lectureID: id)
        case .flashcards(let id): FlashcardView(lectureID: id)
        case .quiz(let id): QuizView(lectureID: id)
        case .studyGuide(let id): StudyGuideView(lectureID: id)
        case .chat(let id): AIChatView(lectureID: id, aiService: environment.aiService)
        case .paywall: PaywallView()
        case .settings: SettingsView()
        }
    }
}

struct CoursesClassesView: View {
    @Binding var path: NavigationPath
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    private var courses: [CourseClass] {
        CourseCatalogStorage.decode(courseClassesData).sorted { $0.createdAt > $1.createdAt }
    }


    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Courses and Classes")
                            .font(.largeTitle.weight(.bold))
                        Text("Keep your lectures organized by class, professor, and term.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)

                    addCourseCard

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Classes", value: "\(courses.count)", systemImage: "books.vertical", tint: .indigo)
                        MetricTile(title: "Lectures", value: "\(lectures.count)", systemImage: "waveform", tint: .teal)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Your Classes")
                            .padding(.horizontal)

                        if courses.isEmpty {
                            EmptyStateView(systemImage: "books.vertical", title: "No classes yet", message: "Add a course or class to keep recordings and study materials easier to find.")
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(courses) { course in
                                    CourseClassCard(course: course, lectures: lecturesForCourse(course)) {
                                        delete(course)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("Courses")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var addCourseCard: some View {
        PrimaryActionButton(title: "Add Class", systemImage: "plus") {
            path.append(AppRoute.addCourseClass)
        }
        .padding(.horizontal)
    }


    private func delete(_ course: CourseClass) {
        let updatedCourses = courses.filter { $0.id != course.id }
        courseClassesData = CourseCatalogStorage.encode(updatedCourses)
        Haptics.light()
    }

    private func lecturesForCourse(_ course: CourseClass) -> [Lecture] {
        let names = [course.name]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return [] }
        return lectures.filter { lecture in
            let courseName = lecture.course.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return names.contains { courseName.contains($0) || $0.contains(courseName) }
        }
    }
}

struct AddCourseClassView: View {
    @Binding var path: NavigationPath
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @State private var name = ""
    @State private var instructor = ""
    @State private var term = ""
    @State private var selectedIconKind = CourseIconKind.symbol
    @State private var selectedEmoji = "📚"
    @State private var selectedIconPhotoItems: [PhotosPickerItem] = []
    @State private var iconPhotoData: String?
    @State private var isShowingIconCamera = false
    @State private var isShowingIconFileImporter = false
    @State private var iconErrorMessage: String?

    private let emojiChoices = ["📚", "🧠", "🧬", "🧪", "🔬", "🧮", "📊", "🌎", "🏛️", "⚖️", "💻", "🎨", "🎼", "✏️", "📝", "🩺", "🚀", "💡"]

    private var canAddCourse: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedIconKindRaw: String? {
        switch selectedIconKind {
        case .symbol:
            return nil
        case .emoji:
            return CourseIconKind.emoji.rawValue
        case .photo:
            return iconPhotoData == nil ? nil : CourseIconKind.photo.rawValue
        }
    }

    private var selectedIconValue: String? {
        switch selectedIconKind {
        case .symbol:
            return nil
        case .emoji:
            return selectedEmoji
        case .photo:
            return iconPhotoData
        }
    }

    private var previewCourse: CourseClass {
        CourseClass(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Class" : name,
            accentName: "indigo",
            iconKindRaw: selectedIconKindRaw,
            iconValue: selectedIconValue
        )
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 18) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("New Class", systemImage: "books.vertical")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PrepPilotTheme.studyGradient)
                            Text("Add the class name, instructor, and term so lectures are easier to organize.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    iconChooserCard

                    GlassCard {
                        VStack(spacing: 12) {
                            TextField("Course or class name", text: $name)
                                .textInputAutocapitalization(.words)
                                .font(.headline)
                                .padding(12)
                                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))


                            HStack(spacing: 12) {
                                TextField("Instructor", text: $instructor)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                                TextField("Term", text: $term)
                                    .textInputAutocapitalization(.words)
                                    .padding(12)
                                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                            }
                        }
                    }

                    PrimaryActionButton(title: "Add Class", systemImage: "plus") {
                        addCourse()
                    }
                    .disabled(!canAddCourse)
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("Add Class")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isShowingIconFileImporter, allowedContentTypes: [.image]) { result in
            loadIconFile(result)
        }
        .onChange(of: selectedIconPhotoItems) { _, newItems in
            Task { await loadIconPhotoItems(newItems) }
        }
        .fullScreenCover(isPresented: $isShowingIconCamera) {
            CameraCaptureView { image in
                storeIconImage(image)
            }
        }
    }

    private var iconChooserCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    CourseIconView(course: previewCourse, accent: .indigo, size: 58, fallbackSystemImage: "books.vertical")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Class Icon")
                            .font(.headline)
                        Text("This icon will appear on recordings assigned to this class.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Picker("Icon Style", selection: $selectedIconKind) {
                    ForEach(CourseIconKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedIconKind {
                case .symbol:
                    Label("Use the default class icon.", systemImage: "books.vertical")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                case .emoji:
                    emojiIconGrid
                case .photo:
                    photoIconControls
                }

                if let iconErrorMessage {
                    Text(iconErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var emojiIconGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(emojiChoices, id: \.self) { emoji in
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                        selectedEmoji = emoji
                    }
                    Haptics.light()
                } label: {
                    Text(emoji)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(selectedEmoji == emoji ? PrepPilotTheme.studyGradient : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(selectedEmoji == emoji ? Color.clear : Color.secondary.opacity(0.16), lineWidth: 1)
                        }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Use \(emoji) as class icon")
            }
        }
    }

    private var photoIconControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CompactGradientButton(title: "Camera", systemImage: "camera") {
                    openIconCamera()
                }

                PhotosPicker(selection: $selectedIconPhotoItems, maxSelectionCount: 1, matching: .images) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(PrepPilotTheme.studyGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(PressableButtonStyle())

                CompactGradientButton(title: "File", systemImage: "folder") {
                    isShowingIconFileImporter = true
                }
            }

            Text(iconPhotoData == nil ? "Choose a square-ish image. PrepPilot will crop it into a small class icon." : "Custom class photo selected.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addCourse() {
        var updatedCourses = CourseCatalogStorage.decode(courseClassesData)
        let accent = ["indigo", "teal", "coral", "amber", "blue"].randomElement() ?? "indigo"
        updatedCourses.insert(
            CourseClass(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                instructor: instructor.trimmingCharacters(in: .whitespacesAndNewlines),
                term: term.trimmingCharacters(in: .whitespacesAndNewlines),
                accentName: accent,
                iconKindRaw: selectedIconKindRaw,
                iconValue: selectedIconValue
            ),
            at: 0
        )
        courseClassesData = CourseCatalogStorage.encode(updatedCourses)
        Haptics.success()
        path.removeLast()
    }

    private func openIconCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            iconErrorMessage = "Camera is not available on this device."
            return
        }
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            iconErrorMessage = "Missing NSCameraUsageDescription in the app target."
            return
        }
        iconErrorMessage = nil
        isShowingIconCamera = true
    }

    @MainActor
    private func loadIconPhotoItems(_ items: [PhotosPickerItem]) async {
        guard let item = items.first else { return }
        defer { selectedIconPhotoItems = [] }

        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                storeIconImage(image)
            } else {
                iconErrorMessage = "That photo could not be loaded."
            }
        } catch {
            iconErrorMessage = "That photo could not be loaded."
        }
    }

    private func loadIconFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                iconErrorMessage = "That file is not a readable image."
                return
            }
            storeIconImage(image)
        } catch {
            iconErrorMessage = "That image file could not be opened."
        }
    }

    private func storeIconImage(_ image: UIImage) {
        guard let encodedImage = CourseIconImageRenderer.encodedThumbnail(from: image) else {
            iconErrorMessage = "That image could not be prepared as a class icon."
            return
        }

        withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
            iconPhotoData = encodedImage
            selectedIconKind = .photo
            iconErrorMessage = nil
        }
        Haptics.light()
    }
}

private struct CourseClassCard: View {
    let course: CourseClass
    let lectures: [Lecture]
    let deleteAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    CourseIconView(course: course, accent: PrepPilotTheme.accent(course.accentName), size: 44, fallbackSystemImage: "books.vertical")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    ToolbarIconButton(systemImage: "trash", title: "Delete Class", tint: .red, action: deleteAction)
                }

                HStack(spacing: 10) {
                    Label("\(lectures.count) lectures", systemImage: "waveform")
                    if let latestLecture = lectures.first {
                        Label(PrepPilotFormatters.shortDate.string(from: latestLecture.createdAt), systemImage: "calendar")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                if !lectures.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(lectures.prefix(3)) { lecture in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(PrepPilotTheme.accent(lecture.accentName))
                                    .frame(width: 7, height: 7)
                                Text(lecture.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private var subtitle: String {
        [course.instructor, course.term]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
            .isEmpty ? "Class details" : [course.instructor, course.term]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " • ")
    }
}

struct MaterialsView: View {
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext
    @AppStorage("pinnedLectureIDsData") private var pinnedLectureIDsData = ""
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query(sort: \LectureNote.createdAt, order: .reverse) private var notes: [LectureNote]
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var flashcards: [Flashcard]
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]
    @Query(sort: \QuizQuestion.createdAt, order: .forward) private var questions: [QuizQuestion]
    @Query(sort: \StudyGuide.createdAt, order: .reverse) private var guides: [StudyGuide]
    @Query(sort: \StudyTask.dueDate, order: .forward) private var tasks: [StudyTask]
    @Query(sort: \AIChatMessage.createdAt, order: .forward) private var messages: [AIChatMessage]
    @State private var query = ""
    @State private var sort = MaterialSort.dateRecorded
    @State private var deletingLectureIDs = Set<UUID>()

    private var pinnedIDs: Set<UUID> { PinnedLectureStorage.decode(pinnedLectureIDsData) }
    private var courses: [CourseClass] { CourseCatalogStorage.decode(courseClassesData) }

    private var visibleLectures: [Lecture] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let searchableLectures = lectures.filter { !deletingLectureIDs.contains($0.id) }
        let filtered = term.isEmpty ? searchableLectures : searchableLectures.filter { lecture in
            let lectureNotes = notes.filter { $0.lectureID == lecture.id }
            return [lecture.title, lecture.course, lecture.transcript].contains { $0.lowercased().contains(term) }
                || lectureNotes.contains { [$0.title, $0.conciseSummary, $0.keyTakeaways, $0.importantConcepts].contains { $0.lowercased().contains(term) } }
        }

        return filtered.sorted { left, right in
            let leftPinned = pinnedIDs.contains(left.id)
            let rightPinned = pinnedIDs.contains(right.id)
            if leftPinned != rightPinned { return leftPinned }

            switch sort {
            case .dateRecorded:
                return left.createdAt > right.createdAt
            case .course:
                return left.course.localizedCaseInsensitiveCompare(right.course) == .orderedAscending
            case .contentAmount:
                return contentCount(for: left) > contentCount(for: right)
            case .title:
                return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Materials")
                                .font(.largeTitle.weight(.bold))
                            Text("Search and review every lecture, note, flashcard, quiz, and guide.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        PrimaryActionButton(title: "Upload Notes", systemImage: "doc.badge.plus") {
                            path.append(AppRoute.importNotes)
                        }
                    }
                    .padding(.horizontal)

                    GlassCard {
                        VStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search lectures and materials", text: $query)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                if !query.isEmpty {
                                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(12)
                            .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                            HStack(spacing: 8) {
                                Text("Sort By:")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Picker("Sort", selection: $sort) {
                                    ForEach(MaterialSort.allCases) { option in
                                        Text(option.title).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Notes", value: "\(notes.count)", systemImage: "doc.text", tint: .indigo)
                        MetricTile(title: "Cards", value: "\(flashcards.count)", systemImage: "rectangle.on.rectangle", tint: .teal)
                        MetricTile(title: "Quizzes", value: "\(quizzes.count)", systemImage: "checklist", tint: .pink)
                        MetricTile(title: "Guides", value: "\(guides.count)", systemImage: "book.closed", tint: .orange)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: query.isEmpty ? "All Lectures" : "Search Results")
                            .padding(.horizontal)

                        if lectures.isEmpty {
                            EmptyStateView(systemImage: "rectangle.stack.badge.plus", title: "No materials yet", message: "Record a lecture or upload notes to generate flashcards, quizzes, and study guides.", actionTitle: "Upload Notes") { path.append(AppRoute.importNotes) }
                                .padding(.horizontal)
                        } else if visibleLectures.isEmpty {
                            EmptyStateView(systemImage: "magnifyingglass", title: "No matches", message: "Try a lecture title, course, concept, flashcard answer, or quiz topic.")
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(visibleLectures) { lecture in
                                    MaterialLectureCard(
                                        lecture: lecture,
                                        course: courseForLecture(lecture),
                                        isPinned: pinnedIDs.contains(lecture.id),
                                        noteCount: notes.filter { $0.lectureID == lecture.id }.count,
                                        cardCount: flashcards.filter { $0.lectureID == lecture.id }.count,
                                        quizCount: quizzes.filter { $0.lectureID == lecture.id }.count,
                                        guideCount: guides.filter { $0.lectureID == lecture.id }.count,
                                        path: $path,
                                        togglePin: { togglePin(lecture) },
                                        deleteLecture: { delete(lecture) }
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("Materials")
    }

    private func contentCount(for lecture: Lecture) -> Int {
        notes.filter { $0.lectureID == lecture.id }.count
            + flashcards.filter { $0.lectureID == lecture.id }.count
            + quizzes.filter { $0.lectureID == lecture.id }.count
            + guides.filter { $0.lectureID == lecture.id }.count
    }

    private func courseForLecture(_ lecture: Lecture) -> CourseClass? {
        CourseCatalogStorage.course(matching: lecture.course, in: courses)
    }

    private func togglePin(_ lecture: Lecture) {
        pinnedLectureIDsData = PinnedLectureStorage.toggled(lecture.id, in: pinnedLectureIDsData)
        Haptics.light()
    }

    private func delete(_ lecture: Lecture) {
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = deletingLectureIDs.insert(lecture.id)
        }
        Haptics.warning()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            deleteLectureCascade(lecture, context: modelContext, notes: notes, flashcards: flashcards, quizzes: quizzes, questions: questions, guides: guides, tasks: tasks, messages: messages)
            var pinned = pinnedIDs
            pinned.remove(lecture.id)
            pinnedLectureIDsData = PinnedLectureStorage.encode(pinned)
            deletingLectureIDs.remove(lecture.id)
        }
    }
}

private struct MaterialLectureCard: View {
    let lecture: Lecture
    let course: CourseClass?
    let isPinned: Bool
    let noteCount: Int
    let cardCount: Int
    let quizCount: Int
    let guideCount: Int
    @Binding var path: NavigationPath
    let togglePin: () -> Void
    let deleteLecture: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    CourseIconView(course: course, accent: PrepPilotTheme.accent(lecture.accentName), size: 42, fallbackSystemImage: isPinned ? "pin.fill" : "rectangle.stack.fill")

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(lecture.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            if isPinned {
                                PinnedLectureBadge(tint: PrepPilotTheme.accent(lecture.accentName))
                            }
                        }
                        Text(lecture.course.isEmpty ? PrepPilotFormatters.shortDate.string(from: lecture.createdAt) : lecture.course)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ToolbarIconButton(systemImage: "arrow.right", title: "Open Lecture") {
                        path.append(AppRoute.lecture(lecture.id))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MaterialShortcutButton(title: "Notes", symbol: "doc.text", tint: .indigo, count: noteCount) { path.append(AppRoute.notes(lecture.id)) }
                    MaterialShortcutButton(title: "Cards", symbol: "rectangle.on.rectangle", tint: .teal, count: cardCount) { path.append(AppRoute.flashcards(lecture.id)) }
                    MaterialShortcutButton(title: "Quiz", symbol: "checklist", tint: .pink, count: quizCount) { path.append(AppRoute.quiz(lecture.id)) }
                    MaterialShortcutButton(title: "Guide", symbol: "book.closed", tint: .orange, count: guideCount) { path.append(AppRoute.studyGuide(lecture.id)) }
                }
            }
        }
        .contextMenu {
            Button(action: togglePin) {
                Label(isPinned ? "Unpin Lecture" : "Pin Lecture", systemImage: isPinned ? "pin.slash" : "pin")
            }
            .tint(.primary)
            Button(role: .destructive, action: deleteLecture) {
                Label("Delete Lecture", systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

private func deleteLectureCascade(_ lecture: Lecture, context: ModelContext, notes: [LectureNote], flashcards: [Flashcard], quizzes: [Quiz], questions: [QuizQuestion], guides: [StudyGuide], tasks: [StudyTask], messages: [AIChatMessage]) {
    let quizIDs = Set(quizzes.filter { $0.lectureID == lecture.id }.map(\.id))
    notes.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    flashcards.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    questions.filter { quizIDs.contains($0.quizID) }.forEach(context.delete)
    quizzes.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    guides.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    tasks.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    messages.filter { $0.lectureID == lecture.id }.forEach(context.delete)
    context.delete(lecture)
    try? context.save()
}

private struct MaterialShortcutButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct CoursePickerControl: View {
    let courses: [CourseClass]
    @Binding var selection: String
    @State private var isExpanded = false

    private var selectedCourse: CourseClass? {
        CourseCatalogStorage.course(matching: selection, in: courses)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                KeyboardDismissal.dismiss()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isExpanded.toggle()
                }
                Haptics.light()
            } label: {
                HStack(spacing: 10) {
                    if let selectedCourse {
                        CourseIconView(course: selectedCourse, accent: PrepPilotTheme.accent(selectedCourse.accentName), size: 28, fallbackSystemImage: "books.vertical")
                    }
                    Text(selection.isEmpty ? "Select course or class" : selection)
                        .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(courses) { course in
                        Button {
                            selection = course.displayTitle
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                isExpanded = false
                            }
                            Haptics.light()
                        } label: {
                            HStack(spacing: 10) {
                                CourseIconView(course: course, accent: PrepPilotTheme.accent(course.accentName), size: 28, fallbackSystemImage: "books.vertical")
                                Text(course.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                if selection == course.displayTitle {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PrepPilotTheme.accent(course.accentName))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
    }
}

private struct StudyGenerationSettingsCard: View {
    @Binding var preferences: StudyGenerationPreferences

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Study Material Settings", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Stepper(value: Binding(get: {
                    preferences.flashcardCount
                }, set: { newValue in
                    preferences.flashcardCount = newValue
                }), in: 4...30) {
                    settingsRow(title: "Flashcards", value: "\(preferences.flashcardCount)", symbol: "rectangle.on.rectangle")
                }

                Stepper(value: Binding(get: {
                    preferences.quizQuestionCount
                }, set: { newValue in
                    preferences.quizQuestionCount = newValue
                }), in: 3...25) {
                    settingsRow(title: "Quiz questions", value: "\(preferences.quizQuestionCount)", symbol: "checklist")
                }

                Divider().opacity(0.45)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quiz Structure")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(QuizQuestionKind.allCases) { kind in
                            Toggle(kind.title, isOn: Binding(get: {
                                preferences.quizKinds.contains(kind)
                            }, set: { isSelected in
                                updateQuizKind(kind, isSelected: isSelected)
                            }))
                            .font(.subheadline.weight(.semibold))
                            .tint(.indigo)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingsRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.indigo)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func updateQuizKind(_ kind: QuizQuestionKind, isSelected: Bool) {
        var kinds = Set(preferences.quizKinds)
        if isSelected {
            kinds.insert(kind)
        } else if kinds.count > 1 {
            kinds.remove(kind)
        } else {
            Haptics.warning()
        }
        preferences.quizKinds = QuizQuestionKind.allCases.filter { kinds.contains($0) }
    }
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    @AppStorage("pinnedLectureIDsData") private var pinnedLectureIDsData = ""
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query(sort: \LectureNote.createdAt, order: .reverse) private var notes: [LectureNote]
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var flashcards: [Flashcard]
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]
    @Query(sort: \QuizQuestion.createdAt, order: .forward) private var questions: [QuizQuestion]
    @Query(sort: \StudyGuide.createdAt, order: .reverse) private var guides: [StudyGuide]
    @Query(sort: \StudyTask.dueDate, order: .forward) private var tasks: [StudyTask]
    @Query(sort: \AIChatMessage.createdAt, order: .forward) private var messages: [AIChatMessage]
    @State private var viewModel = DashboardViewModel()
    @State private var deletingLectureIDs = Set<UUID>()

    private var pinnedIDs: Set<UUID> { PinnedLectureStorage.decode(pinnedLectureIDsData) }
    private var courses: [CourseClass] { CourseCatalogStorage.decode(courseClassesData) }

    private var recentLectures: [Lecture] {
        lectures.filter { !deletingLectureIDs.contains($0.id) }.sorted { left, right in
            let leftPinned = pinnedIDs.contains(left.id)
            let rightPinned = pinnedIDs.contains(right.id)
            if leftPinned != rightPinned { return leftPinned }
            return left.createdAt > right.createdAt
        }
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today").font(.largeTitle.weight(.bold))
                            Text("Record a lecture, review generated material, and keep your exam prep moving.").font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        VStack(spacing: 10) {
                            PrimaryActionButton(title: "Record Lecture", systemImage: "mic.fill") { path.append(AppRoute.recording) }
                            PrimaryActionButton(title: "Upload Notes", systemImage: "doc.badge.plus") { path.append(AppRoute.importNotes) }
                        }
                    }
                    .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Lectures", value: "\(lectures.count)", systemImage: "waveform", tint: .indigo)
                        MetricTile(title: "Due Soon", value: "\(tasks.filter { !$0.isComplete }.count)", systemImage: "calendar.badge.clock", tint: .orange)
                        MetricTile(title: "Cards Studied", value: "\(flashcards.filter { $0.lastStudiedAt != nil || $0.mastery > 0 }.count)", systemImage: "rectangle.on.rectangle", tint: .teal)
                        let average = viewModel.averageQuizScore(quizzes)
                        MetricTile(title: "Quiz Avg", value: average == 0 ? "--" : "\(Int(average * 100))%", systemImage: "chart.line.uptrend.xyaxis", tint: .pink)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Study Tasks").padding(.horizontal)
                        let visibleTasks = Array(tasks.filter { !$0.isComplete }.prefix(4))
                        if visibleTasks.isEmpty {
                            EmptyStateView(systemImage: "checkmark.seal", title: "No tasks waiting", message: "New review tasks appear after recording and generating study materials.").padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(visibleTasks) { task in
                                    StudyTaskRow(task: task) { task.isComplete.toggle(); try? modelContext.save(); Haptics.success() }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Recent Lectures").padding(.horizontal)
                        if lectures.isEmpty {
                            EmptyStateView(systemImage: "waveform.badge.plus", title: "Record your first lecture", message: "PrepPilot will save the audio and create a transcript, notes, flashcards, a quiz, and a study guide.", actionTitle: "Start Recording", actionSystemImage: "mic.fill") { path.append(AppRoute.recording) }.padding(.horizontal)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(recentLectures.prefix(6))) { lecture in
                                    Button { path.append(AppRoute.lecture(lecture.id)) } label: {
                                        LectureRow(lecture: lecture, noteCount: notes.filter { $0.lectureID == lecture.id }.count, cardCount: flashcards.filter { $0.lectureID == lecture.id }.count, quizCount: quizzes.filter { $0.lectureID == lecture.id }.count, isPinned: pinnedIDs.contains(lecture.id), course: courseForLecture(lecture))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button { togglePin(lecture) } label: {
                                            Label(pinnedIDs.contains(lecture.id) ? "Unpin Lecture" : "Pin Lecture", systemImage: pinnedIDs.contains(lecture.id) ? "pin.slash" : "pin")
                                        }
                                        .tint(.primary)
                                        Button(role: .destructive) { delete(lecture) } label: {
                                            Label("Delete Lecture", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("PrepPilot")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ToolbarIconButton(systemImage: "plus", title: "Record lecture", tint: .indigo) { path.append(AppRoute.recording) } } }
    }

    private func togglePin(_ lecture: Lecture) {
        pinnedLectureIDsData = PinnedLectureStorage.toggled(lecture.id, in: pinnedLectureIDsData)
        Haptics.light()
    }

    private func courseForLecture(_ lecture: Lecture) -> CourseClass? {
        CourseCatalogStorage.course(matching: lecture.course, in: courses)
    }

    private func delete(_ lecture: Lecture) {
        withAnimation(.easeInOut(duration: 0.22)) {
            _ = deletingLectureIDs.insert(lecture.id)
        }
        Haptics.warning()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            deleteLectureCascade(lecture, context: modelContext, notes: notes, flashcards: flashcards, quizzes: quizzes, questions: questions, guides: guides, tasks: tasks, messages: messages)
            var pinned = pinnedIDs
            pinned.remove(lecture.id)
            pinnedLectureIDsData = PinnedLectureStorage.encode(pinned)
            deletingLectureIDs.remove(lecture.id)
        }
    }
}

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("isSignedIn") private var isSignedIn = true
    @Binding var path: NavigationPath
    @Query private var lectures: [Lecture]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 18) {
                    GlassCard {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 54)).foregroundStyle(PrepPilotTheme.studyGradient)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Student").font(.title2.weight(.bold))
                                Text(environment.cloudSyncService.statusDescription).font(.subheadline).foregroundStyle(environment.cloudSyncService.isAvailable ? .green : .secondary)
                            }
                            Spacer()
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label(environment.subscriptionStore.isPremium ? "PrepPilot Premium" : "Free Plan", systemImage: "sparkles").font(.headline)
                                Spacer()
                                Text(environment.subscriptionStore.isPremium ? "Active" : "Limited").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background((environment.subscriptionStore.isPremium ? Color.green : Color.orange).opacity(0.14), in: Capsule())
                            }
                            Text(environment.subscriptionStore.isPremium ? "Unlimited lectures, generated materials, and AI questions are enabled." : "Free tier includes limited lecture generation. Upgrade for monthly or yearly premium access.").font(.subheadline).foregroundStyle(.secondary)
                            Button(environment.subscriptionStore.isPremium ? "Manage Plan" : "View Premium") { path.append(AppRoute.paywall) }.buttonStyle(.borderedProminent).controlSize(.large)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(title: "Lectures", value: "\(lectures.count)", systemImage: "waveform", tint: .indigo)
                        MetricTile(title: "Flashcards", value: "\(flashcards.count)", systemImage: "rectangle.on.rectangle", tint: .teal)
                        MetricTile(title: "Quizzes", value: "\(quizzes.count)", systemImage: "checklist", tint: .pink)
                        MetricTile(title: "Synced", value: environment.cloudSyncService.isAvailable ? "Yes" : "--", systemImage: "icloud", tint: .blue)
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Courses and Classes", systemImage: "books.vertical")
                                .font(.headline)
                            Text("Manage your classes, then select them while recording or uploading notes.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Open Courses") { path.append(AppRoute.coursesClasses) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button("Settings") { path.append(AppRoute.settings) }.buttonStyle(.bordered).controlSize(.large)
                    Button("Sign Out", role: .destructive) { isSignedIn = false }.buttonStyle(.bordered).controlSize(.large)
                }
                .padding(.vertical, 18)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Profile")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ToolbarIconButton(systemImage: "gearshape", title: "Settings") { path.append(AppRoute.settings) } } }
        .task { await environment.cloudSyncService.refresh() }
    }
}

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("prefersHaptics") private var prefersHaptics = true
    @AppStorage("autoGenerateMaterials") private var autoGenerateMaterials = true
    @AppStorage("useOnDeviceSpeechWhenAvailable") private var useOnDeviceSpeechWhenAvailable = true
    @AppStorage("weeklyStudyReminders") private var weeklyStudyReminders = true
    @State private var notificationMessage: String?

    var body: some View {
        Form {
            Section("Study") { Toggle("Auto-generate materials", isOn: $autoGenerateMaterials) }
            Section("Recording") { Toggle("Prefer on-device speech", isOn: $useOnDeviceSpeechWhenAvailable); Toggle("Haptic feedback", isOn: $prefersHaptics) }
            Section("Notifications") {
                Toggle("Weekly study reminders", isOn: $weeklyStudyReminders)
                Button("Schedule Study Reminders") {
                    Task {
                        do {
                            try await StudyNotificationScheduler.scheduleStudyReminders()
                            notificationMessage = "Scheduled flashcard, quiz, weekly planning, and upload-note reminders."
                        } catch {
                            notificationMessage = error.localizedDescription
                        }
                    }
                }
                if let notificationMessage {
                    Text(notificationMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Cloud") {
                HStack { Label(environment.cloudSyncService.statusDescription, systemImage: "icloud"); Spacer(); if environment.cloudSyncService.isAvailable { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) } }
                Button("Refresh iCloud Status") { Task { await environment.cloudSyncService.refresh() } }
            }
            Section("Onboarding") {
                Button("Replay Onboarding") {
                    Haptics.medium()
                    hasCompletedOnboarding = false
                }
            }
            Section("App Store") { Text("Configure the monthly and yearly product identifiers in App Store Connect before release.").foregroundStyle(.secondary) }
        }
        .navigationTitle("Settings")
        .task { await environment.cloudSyncService.refresh() }
    }
}

struct PaywallView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var purchasingProductID: String?
    @State private var message: String?

    private var store: SubscriptionStore { environment.subscriptionStore }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(PrepPilotTheme.studyGradient).frame(width: 110, height: 110).background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                        VStack(spacing: 6) {
                            Text("PrepPilot Premium").font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                            Text("Unlimited recordings, generated study materials, quizzes, study guides, and note-grounded AI chat.").font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    }
                    PlanCard(title: "Monthly", price: store.displayPrice(for: SubscriptionStore.monthlyProductID), subtitle: "Flexible access for active terms", isRecommended: false, isLoading: purchasingProductID == SubscriptionStore.monthlyProductID, isDisabled: store.products.first { $0.id == SubscriptionStore.monthlyProductID } == nil || store.isPremium) { purchase(SubscriptionStore.monthlyProductID) }
                    PlanCard(title: "Yearly", price: store.displayPrice(for: SubscriptionStore.yearlyProductID), subtitle: "Best value for full-year study", isRecommended: true, isLoading: purchasingProductID == SubscriptionStore.yearlyProductID, isDisabled: store.products.first { $0.id == SubscriptionStore.yearlyProductID } == nil || store.isPremium) { purchase(SubscriptionStore.yearlyProductID) }
                    Button { Task { await store.refreshEntitlements(); message = store.isPremium ? "Purchases restored." : "No active premium entitlement was found." } } label: { Label("Restore Purchases", systemImage: "arrow.clockwise").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50) }.buttonStyle(.bordered).controlSize(.large)
                    if let message { Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Premium")
        .task { await store.loadProducts() }
    }

    private func purchase(_ productID: String) {
        guard let product = store.products.first(where: { $0.id == productID }) else {
            message = "Product not loaded. Verify StoreKit configuration and App Store Connect product IDs."
            return
        }
        Task {
            purchasingProductID = productID
            defer { purchasingProductID = nil }
            do { message = try await store.purchase(product) ? "Premium is active." : "Purchase was not completed." } catch { message = error.localizedDescription }
        }
    }
}

private struct PlanCard: View {
    let title: String
    let price: String
    let subtitle: String
    let isRecommended: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) { Text(title).font(.title3.weight(.bold)); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                    Spacer()
                    if isRecommended { Text("Best Value").font(.caption.weight(.bold)).foregroundStyle(.teal).padding(.horizontal, 10).padding(.vertical, 6).background(.teal.opacity(0.12), in: Capsule()) }
                }
                Text(price).font(.title.weight(.bold)).monospacedDigit()
                PrimaryActionButton(title: isDisabled ? "Unavailable" : "Choose Plan", systemImage: "creditcard", isLoading: isLoading, action: action).disabled(isDisabled || isLoading)
            }
        }
    }
}

// MARK: - Learning Views

struct LectureDetailView: View {
    let lectureID: UUID
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext
    @Query private var lectures: [Lecture]
    @Query private var notes: [LectureNote]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]
    @Query private var quizQuestions: [QuizQuestion]
    @Query private var guides: [StudyGuide]
    private var lecture: Lecture? { lectures.first { $0.id == lectureID } }

    var body: some View {
        PremiumBackground {
            if let lecture {
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 18) {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: "waveform").font(.title.weight(.semibold)).foregroundStyle(PrepPilotTheme.accent(lecture.accentName)).frame(width: 58, height: 58).background(PrepPilotTheme.accent(lecture.accentName).opacity(0.14), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                                    VStack(alignment: .leading, spacing: 6) { Text(lecture.title).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true); Text(lecture.course.isEmpty ? PrepPilotFormatters.shortDate.string(from: lecture.createdAt) : lecture.course).font(.subheadline).foregroundStyle(.secondary) }
                                    Spacer()
                                }
                                HStack(spacing: 10) { Label(PrepPilotFormatters.durationString(lecture.duration), systemImage: "clock"); Label(lecture.status.rawValue.capitalized, systemImage: "checkmark.seal") }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            DetailActionTile(title: "Transcript", symbol: "text.quote", tint: .blue) { path.append(AppRoute.transcript(lecture.id)) }
                            DetailActionTile(title: "Notes", symbol: "doc.text", tint: .indigo) { path.append(AppRoute.notes(lecture.id)) }
                            DetailActionTile(title: "Flashcards", symbol: "rectangle.on.rectangle", tint: .teal, badge: "\(flashcards.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.flashcards(lecture.id)) }
                            DetailActionTile(title: "Quiz", symbol: "checklist", tint: .pink, badge: "\(quizzes.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.quiz(lecture.id)) }
                            DetailActionTile(title: "Study Guide", symbol: "book.closed", tint: .orange, badge: "\(guides.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.studyGuide(lecture.id)) }
                            DetailActionTile(title: "Ask AI", symbol: "bubble.left.and.sparkles", tint: .purple, badge: "\(notes.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.chat(lecture.id)) }
                        }
                        GlassCard {
                            let lectureCards = flashcards.filter { $0.lectureID == lecture.id }
                            let lectureQuizzes = quizzes.filter { $0.lectureID == lecture.id }
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(title: "Study Stats")
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                    MetricTile(title: "Cards Studied", value: "\(lectureCards.filter { $0.lastStudiedAt != nil || $0.mastery > 0 }.count)", systemImage: "rectangle.on.rectangle", tint: .teal)
                                    MetricTile(title: "Avg Mastery", value: averageMasteryText(lectureCards), systemImage: "star", tint: .yellow)
                                    MetricTile(title: "Quiz Attempts", value: "\(lectureQuizzes.map(\.attemptCount).reduce(0, +))", systemImage: "checklist", tint: .pink)
                                    MetricTile(title: "Best Score", value: bestQuizScoreText(lectureQuizzes), systemImage: "chart.line.uptrend.xyaxis", tint: .indigo)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal)
                }
            } else {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "Lecture not found", message: "This lecture may have been deleted on another device.")
            }
        }
        .navigationTitle(lecture?.title ?? "Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let lecture {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        lecture.isFavorite.toggle()
                        lecture.updatedAt = .now
                        try? modelContext.save()
                        Haptics.light()
                    } label: {
                        Image(systemName: lecture.isFavorite ? "star.fill" : "star")
                            .font(.headline)
                            .foregroundStyle(lecture.isFavorite ? .yellow : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Favorite")
                    .help("Favorite")
                }
            }
        }
    }

    private func averageMasteryText(_ cards: [Flashcard]) -> String {
        guard !cards.isEmpty else { return "--" }
        let average = Double(cards.map(\.mastery).reduce(0, +)) / Double(cards.count)
        return "\(String(format: "%.1f", average))/5"
    }

    private func bestQuizScoreText(_ quizzes: [Quiz]) -> String {
        guard let best = quizzes.map(\.lastScore).max(), best > 0 else { return "--" }
        return "\(Int(best * 100))%"
    }
}

private struct DetailActionTile: View {
    let title: String
    let symbol: String
    let tint: Color
    var badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(tint).frame(width: 36, height: 36).background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)); Spacer(); if let badge { Text(badge).font(.caption.weight(.bold)).foregroundStyle(.secondary) } }
                    Text(title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RecordingWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 28, height: 28)
                .background(.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                .stroke(.orange.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RecordingNoticeBanner: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RecordingView: View {
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("courseClassesData") private var courseClassesData = ""
    private var viewModel: RecordingViewModel { environment.recordingViewModel }

    private var courses: [CourseClass] {
        CourseCatalogStorage.decode(courseClassesData).sorted { $0.displayTitle < $1.displayTitle }
    }

    private var isCourseSelectionMissing: Bool {
        viewModel.course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isLectureTitleMissing: Bool {
        viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canStartRecording: Bool {
        !isCourseSelectionMissing && !isLectureTitleMissing
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.title },
            set: {
                viewModel.title = $0
                viewModel.errorMessage = nil
            }
        )
    }

    private var courseBinding: Binding<String> {
        Binding(
            get: { viewModel.course },
            set: {
                viewModel.course = $0
                viewModel.errorMessage = nil
            }
        )
    }

    private var preferencesBinding: Binding<StudyGenerationPreferences> {
        Binding(
            get: { viewModel.preferences },
            set: { viewModel.preferences = $0 }
        )
    }

    init(path: Binding<NavigationPath>) {
        _path = path
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 20) {
                    GlassCard {
                        VStack(spacing: 12) {
                            TextField("Lecture title", text: titleBinding)
                                .textInputAutocapitalization(.words)
                                .font(.headline)
                                .padding(12)
                                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                            courseSelectionControl
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        RecordingNoticeBanner(message: errorMessage, systemImage: "exclamationmark.circle.fill", tint: .red)
                    }

                    recorderCard
                    StudyGenerationSettingsCard(preferences: preferencesBinding)
                    controls
                    if let warningMessage = viewModel.warningMessage {
                        RecordingWarningBanner(message: warningMessage)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .overlay { if case .processing(let message) = viewModel.phase { Color.black.opacity(0.18).ignoresSafeArea(); LoadingStateView(message: message).padding() } }
        }
        .navigationTitle("Record Lecture")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.recorder.duration) { _, _ in
            viewModel.refreshLiveActivity()
        }
    }


    private var courseSelectionControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            if courses.isEmpty {
                TextField("Course or class", text: courseBinding)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            } else {
                CoursePickerControl(courses: courses, selection: courseBinding)
            }
        }
    }

    private var recorderCard: some View {
        GlassCard {
            VStack(spacing: 22) {
                Button {
                    switch viewModel.phase {
                    case .idle:
                        startRecording()
                    case .recording, .paused:
                        stopRecording()
                    case .processing, .completed:
                        break
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(recordingTint.opacity(0.13))
                            .frame(width: 146, height: 146)
                        Circle()
                            .stroke(PrepPilotTheme.recordingGradient, lineWidth: 2.5)
                            .frame(width: 138, height: 138)
                            .scaleEffect(viewModel.phase == .recording ? 1.08 : 1)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.phase == .recording)
                        Image(systemName: iconName)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(PrepPilotTheme.recordingGradient)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(viewModel.phase == .idle ? "Start recording" : "Stop recording")
                Text(PrepPilotFormatters.durationString(viewModel.recorder.duration)).font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                RecordingFlowWaveformView(levels: viewModel.recorder.powerLevels, isPaused: viewModel.phase == .paused).frame(height: 86)
                Text(statusText).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            switch viewModel.phase {
            case .idle:
                PrimaryActionButton(title: "Start Recording", systemImage: "mic.fill") { startRecording() }
                    .disabled(!canStartRecording)
            case .recording, .paused:
                HStack(spacing: 12) {
                    PrimaryActionButton(title: viewModel.phase == .paused ? "Resume" : "Pause", systemImage: viewModel.phase == .paused ? "play.fill" : "pause.fill") {
                        viewModel.pauseOrResume()
                    }
                    PrimaryActionButton(title: "Finish", systemImage: "stop.fill") {
                        stopRecording()
                    }
                }
            case .processing:
                PrimaryActionButton(title: "Processing", systemImage: "sparkles", isLoading: true) {}
            case .completed:
                PrimaryActionButton(title: "Open Lecture", systemImage: "arrow.right") { if let id = viewModel.generatedLectureID { path.append(AppRoute.lecture(id)) } }
            }
        }
    }

    private func startRecording() {
        guard !isLectureTitleMissing else {
            viewModel.errorMessage = "Name the lecture before recording."
            Haptics.warning()
            return
        }
        guard !isCourseSelectionMissing else {
            viewModel.errorMessage = "Choose or type a class before recording."
            Haptics.warning()
            return
        }
        Task { await viewModel.start() }
    }

    private func stopRecording() {
        Task {
            if let id = await viewModel.stopAndSave(in: modelContext) {
                path.append(AppRoute.lecture(id))
            }
        }
    }

    private var recordingTint: Color { switch viewModel.phase { case .recording: return PrepPilotTheme.recordingRed; case .paused: return PrepPilotTheme.recordingPaused; case .processing: return .indigo; default: return .teal } }
    private var iconName: String { switch viewModel.phase { case .recording: return "mic.fill"; case .paused: return "pause.fill"; case .processing: return "sparkles"; case .completed: return "checkmark"; case .idle: return "mic" } }
    private var statusText: String { switch viewModel.phase { case .idle: return "Ready to record"; case .recording: return "Recording"; case .paused: return "Paused"; case .processing(let message): return message; case .completed: return "Saved" } }
}

struct ImportNotesView: View {
    @Binding var path: NavigationPath
    let aiService: StudyAIProviding
    @Environment(\.modelContext) private var modelContext
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @State private var viewModel = NoteImportViewModel()

    private var courses: [CourseClass] {
        CourseCatalogStorage.decode(courseClassesData).sorted { $0.displayTitle < $1.displayTitle }
    }

    private var isCourseSelectionMissing: Bool {
        viewModel.course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isLectureTitleMissing: Bool {
        viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canCreateMaterials: Bool {
        viewModel.canImport && !imageAttachments.contains { $0.isProcessing } && !isCourseSelectionMissing && !isLectureTitleMissing
    }

    @State private var isShowingFileImporter = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var imageAttachments: [NoteImageAttachment] = []
    @State private var isShowingCamera = false

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 18) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Upload Notes", systemImage: "doc.badge.plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(PrepPilotTheme.studyGradient)
                            Text("Paste your notes or import a text file. PrepPilot will generate the same notes, cards, quiz, and study guide you get from a recording.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    GlassCard {
                        VStack(spacing: 12) {
                            TextField("Lecture title", text: $viewModel.title)
                                .textInputAutocapitalization(.words)
                                .font(.headline)
                                .padding(12)
                                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                            courseSelectionControl
                        }
                    }

                    uploadActionsCard
                    StudyGenerationSettingsCard(preferences: Binding(get: {
                        viewModel.preferences
                    }, set: { newValue in
                        viewModel.preferences = newValue
                    }))

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Extracted and Pasted Text")
                                .font(.headline)
                            TextEditor(text: $viewModel.notesText)
                                .font(.body)
                                .frame(minHeight: 280)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                                .overlay(alignment: .topLeading) {
                                    if viewModel.notesText.isEmpty {
                                        Text("Paste notes here, or add photos and PrepPilot will extract readable text.")
                                            .font(.body)
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }
                    }

                    PrimaryActionButton(title: viewModel.isImporting ? "Creating" : "Create", systemImage: "sparkles", isLoading: viewModel.isImporting) {
                        createMaterials()
                    }
                    .disabled(!canCreateMaterials)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("Upload Notes")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.text, .plainText]) { result in
            loadImportedFile(result)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await loadPhotoItems(newItems) }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                Task { await addImageAttachment(image) }
            }
        }
        .overlay {
            if viewModel.isImporting {
                Color.black.opacity(0.18).ignoresSafeArea()
                LoadingStateView(message: "Creating study materials").padding()
            }
        }
    }

    @ViewBuilder private var courseSelectionControl: some View {
        if courses.isEmpty {
            TextField("Course or class", text: $viewModel.course)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        } else {
            CoursePickerControl(courses: courses, selection: $viewModel.course)
        }
    }

    private var generationSettingsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Study Material Settings", systemImage: "slider.horizontal.3")
                    .font(.headline)

                Stepper(value: Binding(get: {
                    viewModel.preferences.flashcardCount
                }, set: { newValue in
                    viewModel.preferences.flashcardCount = newValue
                }), in: 4...30) {
                    settingsRow(title: "Flashcards", value: "\(viewModel.preferences.flashcardCount)", symbol: "rectangle.on.rectangle")
                }

                Stepper(value: Binding(get: {
                    viewModel.preferences.quizQuestionCount
                }, set: { newValue in
                    viewModel.preferences.quizQuestionCount = newValue
                }), in: 3...25) {
                    settingsRow(title: "Quiz questions", value: "\(viewModel.preferences.quizQuestionCount)", symbol: "checklist")
                }

                Divider().opacity(0.45)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Quiz Structure")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(QuizQuestionKind.allCases) { kind in
                            Toggle(kind.title, isOn: Binding(get: {
                                viewModel.preferences.quizKinds.contains(kind)
                            }, set: { isOn in
                                updateQuizKind(kind, isSelected: isOn)
                            }))
                            .font(.subheadline.weight(.semibold))
                            .tint(.indigo)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func settingsRow(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.indigo)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    private func updateQuizKind(_ kind: QuizQuestionKind, isSelected: Bool) {
        var kinds = Set(viewModel.preferences.quizKinds)
        if isSelected {
            kinds.insert(kind)
        } else if kinds.count > 1 {
            kinds.remove(kind)
        } else {
            Haptics.warning()
        }
        viewModel.preferences.quizKinds = QuizQuestionKind.allCases.filter { kinds.contains($0) }
    }

    private func createMaterials() {
        guard !isLectureTitleMissing else {
            viewModel.errorMessage = "Name the lecture before creating materials."
            Haptics.warning()
            return
        }
        guard !isCourseSelectionMissing else {
            viewModel.errorMessage = "Choose or type a class before creating materials."
            Haptics.warning()
            return
        }
        Task {
            if let id = await viewModel.importNotes(in: modelContext, aiService: aiService) {
                path.append(AppRoute.lecture(id))
            }
        }
    }

    private var uploadActionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Add Notes", systemImage: "plus.circle")
                        .font(.headline)
                    Spacer()
                    if imageAttachments.contains(where: { $0.isProcessing }) {
                        ProgressView()
                    }
                }

                HStack(spacing: 10) {
                    CompactGradientButton(title: "Camera", systemImage: "camera") {
                        openCamera()
                    }

                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 0, matching: .images) {
                        Label("Photos", systemImage: "photo.on.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background(PrepPilotTheme.studyGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(PressableButtonStyle())

                    CompactGradientButton(title: "File", systemImage: "folder") {
                        isShowingFileImporter = true
                    }
                }

                if !imageAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(imageAttachments) { attachment in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: attachment.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 76, height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                    if attachment.isProcessing {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(.black.opacity(0.28))
                                            ProgressView()
                                                .tint(.white)
                                        }
                                        .frame(width: 76, height: 76)
                                    } else if attachment.recognizedText.isEmpty {
                                        Image(systemName: "text.magnifyingglass")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(.orange, in: Circle())
                                            .padding(5)
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(.green, in: Circle())
                                            .padding(5)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Text("Photo selection has no app-side limit. PrepPilot extracts readable text from each image and sends that text into the study-material generator.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            viewModel.errorMessage = "Camera is not available on this device."
            return
        }
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else {
            viewModel.errorMessage = "Missing NSCameraUsageDescription in the app target. Add a camera privacy description in Target > Info before taking note photos."
            return
        }
        isShowingCamera = true
    }

    private func loadPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        viewModel.errorMessage = nil

        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await addImageAttachment(image)
                }
            } catch {
                viewModel.errorMessage = "One or more photos could not be loaded."
            }
        }

        selectedPhotoItems = []
    }

    private func addImageAttachment(_ image: UIImage) async {
        let attachment = NoteImageAttachment(image: image)
        imageAttachments.append(attachment)
        let recognizedText = await ImageTextExtractor.recognizedText(from: image)

        if let index = imageAttachments.firstIndex(where: { $0.id == attachment.id }) {
            imageAttachments[index].recognizedText = recognizedText
            imageAttachments[index].isProcessing = false
        }

        if recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.errorMessage = "One image did not contain readable text. You can keep uploading more images or paste notes manually."
        } else {
            appendRecognizedText(recognizedText)
            viewModel.errorMessage = nil
            Haptics.light()
        }
    }

    private func appendRecognizedText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        if viewModel.notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            viewModel.notesText = trimmedText
        } else {
            viewModel.notesText += "\n\n" + trimmedText
        }
    }

    private func loadImportedFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            viewModel.notesText = try String(contentsOf: url, encoding: .utf8)
            if viewModel.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.title = url.deletingPathExtension().lastPathComponent
            }
            viewModel.errorMessage = nil
            Haptics.light()
        } catch {
            viewModel.errorMessage = "Could not import that file. Use a plain text note file or paste the notes directly."
        }
    }
}

#if canImport(UIKit)
private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

struct TranscriptView: View {
    let lectureID: UUID
    @Query private var lectures: [Lecture]
    private var lecture: Lecture? { lectures.first { $0.id == lectureID } }

    var body: some View {
        PremiumBackground { if let lecture { TranscriptEditor(lecture: lecture) } else { EmptyStateView(systemImage: "text.quote", title: "Transcript not found", message: "This lecture transcript is unavailable.") } }
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TranscriptEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var lecture: Lecture

    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) { GlassCard { VStack(alignment: .leading, spacing: 8) { Text(lecture.title).font(.title2.weight(.bold)); Text("\(PrepPilotFormatters.durationString(lecture.duration)) • \(PrepPilotFormatters.shortDate.string(from: lecture.createdAt))").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }; GlassCard { VStack(alignment: .leading, spacing: 12) { Text("Editable Transcript").font(.headline); TextEditor(text: $lecture.transcript).font(.body).frame(minHeight: 360).scrollContentBackground(.hidden).padding(8).background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)) } } }.padding(.vertical, 18).padding(.horizontal) }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .onDisappear { lecture.updatedAt = .now; try? modelContext.save() }
    }
}

struct NotesView: View {
    let lectureID: UUID
    @Query private var notes: [LectureNote]
    private var note: LectureNote? { notes.first { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground { if let note { NoteEditorView(note: note) } else { EmptyStateView(systemImage: "doc.text.magnifyingglass", title: "No notes yet", message: "Generate notes from the transcript after recording or paste lecture content into the transcript view.") } }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: LectureNote

    var body: some View {
        ScrollView { VStack(spacing: 16) { section("Concise Summary", text: $note.conciseSummary, minHeight: 110); section("Detailed Notes", text: $note.detailedNotes, minHeight: 230); section("Key Takeaways", text: $note.keyTakeaways, minHeight: 160); section("Vocabulary", text: $note.vocabularyTerms, minHeight: 160); section("Important Concepts", text: $note.importantConcepts, minHeight: 130) }.padding(.vertical, 18).padding(.horizontal) }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .onDisappear { note.updatedAt = .now; try? modelContext.save() }
    }

    private func section(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        GlassCard { VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); TextEditor(text: text).font(.body).frame(minHeight: minHeight).scrollContentBackground(.hidden).padding(8).background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)) } }
    }
}

struct StudyGuideView: View {
    let lectureID: UUID
    @Query private var guides: [StudyGuide]
    private var guide: StudyGuide? { guides.first { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground {
            if let guide {
                ScrollView { VStack(spacing: 16) { guideSection("Exam Review", symbol: "graduationcap", content: guide.examReview, tint: .indigo); guideSection("Topic Summaries", symbol: "list.bullet.rectangle", content: guide.topicSummaries, tint: .teal); guideSection("Important Concepts", symbol: "star.square", content: guide.importantConcepts, tint: .pink); guideSection("Key Definitions", symbol: "text.book.closed", content: guide.keyDefinitions, tint: .orange) }.padding(.vertical, 18).padding(.horizontal) }
            } else { EmptyStateView(systemImage: "book.closed", title: "No study guide", message: "A guide will appear after the lecture transcript is processed.") }
        }
        .navigationTitle(guide?.title ?? "Study Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func guideSection(_ title: String, symbol: String, content: String, tint: Color) -> some View {
        GlassCard { VStack(alignment: .leading, spacing: 12) { Label(title, systemImage: symbol).font(.headline).foregroundStyle(tint); Text(content).font(.body).foregroundStyle(content.isEmpty ? .secondary : .primary).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading) }
    }
}

struct FlashcardView: View {
    let lectureID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flashcard.createdAt, order: .forward) private var allCards: [Flashcard]
    @State private var study = FlashcardStudyViewModel()
    private var cards: [Flashcard] { allCards.filter { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground {
            if cards.isEmpty { EmptyStateView(systemImage: "rectangle.on.rectangle", title: "No flashcards", message: "Flashcards are generated after a transcript and notes are available.") }
            else { VStack(spacing: 20) { progressHeader; cardStack; ratingControls; navigationControls }.padding(.vertical, 20).padding(.horizontal) }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .task { study.resetIfNeeded(total: cards.count) }
        .onChange(of: cards.count) { _, newValue in study.resetIfNeeded(total: newValue) }
    }

    private var currentCard: Flashcard { cards[study.currentIndex] }

    private var progressHeader: some View {
        GlassCard { VStack(spacing: 12) { HStack { Text("Card \(study.currentIndex + 1) of \(cards.count)").font(.headline); Spacer(); masteryStars(currentCard.mastery) }; ProgressView(value: Double(study.currentIndex + 1), total: Double(cards.count)).tint(.indigo) } }
    }

    private var cardStack: some View {
        Button { withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { study.flip() } } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous).fill(.regularMaterial).shadow(color: .black.opacity(0.10), radius: 24, y: 12)
                VStack(spacing: 18) { Label(study.isShowingBack ? "Answer" : "Question", systemImage: study.isShowingBack ? "checkmark.seal" : "questionmark.circle").font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(.secondary); Text(study.isShowingBack ? currentCard.back : currentCard.front).font(.title3.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.center).minimumScaleFactor(0.8).contentTransition(.opacity); Text("Tap to flip").font(.footnote.weight(.medium)).foregroundStyle(.secondary) }.padding(28)
            }
            .frame(maxWidth: .infinity).frame(height: 360)
        }
        .buttonStyle(.plain)
        .gesture(DragGesture().onEnded { value in withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { if value.translation.width < -48 { study.moveForward(total: cards.count) } else if value.translation.width > 48 { study.moveBackward() } else { study.flip() } } })
    }

    private var ratingControls: some View {
        HStack(spacing: 12) {
            Button { study.mark(currentCard, masteryDelta: -1, context: modelContext); withAnimation { study.moveForward(total: cards.count) } } label: { Label("Needs Work", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
            Button { study.mark(currentCard, masteryDelta: 1, context: modelContext); withAnimation { study.moveForward(total: cards.count) } } label: { Label("Know", systemImage: "checkmark").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 12) { ToolbarIconButton(systemImage: "chevron.left", title: "Previous") { withAnimation { study.moveBackward() } }; Spacer(); Button("Flip Card") { withAnimation { study.flip() } }.font(.headline); Spacer(); ToolbarIconButton(systemImage: "chevron.right", title: "Next") { withAnimation { study.moveForward(total: cards.count) } } }
    }

    private func masteryStars(_ mastery: Int) -> some View {
        HStack(spacing: 2) { ForEach(0..<5, id: \.self) { index in Image(systemName: index < mastery ? "star.fill" : "star").font(.caption).foregroundStyle(index < mastery ? .yellow : .secondary) } }
    }
}

struct QuizView: View {
    let lectureID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]
    @Query(sort: \QuizQuestion.createdAt, order: .forward) private var allQuestions: [QuizQuestion]
    @State private var session = QuizSessionViewModel()
    private var quiz: Quiz? { quizzes.first { $0.lectureID == lectureID } }
    private var questions: [QuizQuestion] { guard let quiz else { return [] }; return allQuestions.filter { $0.quizID == quiz.id } }

    var body: some View {
        PremiumBackground {
            if let quiz, !questions.isEmpty { ScrollView { VStack(spacing: 16) { quizHeader(quiz); gradingControls; ForEach(questions) { questionCard($0) }; submitControls(quiz) }.padding(.vertical, 18).padding(.horizontal) }.scrollDismissesKeyboard(.interactively).dismissKeyboardOnTap() }
            else { EmptyStateView(systemImage: "checklist", title: "No quiz yet", message: "A quiz will appear after PrepPilot processes lecture notes.") }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func quizHeader(_ quiz: Quiz) -> some View {
        GlassCard { VStack(alignment: .leading, spacing: 12) { HStack { VStack(alignment: .leading, spacing: 4) { Text(quiz.title).font(.title2.weight(.bold)); Text("\(questions.count) questions • \(quiz.attemptCount) attempts").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); if session.isSubmitted { Text(session.scoreText(for: questions)).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(.indigo) } }; if quiz.attemptCount > 0 { ProgressView(value: quiz.lastScore).tint(.teal) } } }
    }

    private var gradingControls: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Written Answer Grading", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Picker("Written answer grading", selection: Binding(get: {
                    session.gradingStrictness
                }, set: { newValue in
                    session.gradingStrictness = newValue
                })) {
                    ForEach(GradingStrictness.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(session.isSubmitted)
                Text("Easy accepts broader wording. Hard requires more key terms from the answer key.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func questionCard(_ question: QuizQuestion) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text(question.kind.title).font(.caption.weight(.bold)).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); if session.isSubmitted { Image(systemName: session.isCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(session.isCorrect(question) ? .green : .red) } }
                Text(question.prompt).font(.headline).fixedSize(horizontal: false, vertical: true)
                switch question.kind {
                case .multipleChoice, .trueFalse, .matching:
                    VStack(spacing: 8) { ForEach(question.options, id: \.self) { optionButton($0, for: question) } }
                case .shortAnswer:
                    TextField("Your answer", text: Binding(get: { session.answers[question.id] ?? "" }, set: { session.answers[question.id] = $0 }), axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...4).disabled(session.isSubmitted)
                }
                if session.isSubmitted { VStack(alignment: .leading, spacing: 6) { Text("Correct answer").font(.caption.weight(.bold)).foregroundStyle(.secondary); Text(question.correctAnswer).font(.subheadline.weight(.semibold)); Text(question.explanation).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }.padding(12).background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)) }
            }
        }
    }

    private func optionButton(_ option: String, for question: QuizQuestion) -> some View {
        let selected = session.answers[question.id] == option
        let correct = option.caseInsensitiveCompare(question.correctAnswer) == .orderedSame
        let tint: Color = session.isSubmitted ? (correct ? .green : (selected ? .red : .secondary)) : (selected ? .indigo : .secondary)
        return Button { session.answer(question, with: option) } label: { HStack { Image(systemName: selected ? "largecircle.fill.circle" : "circle").foregroundStyle(tint); Text(option).foregroundStyle(.primary).multilineTextAlignment(.leading); Spacer() }.padding(12).background(tint.opacity((selected || (correct && session.isSubmitted)) ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)) }.buttonStyle(.plain).disabled(session.isSubmitted)
    }

    @ViewBuilder private func submitControls(_ quiz: Quiz) -> some View {
        if session.isSubmitted { Button { session.reset() } label: { Label("Try Again", systemImage: "arrow.clockwise").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 52) }.buttonStyle(.bordered).controlSize(.large) }
        else { PrimaryActionButton(title: "Submit Quiz", systemImage: "checkmark.seal") { session.submit(quiz: quiz, questions: questions, context: modelContext) }.disabled(questions.contains { (session.answers[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) }
    }
}

struct AIChatView: View {
    let lectureID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LectureNote.createdAt, order: .forward) private var notes: [LectureNote]
    @Query(sort: \AIChatMessage.createdAt, order: .forward) private var allMessages: [AIChatMessage]
    @State private var viewModel: ChatViewModel

    init(lectureID: UUID, aiService: StudyAIProviding) {
        self.lectureID = lectureID
        _viewModel = State(initialValue: ChatViewModel(aiService: aiService))
    }

    private var lectureNotes: [LectureNote] { notes.filter { $0.lectureID == lectureID } }
    private var messages: [AIChatMessage] { allMessages.filter { $0.lectureID == lectureID } }
    private var noteContext: String { lectureNotes.map { [$0.title, $0.conciseSummary, $0.keyTakeaways, $0.detailedNotes, $0.vocabularyTerms, $0.importantConcepts].filter { !$0.isEmpty }.joined(separator: "\n") }.joined(separator: "\n") }

    var body: some View {
        PremiumBackground {
            VStack(spacing: 0) { messagesView; inputBar }
        }
        .navigationTitle("Ask AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty { EmptyStateView(systemImage: "bubble.left.and.sparkles", title: "Ask about this lecture", message: "Answers are constrained to the generated notes and transcript context.") }
                    ForEach(messages) { MessageBubble(message: $0).id($0.id) }
                    if viewModel.isResponding { HStack { LoadingStateView(message: "Reading notes").scaleEffect(0.86); Spacer() }.padding(.horizontal) }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .onChange(of: messages.count) { _, _ in if let last = messages.last { withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) { proxy.scrollTo(last.id, anchor: .bottom) } } }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about notes", text: $viewModel.draft, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...4).disabled(viewModel.isResponding)
                Button { Task { await viewModel.send(lectureID: lectureID, noteContext: noteContext, context: modelContext) } } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 34, weight: .semibold)) }.disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isResponding).accessibilityLabel("Send")
            }
        }
        .padding(12)
        .background(.regularMaterial)
    }
}

private struct MessageBubble: View {
    let message: AIChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user { Spacer(minLength: 44) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                Text(message.content).font(.body).foregroundStyle(message.role == .user ? .white : .primary).fixedSize(horizontal: false, vertical: true)
                if message.role == .assistant, !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) { Text("Sources").font(.caption.weight(.bold)).foregroundStyle(.secondary); ForEach(message.sources, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }
                        .padding(10)
                        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                }
            }
            .padding(14)
            .background { bubbleBackground }
            .frame(maxWidth: 330, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 44) }
        }
        .padding(.horizontal)
    }

    @ViewBuilder private var bubbleBackground: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous).fill(Color.indigo.gradient)
        } else {
            RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous).fill(.regularMaterial)
        }
    }
}

struct SearchView: View {
    @Binding var path: NavigationPath
    @AppStorage("courseClassesData") private var courseClassesData = ""
    @State private var viewModel = SearchViewModel()
    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query private var notes: [LectureNote]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]
    @Query private var guides: [StudyGuide]

    private var results: [SearchResult] { viewModel.results(lectures: lectures, notes: notes, flashcards: flashcards, quizzes: quizzes, guides: guides) }
    private var courses: [CourseClass] { CourseCatalogStorage.decode(courseClassesData) }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { recentSearchContent }
                    else if results.isEmpty { EmptyStateView(systemImage: "magnifyingglass", title: "No matches", message: "Try a lecture title, course, concept, flashcard answer, or quiz topic.") }
                    else { VStack(spacing: 10) { ForEach(results) { result in Button { path.append(result.route) } label: { SearchResultRow(result: result) }.buttonStyle(.plain) } } }
                }
                .padding(.vertical, 18)
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search lectures, notes, cards")
    }

    private var recentSearchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard { VStack(alignment: .leading, spacing: 10) { Label("Search everything", systemImage: "magnifyingglass").font(.headline); Text("Find lectures, notes, flashcards, quizzes, and study guides from one place.").font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading) }
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Lectures").font(.headline)
                if lectures.isEmpty { EmptyStateView(systemImage: "waveform", title: "Nothing to search yet", message: "Record a lecture to build your searchable study library.") }
                else { ForEach(Array(lectures.prefix(5))) { lecture in Button { path.append(AppRoute.lecture(lecture.id)) } label: { LectureRow(lecture: lecture, noteCount: notes.filter { $0.lectureID == lecture.id }.count, cardCount: flashcards.filter { $0.lectureID == lecture.id }.count, quizCount: quizzes.filter { $0.lectureID == lecture.id }.count, course: courseForLecture(lecture)) }.buttonStyle(.plain) } }
            }
        }
    }

    private func courseForLecture(_ lecture: Lecture) -> CourseClass? {
        CourseCatalogStorage.course(matching: lecture.course, in: courses)
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.symbolName).font(.headline).foregroundStyle(.indigo).frame(width: 38, height: 38).background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 4) { Text(result.title).font(.headline).foregroundStyle(.primary).lineLimit(1); Text(result.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
        .modelContainer(for: PrepPilotSchema.models, inMemory: true)
}
