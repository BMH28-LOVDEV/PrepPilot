import SwiftData
import SwiftUI

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
    private var noteContext: String {
        lectureNotes.map { note in
            [note.title, note.conciseSummary, note.keyTakeaways, note.detailedNotes, note.vocabularyTerms, note.importantConcepts]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        .joined(separator: "\n")
    }

    var body: some View {
        PremiumBackground {
            VStack(spacing: 0) {
                messagesView
                inputBar
            }
        }
        .navigationTitle("Ask AI")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        EmptyStateView(systemImage: "bubble.left.and.sparkles", title: "Ask about this lecture", message: "Answers are constrained to the generated notes and transcript context.")
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isResponding {
                        HStack {
                            LoadingStateView(message: "Reading notes")
                                .scaleEffect(0.86)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about notes", text: $viewModel.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .disabled(viewModel.isResponding)

                Button {
                    Task {
                        await viewModel.send(lectureID: lectureID, noteContext: noteContext, context: modelContext)
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                }
                .disabled(viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isResponding)
                .accessibilityLabel("Send")
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
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                if message.role == .assistant, !message.sources.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sources")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        ForEach(message.sources, id: \.self) { source in
                            Text(source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                }
            }
            .padding(14)
            .background(message.role == .user ? Color.indigo.gradient : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            .frame(maxWidth: 330, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer(minLength: 44) }
        }
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        AIChatView(lectureID: PreviewData.lectureID, aiService: AppEnvironment().aiService)
    }
    .modelContainer(PreviewData.container)
}
