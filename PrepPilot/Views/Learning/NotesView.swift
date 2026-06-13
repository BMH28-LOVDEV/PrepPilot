import SwiftData
import SwiftUI

struct NotesView: View {
    let lectureID: UUID
    @Query private var notes: [LectureNote]

    private var note: LectureNote? { notes.first { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground {
            if let note {
                NoteEditorView(note: note)
            } else {
                EmptyStateView(systemImage: "doc.text.magnifyingglass", title: "No notes yet", message: "Generate notes from the transcript after recording or paste lecture content into the transcript view.")
            }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: LectureNote

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                editableSection("Concise Summary", text: $note.conciseSummary, minHeight: 110)
                editableSection("Detailed Notes", text: $note.detailedNotes, minHeight: 230)
                editableSection("Key Takeaways", text: $note.keyTakeaways, minHeight: 160)
                editableSection("Vocabulary", text: $note.vocabularyTerms, minHeight: 160)
                editableSection("Important Concepts", text: $note.importantConcepts, minHeight: 130)
            }
            .padding(.vertical, 18)
            .padding(.horizontal)
        }
        .onDisappear {
            note.updatedAt = .now
            try? modelContext.save()
        }
    }

    private func editableSection(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                TextEditor(text: text)
                    .font(.body)
                    .frame(minHeight: minHeight)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotesView(lectureID: PreviewData.lectureID)
    }
    .modelContainer(PreviewData.container)
}
