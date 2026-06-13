import AVFAudio
import AVFoundation
import Foundation

struct RecordingResult {
    let url: URL
    let duration: TimeInterval
}

enum AudioRecorderError: LocalizedError {
    case microphoneDenied
    case recorderUnavailable

    var errorDescription: String? {
        switch self {
        case .microphoneDenied: "Microphone permission was not granted."
        case .recorderUnavailable: "The recorder is not available."
        }
    }
}

@MainActor
@Observable
final class AudioRecorderService {
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?

    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var duration: TimeInterval = 0
    private(set) var powerLevels: [CGFloat] = Array(repeating: 0.08, count: 44)
    private(set) var recordingURL: URL?

    func start() async throws {
        guard await requestMicrophoneAccess() else {
            throw AudioRecorderError.microphoneDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let directory = try Self.recordingsDirectory()
        let url = directory.appendingPathComponent("lecture-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        self.recordingURL = url
        self.duration = 0
        self.startedAt = .now
        self.isRecording = true
        self.isPaused = false
        startMetering()
    }

    func pause() {
        guard isRecording, !isPaused else { return }
        recorder?.pause()
        isPaused = true
        Haptics.light()
    }

    func resume() {
        guard isRecording, isPaused else { return }
        recorder?.record()
        isPaused = false
        Haptics.light()
    }

    func stop() throws -> RecordingResult {
        guard let recorder, let recordingURL else {
            throw AudioRecorderError.recorderUnavailable
        }

        recorder.updateMeters()
        let finalDuration = recorder.currentTime
        recorder.stop()
        meterTimer?.invalidate()
        meterTimer = nil

        self.recorder = nil
        self.isRecording = false
        self.isPaused = false
        self.duration = finalDuration
        self.powerLevels = Array(repeating: 0.08, count: 44)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Haptics.success()

        return RecordingResult(url: recordingURL, duration: finalDuration)
    }

    private func requestMicrophoneAccess() async -> Bool {
        guard Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let recorderService = self else { return }
            Task { @MainActor in
                recorderService.refreshMeters()
            }
        }
    }

    private func refreshMeters() {
        guard let recorder else { return }
        recorder.updateMeters()
        duration = recorder.currentTime

        let power = recorder.averagePower(forChannel: 0)
        let normalized = max(0.06, min(1, CGFloat(pow(10, power / 35))))
        let nextLevel = isPaused ? 0.06 : normalized
        powerLevels.append(nextLevel)
        if powerLevels.count > 44 {
            powerLevels.removeFirst(powerLevels.count - 44)
        }
    }

    private static func recordingsDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
