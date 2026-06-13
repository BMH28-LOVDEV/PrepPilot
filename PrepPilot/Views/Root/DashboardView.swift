import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath

    @Query(sort: \Lecture.createdAt, order: .reverse) private var lectures: [Lecture]
    @Query(sort: \LectureNote.createdAt, order: .reverse) private var notes: [LectureNote]
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var flashcards: [Flashcard]
    @Query(sort: \Quiz.createdAt, order: .reverse) private var quizzes: [Quiz]
    @Query(sort: \StudyTask.dueDate, order: .forward) private var tasks: [StudyTask]

    @State private var viewModel = DashboardViewModel()

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    metricsGrid
                    upcomingTasks
                    recentLectures
                }
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("PrepPilot")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIconButton(systemImage: "plus", title: "Record lecture", tint: .indigo) {
                    path.append(AppRoute.recording)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.largeTitle.weight(.bold))
                Text("Record a lecture, review generated material, and keep your exam prep moving.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryActionButton(title: "Record Lecture", systemImage: "mic.fill") {
                path.append(AppRoute.recording)
            }
        }
        .padding(.horizontal)
    }

    private var metricsGrid: some View {
        let stats = viewModel.stats(lectures: lectures, tasks: tasks, flashcards: flashcards, quizzes: quizzes)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Lectures", value: "\(stats.lectureCount)", systemImage: "waveform", tint: .indigo)
            MetricTile(title: "Due Soon", value: "\(stats.dueTaskCount)", systemImage: "calendar.badge.clock", tint: .orange)
            MetricTile(title: "Cards Studied", value: "\(stats.studiedCards)", systemImage: "rectangle.on.rectangle", tint: .teal)
            MetricTile(title: "Quiz Avg", value: stats.averageQuizScore == 0 ? "--" : "\(Int(stats.averageQuizScore * 100))%", systemImage: "chart.line.uptrend.xyaxis", tint: .pink)
        }
        .padding(.horizontal)
    }

    private var upcomingTasks: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Study Tasks")
            let visibleTasks = tasks.filter { !$0.isComplete }.prefix(4)
            if visibleTasks.isEmpty {
                EmptyStateView(systemImage: "checkmark.seal", title: "No tasks waiting", message: "New review tasks appear after recording and generating study materials.")
                    .premiumCard()
                    .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(visibleTasks)) { task in
                        StudyTaskRow(task: task) {
                            task.isComplete.toggle()
                            try? modelContext.save()
                            Haptics.success()
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recentLectures: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent Lectures")
            if lectures.isEmpty {
                EmptyStateView(systemImage: "waveform.badge.plus", title: "Record your first lecture", message: "PrepPilot will save the audio and create a transcript, notes, flashcards, a quiz, and a study guide.", actionTitle: "Start Recording") {
                    path.append(AppRoute.recording)
                }
                .premiumCard()
                .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(lectures.prefix(6))) { lecture in
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
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DashboardView(path: .constant(NavigationPath()))
    }
    .modelContainer(PreviewData.container)
}
