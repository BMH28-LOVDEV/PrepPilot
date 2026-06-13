import Foundation
import SwiftData

enum PreviewData {
    static let lectureID = UUID()
    static let quizID = UUID()

    @MainActor
    static var container: ModelContainer = {
        let schema = Schema(PrepPilotSchema.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            seed(container.mainContext)
            return container
        } catch {
            fatalError("Unable to create preview container: \(error)")
        }
    }()

    @MainActor
    static func seed(_ context: ModelContext) {
        let lecture = Lecture(
            id: lectureID,
            title: "Cellular Respiration Review",
            course: "Biology 201",
            createdAt: .now.addingTimeInterval(-3600 * 18),
            duration: 4380,
            transcript: sampleTranscript,
            status: .ready,
            isFavorite: true,
            accentName: "teal"
        )
        context.insert(lecture)

        let note = LectureNote(
            lectureID: lectureID,
            title: "Cellular Respiration Notes",
            detailedNotes: "Glycolysis begins in the cytosol and produces pyruvate, ATP, and NADH. The Krebs cycle continues in the mitochondrial matrix, generating electron carriers that drive oxidative phosphorylation.",
            conciseSummary: "Cells convert glucose into ATP through glycolysis, the Krebs cycle, and oxidative phosphorylation.",
            keyTakeaways: "ATP yield depends on oxygen availability.\nNADH and FADH2 carry electrons to the transport chain.\nThe proton gradient powers ATP synthase.",
            vocabularyTerms: "Glycolysis: glucose splitting pathway.\nChemiosmosis: ATP generation from proton movement.\nOxidative phosphorylation: ATP production using electron transport.",
            importantConcepts: "Energy transfer, redox reactions, mitochondria structure, proton gradients"
        )
        context.insert(note)

        for card in sampleFlashcards {
            context.insert(Flashcard(lectureID: lectureID, front: card.0, back: card.1, mastery: card.2))
        }

        let quiz = Quiz(id: quizID, lectureID: lectureID, title: "Respiration Checkpoint", lastScore: 0.82, attemptCount: 2)
        context.insert(quiz)
        context.insert(QuizQuestion(quizID: quizID, kind: .multipleChoice, prompt: "Where does glycolysis occur?", options: ["Cytosol", "Mitochondrial matrix", "Nucleus", "Golgi apparatus"], correctAnswer: "Cytosol", explanation: "Glycolysis happens outside the mitochondria in the cytosol."))
        context.insert(QuizQuestion(quizID: quizID, kind: .trueFalse, prompt: "The electron transport chain creates a proton gradient.", options: ["True", "False"], correctAnswer: "True", explanation: "Electron movement powers proton pumping across the inner mitochondrial membrane."))
        context.insert(QuizQuestion(quizID: quizID, kind: .shortAnswer, prompt: "What molecule powers ATP synthase?", correctAnswer: "A proton gradient", explanation: "ATP synthase converts proton motive force into chemical energy stored in ATP."))

        context.insert(StudyGuide(lectureID: lectureID, title: "Exam Review", examReview: "Focus on each stage of respiration, where it occurs, and what it produces.", topicSummaries: "Glycolysis: cytosol pathway.\nKrebs cycle: matrix pathway.\nElectron transport: membrane pathway.", importantConcepts: "ATP accounting\nElectron carriers\nAerobic versus anaerobic conditions", keyDefinitions: "ATP synthase: enzyme that produces ATP.\nNADH: reduced electron carrier."))
        context.insert(StudyTask(lectureID: lectureID, dueDate: .now.addingTimeInterval(86400), title: "Review flashcards", subtitle: "Biology 201", kind: .flashcards))
        context.insert(AIChatMessage(lectureID: lectureID, role: .assistant, content: "Ask a question about this lecture and I will stay grounded in your notes.", sources: ["Cellular Respiration Notes"]))
    }

    static let sampleTranscript = "Today we covered cellular respiration, beginning with glycolysis in the cytosol. Glycolysis breaks glucose into pyruvate and produces a small amount of ATP and NADH. In aerobic conditions pyruvate enters the mitochondria for the Krebs cycle, producing additional electron carriers. The electron transport chain uses those carriers to build a proton gradient, and ATP synthase uses that gradient to generate ATP."

    static let sampleFlashcards: [(String, String, Int)] = [
        ("Where does glycolysis occur?", "In the cytosol.", 2),
        ("What does ATP synthase use to make ATP?", "A proton gradient across the inner mitochondrial membrane.", 1),
        ("What are NADH and FADH2?", "Electron carriers that deliver high-energy electrons to the electron transport chain.", 3)
    ]
}
