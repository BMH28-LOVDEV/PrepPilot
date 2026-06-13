import SwiftData
import SwiftUI

struct StudyGuideView: View {
    let lectureID: UUID
    @Query private var guides: [StudyGuide]

    private var guide: StudyGuide? { guides.first { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground {
            if let guide {
                ScrollView {
                    VStack(spacing: 16) {
                        GuideSection(title: "Exam Review", symbol: "graduationcap", content: guide.examReview, tint: .indigo)
                        GuideSection(title: "Topic Summaries", symbol: "list.bullet.rectangle", content: guide.topicSummaries, tint: .teal)
                        GuideSection(title: "Important Concepts", symbol: "star.square", content: guide.importantConcepts, tint: .pink)
                        GuideSection(title: "Key Definitions", symbol: "text.book.closed", content: guide.keyDefinitions, tint: .orange)
                    }
                    .padding(.vertical, 18)
                    .padding(.horizontal)
                }
            } else {
                EmptyStateView(systemImage: "book.closed", title: "No study guide", message: "A guide will appear after the lecture transcript is processed.")
            }
        }
        .navigationTitle(guide?.title ?? "Study Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideSection: View {
    let title: String
    let symbol: String
    let content: String
    let tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                Text(content)
                    .font(.body)
                    .foregroundStyle(content.isEmpty ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        StudyGuideView(lectureID: PreviewData.lectureID)
    }
    .modelContainer(PreviewData.container)
}
