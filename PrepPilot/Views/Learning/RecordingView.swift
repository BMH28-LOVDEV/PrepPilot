import SwiftData
import SwiftUI

struct RecordingView: View {
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RecordingViewModel

    init(path: Binding<NavigationPath>, speechService: SpeechTranscribing, aiService: StudyAIProviding) {
        _path = path
        _viewModel = State(initialValue: RecordingViewModel(speechService: speechService, aiService: aiService))
    }

    var body: some View {
        PremiumBackground {
            ScrollView {
                VStack(spacing: 20) {
                    titleFields
                    recorderCard
                    controls
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .overlay {
                if case .processing(let message) = viewModel.phase {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                    LoadingStateView(message: message)
                        .padding()
                }
            }
        }
        .navigationTitle("Record Lecture")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleFields: some View {
        GlassCard {
            VStack(spacing: 12) {
                TextField("Lecture title", text: $viewModel.title)
                    .textInputAutocapitalization(.words)
                    .font(.headline)
                    .padding(12)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                TextField("Course or class", text: $viewModel.course)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            }
        }
    }

    private var recorderCard: some View {
        GlassCard {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(recordingTint.opacity(0.12))
                        .frame(width: 138, height: 138)
                    Circle()
                        .stroke(recordingTint.opacity(0.35), lineWidth: 2)
                        .frame(width: 138, height: 138)
                        .scaleEffect(viewModel.phase == .recording ? 1.08 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.phase == .recording)
                    Image(systemName: iconName)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(recordingTint)
                }

                Text(PrepPilotFormatters.durationString(viewModel.recorder.duration))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()

                WaveformView(levels: viewModel.recorder.powerLevels, tint: recordingTint)
                    .frame(height: 86)

                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            switch viewModel.phase {
            case .idle:
                PrimaryActionButton(title: "Start Recording", systemImage: "mic.fill") {
                    Task { await viewModel.start() }
                }
            case .recording, .paused:
                HStack(spacing: 12) {
                    Button {
                        viewModel.pauseOrResume()
                    } label: {
                        Label(viewModel.phase == .paused ? "Resume" : "Pause", systemImage: viewModel.phase == .paused ? "play.fill" : "pause.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        Task {
                            if let id = await viewModel.stopAndSave(in: modelContext) {
                                path.append(AppRoute.lecture(id))
                            }
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            case .processing:
                PrimaryActionButton(title: "Processing", systemImage: "sparkles", isLoading: true) {}
            case .completed:
                PrimaryActionButton(title: "Open Lecture", systemImage: "arrow.right") {
                    if let id = viewModel.generatedLectureID {
                        path.append(AppRoute.lecture(id))
                    }
                }
            }
        }
    }

    private var recordingTint: Color {
        switch viewModel.phase {
        case .recording: .red
        case .paused: .orange
        case .processing: .indigo
        default: .teal
        }
    }

    private var iconName: String {
        switch viewModel.phase {
        case .recording: "mic.fill"
        case .paused: "pause.fill"
        case .processing: "sparkles"
        case .completed: "checkmark"
        case .idle: "mic"
        }
    }

    private var statusText: String {
        switch viewModel.phase {
        case .idle: "Ready to record"
        case .recording: "Recording"
        case .paused: "Paused"
        case .processing(let message): message
        case .completed: "Saved"
        }
    }
}

#Preview {
    NavigationStack {
        RecordingView(path: .constant(NavigationPath()), speechService: SpeechTranscriptionService(), aiService: AppEnvironment().aiService)
    }
    .modelContainer(PreviewData.container)
}
