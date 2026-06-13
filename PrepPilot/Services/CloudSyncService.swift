import Foundation

@MainActor
@Observable
final class CloudSyncService {
    private(set) var statusDescription = "iCloud not configured"
    private(set) var isAvailable = false

    func refresh() async {
        isAvailable = false
        statusDescription = "iCloud not configured"
    }
}
