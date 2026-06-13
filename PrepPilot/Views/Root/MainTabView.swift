import SwiftUI

struct MainTabView: View {
    @State private var path = NavigationPath()
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        NavigationStack(path: $path) {
            TabView(selection: $selectedTab) {
                DashboardView(path: $path)
                    .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
                    .tag(AppTab.dashboard)

                SearchView(path: $path)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    .tag(AppTab.search)

                ProfileView(path: $path)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(AppTab.profile)
            }
            .navigationDestination(for: AppRoute.self) { route in
                AppDestinationView(route: route, path: $path)
            }
        }
    }
}

private struct AppDestinationView: View {
    let route: AppRoute
    @Binding var path: NavigationPath
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        switch route {
        case .lecture(let id):
            LectureDetailView(lectureID: id, path: $path)
        case .recording:
            RecordingView(path: $path, speechService: environment.speechService, aiService: environment.aiService)
        case .transcript(let id):
            TranscriptView(lectureID: id)
        case .notes(let id):
            NotesView(lectureID: id)
        case .flashcards(let id):
            FlashcardView(lectureID: id)
        case .quiz(let id):
            QuizView(lectureID: id)
        case .studyGuide(let id):
            StudyGuideView(lectureID: id)
        case .chat(let id):
            AIChatView(lectureID: id, aiService: environment.aiService)
        case .search:
            SearchView(path: $path)
        case .profile:
            ProfileView(path: $path)
        case .paywall:
            PaywallView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppEnvironment())
        .modelContainer(PreviewData.container)
}
