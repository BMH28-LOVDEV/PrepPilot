import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selection = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(symbol: "waveform", title: "Capture the lecture", message: "Record, pause, resume, and keep every class session organized from the first minute."),
        OnboardingPage(symbol: "sparkles.rectangle.stack", title: "Turn audio into study material", message: "PrepPilot drafts notes, summaries, flashcards, quizzes, and review guides from each transcript."),
        OnboardingPage(symbol: "graduationcap", title: "Prepare with context", message: "Ask focused questions and get answers grounded in your own lecture notes.")
    ]

    private var currentIndex: Int {
        min(max(selection, 0), pages.count - 1)
    }

    private var currentPage: OnboardingPage {
        pages[currentIndex]
    }

    var body: some View {
        PremiumBackground {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                VStack(spacing: 8) {
                    Text("PrepPilot")
                        .font(.largeTitle.weight(.bold))
                    Text("Study materials from every lecture")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                OnboardingPageView(page: currentPage)
                    .frame(maxHeight: 430)

                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.indigo : Color.secondary.opacity(0.25))
                            .frame(width: index == currentIndex ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selection)
                    }
                }
                .accessibilityLabel("Onboarding step \(currentIndex + 1) of \(pages.count)")

                PrimaryActionButton(
                    title: currentIndex == pages.count - 1 ? "Get Started" : "Continue",
                    systemImage: currentIndex == pages.count - 1 ? "arrow.right" : "chevron.right"
                ) {
                    Haptics.medium()
                    if currentIndex >= pages.count - 1 {
                        hasCompletedOnboarding = true
                    } else {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                            selection = currentIndex + 1
                        }
                    }
                }
                .padding(.horizontal)
                .zIndex(1)

                Spacer(minLength: 24)
            }
        }
    }
}

private struct OnboardingPage: Hashable {
    let symbol: String
    let title: String
    let message: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: page.symbol)
                .font(.system(size: 68, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(PrepPilotTheme.studyGradient)
                .frame(width: 150, height: 150)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView()
}
