import SwiftData
import SwiftUI

struct SearchView: View {
    @Binding var path: NavigationPath
    @State private var viewModel = SearchViewModel()

    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query private var notes: [LectureNote]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]
    @Query private var guides: [StudyGuide]

    private var results: [SearchResult] {
        viewModel.results(lectures: lectures, notes: notes, flashcards: flashcards, quizzes: quizzes, guides: guides)
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        recentSearchContent
                    } else if results.isEmpty {
                        EmptyStateView(systemImage: "magnifyingglass", title: "No matches", message: "Try a lecture title, course, concept, flashcard answer, or quiz topic.")
                            .premiumCard()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(results) { result in
                                Button {
                                    path.append(result.route)
                                } label: {
                                    SearchResultRow(result: result)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search lectures, notes, cards")
    }

    private var recentSearchContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Search everything", systemImage: "magnifyingglass")
                        .font(.headline)
                    Text("Find lectures, notes, flashcards, quizzes, and study guides from one place.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Lectures")
                    .font(.headline)
                if lectures.isEmpty {
                    EmptyStateView(systemImage: "waveform", title: "Nothing to search yet", message: "Record a lecture to build your searchable study library.")
                        .premiumCard()
                } else {
                    ForEach(Array(lectures.prefix(5))) { lecture in
                        Button {
                            path.append(AppRoute.lecture(lecture.id))
                        } label: {
                            LectureRow(
                                lecture: lecture,
                                noteCount: notes.filter { $0.lectureID == lecture.id }.count,
                                cardCount: flashcards.filter { $0.lectureID == lecture.id }.count,
                                quizCount: quizzes.filter { $0.lectureID == lecture.id }.count
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.symbolName)
                .font(.headline)
                .foregroundStyle(.indigo)
                .frame(width: 38, height: 38)
                .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        SearchView(path: .constant(NavigationPath()))
    }
    .modelContainer(PreviewData.container)
}
