import SwiftData
import SwiftUI

struct FlashcardView: View {
    let lectureID: UUID
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flashcard.createdAt, order: .forward) private var allCards: [Flashcard]
    @State private var study = FlashcardStudyViewModel()

    private var cards: [Flashcard] { allCards.filter { $0.lectureID == lectureID } }

    var body: some View {
        PremiumBackground {
            if cards.isEmpty {
                EmptyStateView(systemImage: "rectangle.on.rectangle", title: "No flashcards", message: "Flashcards are generated after a transcript and notes are available.")
            } else {
                VStack(spacing: 20) {
                    progressHeader
                    cardStack
                    ratingControls
                    navigationControls
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .task { study.resetIfNeeded(total: cards.count) }
        .onChange(of: cards.count) { _, newValue in
            study.resetIfNeeded(total: newValue)
        }
    }

    private var currentCard: Flashcard { cards[study.currentIndex] }

    private var progressHeader: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Card \(study.currentIndex + 1) of \(cards.count)")
                        .font(.headline)
                    Spacer()
                    masteryStars(currentCard.mastery)
                }
                ProgressView(value: Double(study.currentIndex + 1), total: Double(cards.count))
                    .tint(.indigo)
            }
        }
    }

    private var cardStack: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                study.flip()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 24, y: 12)

                VStack(spacing: 18) {
                    Label(study.isShowingBack ? "Answer" : "Question", systemImage: study.isShowingBack ? "checkmark.seal" : "questionmark.circle")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text(study.isShowingBack ? currentCard.back : currentCard.front)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .contentTransition(.opacity)

                    Text("Tap to flip")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(28)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture()
                .onEnded { value in
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                        if value.translation.width < -48 {
                            study.moveForward(total: cards.count)
                        } else if value.translation.width > 48 {
                            study.moveBackward()
                        } else {
                            study.flip()
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
    }

    private var ratingControls: some View {
        HStack(spacing: 12) {
            Button {
                study.mark(currentCard, masteryDelta: -1, context: modelContext)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { study.moveForward(total: cards.count) }
            } label: {
                Label("Needs Work", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                study.mark(currentCard, masteryDelta: 1, context: modelContext)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { study.moveForward(total: cards.count) }
            } label: {
                Label("Know", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 12) {
            ToolbarIconButton(systemImage: "chevron.left", title: "Previous") {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { study.moveBackward() }
            }
            Spacer()
            Button("Flip Card") {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { study.flip() }
            }
            .font(.headline)
            Spacer()
            ToolbarIconButton(systemImage: "chevron.right", title: "Next") {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) { study.moveForward(total: cards.count) }
            }
        }
    }

    private func masteryStars(_ mastery: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < mastery ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(index < mastery ? .yellow : .secondary)
            }
        }
        .accessibilityLabel("Mastery \(mastery) out of 5")
    }
}

#Preview {
    NavigationStack {
        FlashcardView(lectureID: PreviewData.lectureID)
    }
    .modelContainer(PreviewData.container)
}
