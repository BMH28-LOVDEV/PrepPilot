import SwiftData
import SwiftUI

struct TranscriptView: View {
    let lectureID: UUID
    @Query private var lectures: [Lecture]

    private var lecture: Lecture? { lectures.first { $0.id == lectureID } }

    var body: some View {
        PremiumBackground {
            if let lecture {
                TranscriptEditor(lecture: lecture)
            } else {
                EmptyStateView(systemImage: "text.quote", title: "Transcript not found", message: "This lecture transcript is unavailable.")
            }
        }
        .navigationTitle("Transcript")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TranscriptEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var lecture: Lecture

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lecture.title)
                            .font(.title2.weight(.bold))
                        Text("\(PrepPilotFormatters.durationString(lecture.duration)) • \(PrepPilotFormatters.shortDate.string(from: lecture.createdAt))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Editable Transcript")
                            .font(.headline)
                        TextEditor(text: $lecture.transcript)
                            .font(.body)
                            .frame(minHeight: 360)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal)
        }
        .onDisappear {
            lecture.updatedAt = .now
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack {
        TranscriptView(lectureID: PreviewData.lectureID)
    }
    .modelContainer(PreviewData.container)
}
