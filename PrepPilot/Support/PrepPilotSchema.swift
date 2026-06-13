import SwiftData

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
