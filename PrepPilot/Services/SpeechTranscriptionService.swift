import Foundation
import Speech

enum SpeechTranscriptionError: LocalizedError {
    case recognizerUnavailable
    case authorizationDenied
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: "Speech recognition is unavailable for the current locale."
        case .authorizationDenied: "Speech recognition permission was not granted."
        case .emptyResult: "No transcript was produced for this recording."
        }
    }
}

@MainActor
protocol SpeechTranscribing {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
    func transcribeAudio(at url: URL) async throws -> String
}

@MainActor
final class SpeechTranscriptionService: SpeechTranscribing {
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    func transcribeAudio(at url: URL) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechTranscriptionError.authorizationDenied
        }

        guard let recognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent), recognizer.isAvailable else {
            throw SpeechTranscriptionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let box = SpeechContinuationBox()
        return try await withCheckedThrowingContinuation { continuation in
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    box.updateTranscript(result.bestTranscription.formattedString)
                    if result.isFinal {
                        box.complete(continuation, result: .success(result.bestTranscription.formattedString))
                    }
                }

                if let error {
                    box.complete(continuation, result: .failure(error))
                }
            }
            box.retain(task)
        }
    }
}

private final class SpeechContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private var latestTranscript = ""
    private var task: SFSpeechRecognitionTask?

    func retain(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        self.task = task
        lock.unlock()
    }

    func updateTranscript(_ transcript: String) {
        lock.lock()
        latestTranscript = transcript
        lock.unlock()
    }

    func complete(_ continuation: CheckedContinuation<String, Error>, result: Result<String, Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        task = nil
        let transcript = latestTranscript
        lock.unlock()

        switch result {
        case .success(let value):
            let final = value.isEmpty ? transcript : value
            if final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continuation.resume(throwing: SpeechTranscriptionError.emptyResult)
            } else {
                continuation.resume(returning: final)
            }
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
