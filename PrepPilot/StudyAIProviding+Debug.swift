import Foundation

extension StudyAIProviding {
    /// Exposes the base URL string for app-level diagnostics.
    /// If the underlying service is HTTPStudyAIService, returns its base URL; otherwise returns a placeholder.
    func debugBaseURLString() -> String {
        if let http = self as? HTTPStudyAIService {
            return http.debugBaseURLString()
        }
        return "unknown"
    }
    
    /// Default implementation for connectivity probing.
    /// If the underlying service is `HTTPStudyAIService`, forwards to its `debugPing()`.
    /// Otherwise, returns false.
    @discardableResult
    func debugPing() async -> Bool {
        if let http = self as? HTTPStudyAIService {
            return await http.debugPing()
        }
        // Fallback: perform a simple connectivity probe against the configured Secrets base URL
        let base = Secrets.backendBaseURLString
        guard let baseURL = URL(string: base) else {
            print("[StudyAIProviding] debugPing fallback: invalid base URL string:", base)
            return false
        }

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        let candidates = ["/", "/health", "/api/health", "/healthz", "/api/healthz"]
        print("[StudyAIProviding] Fallback ping base URL:", base)

        for path in candidates {
            let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
            let url = baseURL.appendingPathComponent(cleanPath)
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            print("[StudyAIProviding] Fallback PING GET", url.absoluteString)
            do {
                let (data, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    print("[StudyAIProviding] Fallback PING: bad server response for", url.absoluteString)
                    continue
                }
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                print("[StudyAIProviding] Fallback PING status:", http.statusCode, "for", url.absoluteString, "body:", body)
                if (200..<300).contains(http.statusCode) {
                    return true
                }
            } catch {
                print("[StudyAIProviding] Fallback PING error for", url.absoluteString, ":", error.localizedDescription)
                // Try next candidate
            }
        }

        print("[StudyAIProviding] Fallback PING failed for all health endpoints.")
        return false
    }
}

