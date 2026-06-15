import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let aiService: StudyAIProviding
    let speechService: SpeechTranscribing
    let subscriptionStore: SubscriptionStore
    let cloudSyncService: CloudSyncService

    /// The backend base URL string used to initialize the AI service (kept explicit for diagnostics)
    var backendBaseURLString: String {
        return "https://preppilot-official-dockersetup.onrender.com"
    }

    init(
        aiService: StudyAIProviding = {
            // Always target the Render backend to avoid accidentally using a local server.
            let renderURLString = "https://preppilot-official-dockersetup.onrender.com"
            let renderURL = URL(string: renderURLString)!
            #if DEBUG
            print("[AppEnvironment] Forcing backend to Render URL: \(renderURLString)")
            #endif
            guard !Secrets.clientAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                fatalError("Missing backend configuration: Set Secrets.clientAPIKey")
            }
            return HTTPStudyAIService(baseURL: renderURL, clientKey: Secrets.clientAPIKey)
        }(),
        speechService: SpeechTranscribing = SpeechTranscriptionService(),
        subscriptionStore: SubscriptionStore = SubscriptionStore(),
        cloudSyncService: CloudSyncService = CloudSyncService()
    ) {
        self.aiService = aiService
        self.speechService = speechService
        self.subscriptionStore = subscriptionStore
        self.cloudSyncService = cloudSyncService
    }
}
