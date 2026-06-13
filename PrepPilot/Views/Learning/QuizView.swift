import SwiftData
import SwiftUI

struct QuizView: View {
    let lectureID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]
    @Query(sort: \QuizQuestion.createdAt, order: .forward) private var allQuestions: [QuizQuestion]
    @State private var session = QuizSessionViewModel()

    private var quiz: Quiz? { quizzes.first { $0.lectureID == lectureID } }
    private var questions: [QuizQuestion] {
        guard let quiz else { return [] }
        return allQuestions.filter { $0.quizID == quiz.id }
    }

    var body: some View {
        PremiumBackground {
            if let quiz, !questions.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        quizHeader(quiz)
                        ForEach(questions) { question in
                            questionCard(question)
                        }
                        submitControls(quiz)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal)
                }
            } else {
                EmptyStateView(systemImage: "checklist", title: "No quiz yet", message: "A quiz will appear after PrepPilot processes lecture notes.")
            }
        }
        .navigationTitle("Quiz")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func quizHeader(_ quiz: Quiz) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quiz.title)
                            .font(.title2.weight(.bold))
                        Text("\(questions.count) questions • \(quiz.attemptCount) attempts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if session.isSubmitted {
                        Text(session.scoreText(for: questions))
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.indigo)
                    }
                }
                if quiz.attemptCount > 0 {
                    ProgressView(value: quiz.lastScore)
                        .tint(.teal)
                }
            }
        }
    }

    private func questionCard(_ question: QuizQuestion) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(question.kind.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    if session.isSubmitted {
                        Image(systemName: session.isCorrect(question) ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(session.isCorrect(question) ? .green : .red)
                    }
                }

                Text(question.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                switch question.kind {
                case .multipleChoice, .trueFalse:
                    VStack(spacing: 8) {
                        ForEach(question.options, id: \.self) { option in
                            optionButton(option, for: question)
                        }
                    }
                case .shortAnswer:
                    TextField("Your answer", text: Binding(
                        get: { session.answers[question.id] ?? "" },
                        set: { session.answers[question.id] = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(session.isSubmitted)
                }

                if session.isSubmitted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Correct answer")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(question.correctAnswer)
                            .font(.subheadline.weight(.semibold))
                        Text(question.explanation)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                }
            }
        }
    }

    private func optionButton(_ option: String, for question: QuizQuestion) -> some View {
        let selected = session.answers[question.id] == option
        let correct = option.caseInsensitiveCompare(question.correctAnswer) == .orderedSame
        let tint: Color = session.isSubmitted ? (correct ? .green : (selected ? .red : .secondary)) : (selected ? .indigo : .secondary)

        return Button {
            session.answer(question, with: option)
        } label: {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(tint)
                Text(option)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(12)
            .background(tint.opacity(selected || correct && session.isSubmitted ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(session.isSubmitted)
    }

    private func submitControls(_ quiz: Quiz) -> some View {
        VStack(spacing: 12) {
            if session.isSubmitted {
                Button {
                    session.reset()
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            } else {
                PrimaryActionButton(title: "Submit Quiz", systemImage: "checkmark.seal") {
                    session.submit(quiz: quiz, questions: questions, context: modelContext)
                }
                .disabled(questions.contains { (session.answers[$0.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            }
        }
    }
}

#Preview {
    NavigationStack {
        QuizView(lectureID: PreviewData.lectureID)
    }
    .modelContainer(PreviewData.container)
}
