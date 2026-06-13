import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let aiService: StudyAIProviding
    let speechService: SpeechTranscribing
    let subscriptionStore: SubscriptionStore
    let cloudSyncService: CloudSyncService

    init(
        aiService: StudyAIProviding = MockStudyAIService(),
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
