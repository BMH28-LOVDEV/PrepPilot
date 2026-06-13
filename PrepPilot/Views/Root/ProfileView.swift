import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("isSignedIn") private var isSignedIn = true
    @Binding var path: NavigationPath

    @Query private var lectures: [Lecture]
    @Query private var flashcards: [Flashcard]
    @Query private var quizzes: [Quiz]

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader
                    subscriptionCard
                    stats
                    actions
                }
                .padding(.vertical, 18)
                .padding(.horizontal)
            }
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToolbarIconButton(systemImage: "gearshape", title: "Settings") {
                    path.append(AppRoute.settings)
                }
            }
        }
        .task {
            await environment.cloudSyncService.refresh()
        }
    }

    private var profileHeader: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(PrepPilotTheme.studyGradient)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Student")
                        .font(.title2.weight(.bold))
                    Text(environment.cloudSyncService.statusDescription)
                        .font(.subheadline)
                        .foregroundStyle(environment.cloudSyncService.isAvailable ? .green : .secondary)
                }
                Spacer()
            }
        }
    }

    private var subscriptionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(environment.subscriptionStore.isPremium ? "PrepPilot Premium" : "Free Plan", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text(environment.subscriptionStore.isPremium ? "Active" : "Limited")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((environment.subscriptionStore.isPremium ? Color.green : Color.orange).opacity(0.14), in: Capsule())
                }

                Text(environment.subscriptionStore.isPremium ? "Unlimited lectures, generated materials, and AI questions are enabled." : "Free tier includes limited lecture generation. Upgrade for monthly or yearly premium access.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(environment.subscriptionStore.isPremium ? "Manage Plan" : "View Premium") {
                    path.append(AppRoute.paywall)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Lectures", value: "\(lectures.count)", systemImage: "waveform", tint: .indigo)
            MetricTile(title: "Flashcards", value: "\(flashcards.count)", systemImage: "rectangle.on.rectangle", tint: .teal)
            MetricTile(title: "Quizzes", value: "\(quizzes.count)", systemImage: "checklist", tint: .pink)
            MetricTile(title: "Synced", value: environment.cloudSyncService.isAvailable ? "Yes" : "--", systemImage: "icloud", tint: .blue)
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                path.append(AppRoute.settings)
            } label: {
                settingsRow(title: "Settings", subtitle: "Notifications, sync, privacy", symbol: "gearshape")
            }
            Button {
                path.append(AppRoute.paywall)
            } label: {
                settingsRow(title: "Subscription", subtitle: "Monthly and yearly plans", symbol: "creditcard")
            }
            Button(role: .destructive) {
                isSignedIn = false
            } label: {
                settingsRow(title: "Sign Out", subtitle: "Return to authentication", symbol: "rectangle.portrait.and.arrow.right")
            }
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        ProfileView(path: .constant(NavigationPath()))
    }
    .environment(AppEnvironment())
    .modelContainer(PreviewData.container)
}
