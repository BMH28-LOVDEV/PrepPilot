import SwiftData
import SwiftUI

struct LectureDetailView: View {
    let lectureID: UUID
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext

    @Query private var lectures: [Lecture]
    @Query private var notes: [LectureNote]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]
    @Query private var guides: [StudyGuide]

    private var lecture: Lecture? { lectures.first { $0.id == lectureID } }

    var body: some View {
        PremiumBackground {
            if let lecture {
                ScrollView {
                    VStack(spacing: 18) {
                        hero(lecture)
                        actionGrid(lecture)
                        transcriptPreview(lecture)
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
                    ToolbarIconButton(systemImage: lecture.isFavorite ? "star.fill" : "star", title: "Favorite", tint: lecture.isFavorite ? .yellow : .primary) {
                        lecture.isFavorite.toggle()
                        lecture.updatedAt = .now
                        try? modelContext.save()
                        Haptics.light()
                    }
                }
            }
        }
    }

    private func hero(_ lecture: Lecture) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "waveform")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(PrepPilotTheme.accent(lecture.accentName))
                        .frame(width: 58, height: 58)
                        .background(PrepPilotTheme.accent(lecture.accentName).opacity(0.14), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(lecture.title)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lecture.course.isEmpty ? PrepPilotFormatters.shortDate.string(from: lecture.createdAt) : lecture.course)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                HStack(spacing: 10) {
                    Label(PrepPilotFormatters.durationString(lecture.duration), systemImage: "clock")
                    Label(lecture.status.rawValue.capitalized, systemImage: "checkmark.seal")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func actionGrid(_ lecture: Lecture) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            DetailActionTile(title: "Transcript", symbol: "text.quote", tint: .blue) { path.append(AppRoute.transcript(lecture.id)) }
            DetailActionTile(title: "Notes", symbol: "doc.text", tint: .indigo) { path.append(AppRoute.notes(lecture.id)) }
            DetailActionTile(title: "Flashcards", symbol: "rectangle.on.rectangle", tint: .teal, badge: "\(flashcards.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.flashcards(lecture.id)) }
            DetailActionTile(title: "Quiz", symbol: "checklist", tint: .pink, badge: "\(quizzes.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.quiz(lecture.id)) }
            DetailActionTile(title: "Study Guide", symbol: "book.closed", tint: .orange, badge: "\(guides.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.studyGuide(lecture.id)) }
            DetailActionTile(title: "Ask AI", symbol: "bubble.left.and.sparkles", tint: .purple, badge: "\(notes.filter { $0.lectureID == lecture.id }.count)") { path.append(AppRoute.chat(lecture.id)) }
        }
    }

    private func transcriptPreview(_ lecture: Lecture) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Transcript Preview", actionTitle: "Open") {
                    path.append(AppRoute.transcript(lecture.id))
                }
                .padding(.horizontal, 0)

                Text(lecture.transcript.isEmpty ? "No transcript is available yet." : lecture.transcript)
                    .font(.body)
                    .foregroundStyle(lecture.transcript.isEmpty ? .secondary : .primary)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
                    HStack {
                        Image(systemName: symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(tint)
                            .frame(width: 36, height: 36)
                            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
                        Spacer()
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LectureDetailView(lectureID: PreviewData.lectureID, path: .constant(NavigationPath()))
    }
    .modelContainer(PreviewData.container)
}
