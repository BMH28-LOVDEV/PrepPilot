import Foundation
import Observation
import Speech
import SwiftData

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
    var errorMessage: String?
    var generatedLectureID: UUID?
    var speechAuthorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let speechService: SpeechTranscribing
    private let aiService: StudyAIProviding

    init(speechService: SpeechTranscribing, aiService: StudyAIProviding) {
        self.speechService = speechService
        self.aiService = aiService
    }

    var isBusy: Bool {
        if case .processing = phase { return true }
        return false
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New Lecture" : trimmed
    }

    func start() async {
        errorMessage = nil
        do {
            speechAuthorizationStatus = await speechService.requestAuthorization()
            try await recorder.start()
            phase = .recording
            Haptics.medium()
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
        case .paused:
            recorder.resume()
            phase = .recording
        default:
            break
        }
    }

    func stopAndSave(in context: ModelContext) async -> UUID? {
        guard phase == .recording || phase == .paused else { return nil }
        errorMessage = nil

        do {
            let result = try recorder.stop()
            phase = .processing("Transcribing lecture")
            let transcript = await transcriptText(for: result.url)

            let lecture = Lecture(
                title: displayTitle,
                course: course.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: result.duration,
                audioFileName: result.url.lastPathComponent,
                transcript: transcript,
                status: .generating,
                accentName: ["indigo", "teal", "coral", "amber", "blue"].randomElement() ?? "indigo"
            )
            context.insert(lecture)
            try context.save()

            phase = .processing("Generating notes")
            let notes = try await aiService.generateNotes(from: transcript, lectureTitle: lecture.title)
            context.insert(LectureNote(
                lectureID: lecture.id,
                title: notes.title,
                detailedNotes: notes.detailedNotes,
                conciseSummary: notes.conciseSummary,
                keyTakeaways: notes.keyTakeaways,
                vocabularyTerms: notes.vocabularyTerms,
                importantConcepts: notes.importantConcepts
            ))

            phase = .processing("Building flashcards")
            let cards = try await aiService.generateFlashcards(from: transcript, notes: notes)
            cards.forEach { card in
                context.insert(Flashcard(lectureID: lecture.id, front: card.front, back: card.back))
            }

            phase = .processing("Creating quiz")
            let generatedQuiz = try await aiService.generateQuiz(from: transcript, notes: notes)
            let quiz = Quiz(lectureID: lecture.id, title: generatedQuiz.title)
            context.insert(quiz)
            generatedQuiz.questions.forEach { question in
                context.insert(QuizQuestion(
                    quizID: quiz.id,
                    kind: question.kind,
                    prompt: question.prompt,
                    options: question.options,
                    correctAnswer: question.correctAnswer,
                    explanation: question.explanation
                ))
            }

            phase = .processing("Preparing study guide")
            let guide = try await aiService.generateStudyGuide(from: transcript, notes: notes)
            context.insert(StudyGuide(
                lectureID: lecture.id,
                title: guide.title,
                examReview: guide.examReview,
                topicSummaries: guide.topicSummaries,
                importantConcepts: guide.importantConcepts,
                keyDefinitions: guide.keyDefinitions
            ))

            context.insert(StudyTask(
                lectureID: lecture.id,
                dueDate: .now.addingTimeInterval(86_400),
                title: "Review \(lecture.title)",
                subtitle: lecture.course.isEmpty ? "New lecture" : lecture.course,
                kind: .flashcards
            ))

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
}
