import Foundation

extension StudyAIProviding {
    /// Default implementation for connectivity probing.
    /// If the underlying service is `HTTPStudyAIService`, forwards to its `debugPing()`.
    /// Otherwise, returns false.
    @discardableResult
    func debugPing() async -> Bool {
        if let http = self as? HTTPStudyAIService {
            return await http.debugPing()
        }
        return false
    }
}
