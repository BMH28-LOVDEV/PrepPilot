import Foundation

final class HTTPStudyAIService: StudyAIProviding {
    // JSON decoding that tolerates snake_case keys from the backend
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    // JSON encoding that matches snake_case keys expected by many backends
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // Handles odd redirects that point to internal or insecure hosts by rewriting them back to our base host over HTTPS.
    private final class RedirectHandler: NSObject, URLSessionTaskDelegate, URLSessionDelegate {
        private let baseURL: URL
        init(baseURL: URL) { self.baseURL = baseURL }
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            // Refuse automatic redirects so we can rewrite any problematic targets (e.g., internal hosts) manually.
            if let url = request.url {
                print("[HTTPStudyAIService] Refusing auto-redirect to: \(url.absoluteString)")
            }
            completionHandler(nil)
        }
        #if DEBUG
        // DEBUG-ONLY: Trust override to unblock TLS handshake issues for the configured base host.
        // Do NOT ship this to production. Fix server certificates instead.
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            let host = challenge.protectionSpace.host
            let allowedHost = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)?.host ?? ""
            if host == allowedHost {
                print("[HTTPStudyAIService] DEBUG: Temporarily trusting TLS for host: \(host)")
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }
        #endif
    }

    private var redirectHandler: RedirectHandler? = nil

    // Ensure we use a correct, secure base URL (upgrade to HTTPS for Render) and strip trailing slashes.
    private static func normalizedBaseURL(from url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        if let host = components.host, host.contains("onrender.com") {
            components.scheme = "https"
        }
        // Remove any trailing slash by rebuilding the URL without an empty last path component
        if let path = components.path.removingPercentEncoding, path.hasSuffix("/") {
            components.path = String(path.dropLast())
        }
        return components.url ?? url
    }

    // Detect private or local hosts (LAN, loopback, or .local)
    private static func isPrivateHost(_ host: String) -> Bool {
        if host == "localhost" { return true }
        if host.hasSuffix(".local") { return true }
        if host.hasPrefix("127.") { return true }
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        if host.hasPrefix("172.") {
            // 172.16.0.0 – 172.31.255.255
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) {
                return true
            }
        }
        return false
    }

    // API prefix used by the backend (e.g., /api/...)
    private let apiPrefix = "api"

    // Build API paths like "api/generate-notes" without leading slashes
    private func apiPath(_ endpoint: String) -> String {
        let cleanEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(apiPrefix)/\(cleanEndpoint)"
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> [GeneratedFlashcard] {
        // Preferences are not yet used by the backend; delegate to the non-preferences overload.
        _ = preferences
        return try await generateFlashcards(from: transcript, notes: notes)
    }
    
    func generateQuiz(from transcript: String, notes: GeneratedNotes, preferences: StudyGenerationPreferences) async throws -> GeneratedQuiz {
        // Preferences are not yet used by the backend; delegate to the non-preferences overload.
        _ = preferences
        return try await generateQuiz(from: transcript, notes: notes)
    }
    
    private var baseURL: URL
    private let clientKey: String
    private let session: URLSession

    init(baseURL: URL, clientKey: String, session: URLSession? = nil) {
        var normalized = HTTPStudyAIService.normalizedBaseURL(from: baseURL)
        let comps = URLComponents(url: normalized, resolvingAgainstBaseURL: false)
        let host = comps?.host ?? ""
        let scheme = (comps?.scheme ?? "").lowercased()
        if HTTPStudyAIService.isPrivateHost(host) || scheme == "http" {
            if let fallback = Secrets.backendBaseURL {
                let fixed = HTTPStudyAIService.normalizedBaseURL(from: fallback)
                print("[HTTPStudyAIService] Overriding base URL \(normalized.absoluteString) -> \(fixed.absoluteString)")
                normalized = fixed
            } else {
                print("[HTTPStudyAIService] Warning: Private or insecure base URL detected (\(normalized.absoluteString)) and no fallback available in Secrets.")
            }
        }
        self.baseURL = normalized
        print("[HTTPStudyAIService] Using base URL:", self.baseURL.absoluteString)
        self.clientKey = clientKey
        // Build a session that can correct bad redirects (e.g., to internal HTTP hosts)
        self.redirectHandler = RedirectHandler(baseURL: self.baseURL)
        if let session = session {
            self.session = session
        } else {
            // Create a delegate-based session tied to our redirect handler
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config, delegate: self.redirectHandler, delegateQueue: nil)
        }
    }

    // MARK: - Internal payloads

    private struct NotesPayload: Encodable {
        let title: String
        let detailedNotes: String
        let conciseSummary: String
        let keyTakeaways: String
        let vocabularyTerms: String
        let importantConcepts: String

        init(from notes: GeneratedNotes) {
            self.title = notes.title
            self.detailedNotes = notes.detailedNotes
            self.conciseSummary = notes.conciseSummary
            self.keyTakeaways = notes.keyTakeaways
            self.vocabularyTerms = notes.vocabularyTerms
            self.importantConcepts = notes.importantConcepts
        }
    }

    // MARK: - StudyAIProviding

    func generateNotes(from transcript: String, lectureTitle: String) async throws -> GeneratedNotes {
        struct Req: Encodable { let transcript: String; let lectureTitle: String }
        struct Res: Decodable {
            let title: String
            let detailedNotes: String
            let conciseSummary: String
            let keyTakeaways: String
            let vocabularyTerms: String
            let importantConcepts: String
        }
        let res: Res = try await postWithFallbacks("generate-notes", body: Req(transcript: transcript, lectureTitle: lectureTitle))
        return GeneratedNotes(
            title: res.title,
            detailedNotes: res.detailedNotes,
            conciseSummary: res.conciseSummary,
            keyTakeaways: res.keyTakeaways,
            vocabularyTerms: res.vocabularyTerms,
            importantConcepts: res.importantConcepts
        )
    }

    func generateFlashcards(from transcript: String, notes: GeneratedNotes) async throws -> [GeneratedFlashcard] {
        struct Req: Encodable { let transcript: String; let notes: NotesPayload }
        struct Card: Decodable { let front: String; let back: String }
        let cards: [Card] = try await postWithFallbacks("generate-flashcards", body: Req(transcript: transcript, notes: NotesPayload(from: notes)))
        return cards.map { GeneratedFlashcard(front: $0.front, back: $0.back) }
    }

    func generateQuiz(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedQuiz {
        struct Req: Encodable { let transcript: String; let notes: NotesPayload }
        struct Question: Decodable {
            let kind: String
            let prompt: String
            let options: [String]?
            let correctAnswer: String
            let explanation: String
        }
        struct Res: Decodable { let title: String; let questions: [Question] }
        let res: Res = try await postWithFallbacks("generate-quiz", body: Req(transcript: transcript, notes: NotesPayload(from: notes)))
        let questions: [GeneratedQuizQuestion] = res.questions.map { q in
            let normalizedKind = q.kind
                .lowercased()
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: " ", with: "")
            let kind: QuizQuestionKind
            switch normalizedKind {
            case "multiplechoice": kind = .multipleChoice
            case "truefalse": kind = .trueFalse
            default: kind = .shortAnswer
            }
            return GeneratedQuizQuestion(
                kind: kind,
                prompt: q.prompt,
                options: q.options ?? [],
                correctAnswer: q.correctAnswer,
                explanation: q.explanation
            )
        }
        return GeneratedQuiz(title: res.title, questions: questions)
    }

    func generateStudyGuide(from transcript: String, notes: GeneratedNotes) async throws -> GeneratedStudyGuide {
        struct Req: Encodable { let transcript: String; let notes: NotesPayload }
        struct Res: Decodable {
            let title: String
            let examReview: String
            let topicSummaries: String
            let importantConcepts: String
            let keyDefinitions: String
        }
        let res: Res = try await postWithFallbacks("generate-study-guide", body: Req(transcript: transcript, notes: NotesPayload(from: notes)))
        return GeneratedStudyGuide(
            title: res.title,
            examReview: res.examReview,
            topicSummaries: res.topicSummaries,
            importantConcepts: res.importantConcepts,
            keyDefinitions: res.keyDefinitions
        )
    }

    func answer(question: String, noteContext: String) async throws -> AIAnswer {
        struct Req: Encodable { let question: String; let noteContext: String }
        struct Res: Decodable { let content: String; let sources: [String] }
        let res: Res = try await postWithFallbacks("answer", body: Req(question: question, noteContext: noteContext))
        return AIAnswer(content: res.content, sources: res.sources)
    }


    // Resolve a final, public HTTPS URL by following (and rewriting) any redirect chain before sending a POST.
    private func resolveFinalURL(startingAt url: URL, maxRedirects: Int = 4) async -> URL {
        var current = url
        var attempts = 0
        while attempts < maxRedirects {
            var req = URLRequest(url: current)
            req.httpMethod = "GET"
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("PrepPilot/1.0 (iOS; URLSession)", forHTTPHeaderField: "User-Agent")
            // Proxy-awareness
            // Removed X-Forwarded-* headers as per instructions

            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.allowsConstrainedNetworkAccess = true
            req.allowsExpensiveNetworkAccess = true

            do {
                let (_, response) = try await session.data(for: req)
                guard let http = response as? HTTPURLResponse else { break }
                if (300..<400).contains(http.statusCode), let location = http.value(forHTTPHeaderField: "Location") {
                    let candidate = URL(string: location, relativeTo: current) ?? URL(string: location)
                    if let candidate {
                        var comps = URLComponents(url: candidate, resolvingAgainstBaseURL: true) ?? URLComponents()
                        let original = candidate.absoluteString
                        comps.scheme = "https"
                        comps.host = baseURL.host
                        comps.port = baseURL.port
                        if let fixed = comps.url {
                            print("[HTTPStudyAIService] Preflight redirect fix: \(original) -> \(fixed.absoluteString)")
                            current = fixed
                            attempts += 1
                            continue
                        } else {
                            print("[HTTPStudyAIService] Preflight redirect could not be rewritten: \(original)")
                        }
                    }
                }
                // Not a redirect
                break
            } catch {
                // If preflight fails, return the current URL and let the main request handle it.
                print("[HTTPStudyAIService] Preflight error: \(error.localizedDescription)")
                break
            }
        }
        return current
    }

    // Force any URL to use our public HTTPS host while preserving path/query.
    private func normalizedPublicURL(from url: URL) -> URL {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: true) ?? URLComponents()
        comps.scheme = "https"
        comps.host = baseURL.host
        comps.port = baseURL.port
        return comps.url ?? url
    }

    // MARK: - Networking

    private func candidatePaths(for endpoint: String) -> [String] {
        // Try API-style and flat paths, with hyphen and underscore variants, and common prefixes.
        let clean = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let underscore = clean.replacingOccurrences(of: "-", with: "_")
        let hyphenless = clean.replacingOccurrences(of: "generate-", with: "")
        let underscoreless = underscore.replacingOccurrences(of: "generate_", with: "")

        let variants = [clean, underscore, hyphenless, underscoreless].filter { !$0.isEmpty }
        let prefixes = ["api/", "", "v1/", "api/v1/", "ai/", "api/ai/", "v1/ai/", "api/v1/ai/"]

        var base: [String] = []
        for v in variants {
            for prefix in prefixes {
                base.append("\(prefix)\(v)")
            }
        }

        // Add trailing slash variants
        let withTrailingSlash = base.map { $0.hasSuffix("/") ? $0 : $0 + "/" }
        // Return unique ordered candidates
        var seen = Set<String>()
        let all = base + withTrailingSlash
        return all.filter { seen.insert($0).inserted }
    }

    private func postWithFallbacks<Body: Encodable, Response: Decodable>(_ endpoint: String, body: Body) async throws -> Response {
        let paths = candidatePaths(for: endpoint)
        var lastError: Error?
        for p in paths {
            do {
                return try await post(p, body: body)
            } catch {
                #if DEBUG
                print("[HTTPStudyAIService] POST failed for \(p): \(error.localizedDescription)")
                #endif
                lastError = error
                continue
            }
        }
        throw lastError ?? URLError(.badURL)
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let encodedBody = try encoder.encode(body)

        var currentURL = baseURL.appendingPathComponent(cleanPath)
        currentURL = await resolveFinalURL(startingAt: currentURL)
        currentURL = normalizedPublicURL(from: currentURL)

        #if DEBUG
        print("[HTTPStudyAIService] SANITY: base host=\(baseURL.host ?? "<nil>") scheme=\(baseURL.scheme ?? "<nil>") current host=\(currentURL.host ?? "<nil>") scheme=\(currentURL.scheme ?? "<nil>") path=\(currentURL.path)")
        #endif

        var redirectAttempts = 0
        let maxRedirects = 4
        var data: Data = Data()
        var response: URLResponse = URLResponse()

        redirectLoop: while redirectAttempts <= maxRedirects {
            currentURL = normalizedPublicURL(from: currentURL)

            #if DEBUG
            print("[HTTPStudyAIService] SANITY: base host=\(baseURL.host ?? "<nil>") scheme=\(baseURL.scheme ?? "<nil>") current host=\(currentURL.host ?? "<nil>") scheme=\(currentURL.scheme ?? "<nil>") path=\(currentURL.path)")
            #endif

            var request = URLRequest(url: currentURL)
            request.httpMethod = "POST"
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.allowsConstrainedNetworkAccess = true
            request.allowsExpensiveNetworkAccess = true
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("PrepPilot/1.0 (iOS; URLSession)", forHTTPHeaderField: "User-Agent")
            request.setValue("Bearer \(clientKey)", forHTTPHeaderField: "Authorization")
            request.setValue(clientKey, forHTTPHeaderField: "X-API-Key")
            // Removed X-Forwarded-* headers as per instructions
            request.httpBody = encodedBody

            #if DEBUG
            print("[HTTPStudyAIService] POST", request.url?.absoluteString ?? path)
            #endif

            var attempt = 0
            let maxAttempts = 3
            while true {
                do {
                    (data, response) = try await session.data(for: request)
                    break
                } catch {
                    #if DEBUG
                    let ns = error as NSError
                    let urlErr = (error as? URLError)?.code.rawValue ?? ns.code
                    print("[HTTPStudyAIService] Network error (code: \(urlErr)) for \(request.url?.absoluteString ?? cleanPath): \(ns.domain) - \(ns.localizedDescription)")
                    #endif
                    if let urlError = error as? URLError,
                       [URLError.timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost].contains(urlError.code),
                       attempt < maxAttempts - 1 {
                        attempt += 1
                        let delay = UInt64(1_000_000_000) * UInt64(attempt) // 1s, then 2s
                        #if DEBUG
                        print("[HTTPStudyAIService] Retrying (\(attempt)/\(maxAttempts)) after transient error...")
                        #endif
                        try? await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw error
                }
            }

            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            #if DEBUG
            print("[HTTPStudyAIService] Status: \(http.statusCode)")
            #endif

            // Manual redirect handling to correct problematic redirects to internal or insecure hosts
            if (300..<400).contains(http.statusCode), let location = http.value(forHTTPHeaderField: "Location") {
                let candidate = URL(string: location, relativeTo: currentURL) ?? URL(string: location)
                if let candidate {
                    var comps = URLComponents(url: candidate, resolvingAgainstBaseURL: true) ?? URLComponents()
                    let original = candidate.absoluteString
                    // Force HTTPS and our known public host
                    comps.scheme = "https"
                    comps.host = baseURL.host
                    comps.port = baseURL.port
                    if let fixed = comps.url {
                        print("[HTTPStudyAIService] Manual redirect fix: \(original) -> \(fixed.absoluteString)")
                        currentURL = fixed
                        redirectAttempts += 1
                        continue redirectLoop
                    } else {
                        print("[HTTPStudyAIService] Manual redirect could not be rewritten: \(original)")
                    }
                }
            }

            // Not a redirect -> break out and handle status
            break
        }

        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        #if DEBUG
        print("[HTTPStudyAIService] Status: \(http.statusCode)")
        #endif
        guard (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("[HTTPStudyAIService] Error body: \(message)")
            #endif
            let errMsg = "\(message) [HTTP \(http.statusCode) at \(currentURL.path)]"
            throw NSError(domain: "HTTPStudyAIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            #if DEBUG
            let preview = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print("[HTTPStudyAIService] Decoding failed: \(error). Body preview: \(preview)")
            #endif
            throw error
        }
    }

    // MARK: - Debugging / Connectivity

    /// Exposes the base URL string for app-level diagnostics.
    func debugBaseURLString() -> String { baseURL.absoluteString }

    /// Simple connectivity probe to verify the app can reach the backend and that URLs are correct.
    /// Hits `/health` and prints the status/body to the console.
    @discardableResult
    func debugPing() async -> Bool {
        // Try a few common health endpoints without auth to avoid 401s preventing reachability checks.
        let candidates = [
            "/",
            "/health",
            "/api/health",
            "/healthz",
            "/api/healthz",
            "/status",
            "/api/status",
            "/v1/health",
            "/api/v1/health"
        ]
        print("[HTTPStudyAIService] Ping base URL: \(baseURL.absoluteString)")

        for path in candidates {
            let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
            let url = baseURL.appendingPathComponent(cleanPath)
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            print("[HTTPStudyAIService] PING GET \(url.absoluteString)")
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    print("[HTTPStudyAIService] Ping: bad server response for \(url.absoluteString)")
                    continue
                }
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                print("[HTTPStudyAIService] Ping status: \(http.statusCode) for \(url.absoluteString) body: \(body)")
                // Consider any HTTP response as network reachable; 4xx/5xx likely means missing health route.
                return true
            } catch {
                print("[HTTPStudyAIService] Ping error for \(url.absoluteString): \(error.localizedDescription)")
                // Try next candidate
            }
        }

        print("[HTTPStudyAIService] Ping failed for all health endpoints.")
        return false
    }
}

