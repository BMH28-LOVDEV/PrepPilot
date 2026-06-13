import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("prefersHaptics") private var prefersHaptics = true
    @AppStorage("autoGenerateMaterials") private var autoGenerateMaterials = true
    @AppStorage("useOnDeviceSpeechWhenAvailable") private var useOnDeviceSpeechWhenAvailable = true
    @AppStorage("weeklyStudyReminders") private var weeklyStudyReminders = true

    var body: some View {
        Form {
            Section("Study") {
                Toggle("Auto-generate materials", isOn: $autoGenerateMaterials)
                Toggle("Weekly study reminders", isOn: $weeklyStudyReminders)
            }

            Section("Recording") {
                Toggle("Prefer on-device speech", isOn: $useOnDeviceSpeechWhenAvailable)
                Toggle("Haptic feedback", isOn: $prefersHaptics)
            }

            Section("Cloud") {
                HStack {
                    Label(environment.cloudSyncService.statusDescription, systemImage: "icloud")
                    Spacer()
                    if environment.cloudSyncService.isAvailable {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Button("Refresh iCloud Status") {
                    Task { await environment.cloudSyncService.refresh() }
                }
            }

            Section("App Store") {
                Text("Configure the monthly and yearly product identifiers in App Store Connect before release.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .task {
            await environment.cloudSyncService.refresh()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppEnvironment())
}
