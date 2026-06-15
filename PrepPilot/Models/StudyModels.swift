import Foundation
import SwiftData

enum LectureStatus: String, Codable, CaseIterable {
    case recording
    case transcribing
    case generating
    case ready
    case archived
}

public enum QuizQuestionKind: String, Codable, CaseIterable {
    case multipleChoice
    case trueFalse
    case shortAnswer

    var title: String {
        switch self {
        case .multipleChoice: "Multiple choice"
        case .trueFalse: "True or false"
        case .shortAnswer: "Short answer"
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

    init(
        id: UUID = UUID(),
        lectureID: UUID,
        front: String,
        back: String,
        mastery: Int = 0,
        lastStudiedAt: Date? = nil
    ) {
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

    init(
        id: UUID = UUID(),
        lectureID: UUID? = nil,
        dueDate: Date,
        title: String,
        subtitle: String,
        kind: StudyTaskKind,
        isComplete: Bool = false
    ) {
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
