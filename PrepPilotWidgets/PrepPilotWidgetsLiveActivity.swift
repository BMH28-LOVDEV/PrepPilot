import ActivityKit
import SwiftUI
import WidgetKit

struct PrepPilotRecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var isPaused: Bool
        var audioLevel: Double
        var waveformLevels: [Double]
        var statusText: String
    }

    var lectureTitle: String
    var courseName: String
}

struct PrepPilotWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrepPilotRecordingActivityAttributes.self) { context in
            PrepPilotLockScreenRecordingView(context: context)
                .activityBackgroundTint(PrepPilotLiveActivityTheme.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PrepPilotDynamicIslandStatusPill(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(Self.elapsedText(context.state.elapsedSeconds))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .accessibilityLabel("Recording duration \(Self.elapsedText(context.state.elapsedSeconds))")
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.lectureTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(context.attributes.courseName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    PrepPilotRecordingWaveform(
                        levels: context.state.waveformLevels,
                        fallbackLevel: context.state.audioLevel,
                        isPaused: context.state.isPaused
                    )
                        .frame(height: 28)
                        .padding(.top, 2)
                }
            } compactLeading: {
                PrepPilotRecordingWaveform(
                    levels: context.state.waveformLevels,
                    fallbackLevel: context.state.audioLevel,
                    isPaused: context.state.isPaused,
                    maxBars: 7
                )
                .frame(width: 30, height: 18)
                    .accessibilityLabel(context.state.isPaused ? "Recording paused" : "Recording")
            } compactTrailing: {
                Text(Self.compactElapsedText(context.state.elapsedSeconds))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .accessibilityLabel("Recording duration \(Self.elapsedText(context.state.elapsedSeconds))")
            } minimal: {
                ZStack {
                    Circle()
                        .fill((context.state.isPaused ? PrepPilotLiveActivityTheme.paused : PrepPilotLiveActivityTheme.recording).opacity(0.24))
                    Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(context.state.isPaused ? PrepPilotLiveActivityTheme.paused : PrepPilotLiveActivityTheme.recording)
                }
                .accessibilityLabel(context.state.isPaused ? "PrepPilot recording paused" : "PrepPilot recording")
            }
            .keylineTint(context.state.isPaused ? PrepPilotLiveActivityTheme.paused : PrepPilotLiveActivityTheme.recording)
        }
    }

    private static func elapsedText(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let remainingSeconds = clampedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private static func compactElapsedText(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct PrepPilotLockScreenRecordingView: View {
    let context: ActivityViewContext<PrepPilotRecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(PrepPilotLiveActivityTheme.softFlowGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PrepPilotLiveActivityTheme.strokeFlowGradient, lineWidth: 1)
                    }

                Image(systemName: context.state.isPaused ? "pause.fill" : "waveform")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(PrepPilotLiveActivityTheme.flowGradient)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.lectureTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(context.attributes.courseName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }

                PrepPilotRecordingWaveform(
                    levels: context.state.waveformLevels,
                    fallbackLevel: context.state.audioLevel,
                    isPaused: context.state.isPaused
                )
                    .frame(height: 24)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.70))
                        .offset(x: -2)
                    Text(elapsedText)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text(context.state.isPaused ? "Paused" : "Recording")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(statusTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(statusTint.opacity(0.16), in: Capsule())
            }
        }
        .padding(16)
        .background(PrepPilotLiveActivityTheme.backgroundFlowGradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusTint: Color {
        context.state.isPaused ? PrepPilotLiveActivityTheme.paused : PrepPilotLiveActivityTheme.recording
    }

    private var elapsedText: String {
        let seconds = max(0, context.state.elapsedSeconds)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct PrepPilotDynamicIslandStatusPill: View {
    let context: ActivityViewContext<PrepPilotRecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: context.state.isPaused ? "pause.fill" : "mic.fill")
                .font(.caption.weight(.bold))
            Text(context.state.isPaused ? "Paused" : "Live")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(PrepPilotLiveActivityTheme.flowGradient)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(PrepPilotLiveActivityTheme.softFlowGradient, in: Capsule())
    }

    private var statusTint: Color {
        context.state.isPaused ? PrepPilotLiveActivityTheme.paused : PrepPilotLiveActivityTheme.recording
    }
}

private struct PrepPilotRecordingWaveform: View {
    let levels: [Double]
    let fallbackLevel: Double
    let isPaused: Bool
    var maxBars = 24

    var body: some View {
        GeometryReader { proxy in
            let samples = displayLevels
            let spacing: CGFloat = proxy.size.width < 40 ? 2 : 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(max(samples.count - 1, 0))) / CGFloat(max(samples.count, 1)))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(waveformGradient)
                        .frame(width: barWidth, height: barHeight(for: level, in: proxy.size.height))
                        .opacity(isPaused ? 0.46 : 1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var waveformGradient: LinearGradient {
        LinearGradient(
            colors: [
                PrepPilotLiveActivityTheme.recording,
                PrepPilotLiveActivityTheme.indigo,
                PrepPilotLiveActivityTheme.teal
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var displayLevels: [Double] {
        let cleaned = levels
            .suffix(maxBars)
            .map { min(max($0, 0.06), 1) }

        guard !cleaned.isEmpty else {
            return Array(repeating: min(max(fallbackLevel, 0.06), 1), count: maxBars)
        }

        if cleaned.count >= maxBars {
            return Array(cleaned)
        }

        let padding = Array(repeating: 0.06, count: maxBars - cleaned.count)
        return padding + cleaned
    }

    private func barHeight(for level: Double, in availableHeight: CGFloat) -> CGFloat {
        let normalizedLevel = min(max(level, 0.06), 1)
        let minimum = max(4, availableHeight * 0.14)
        let maximum = max(minimum, availableHeight)
        return minimum + CGFloat(normalizedLevel) * (maximum - minimum)
    }
}

private enum PrepPilotLiveActivityTheme {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.14)
    static let card = Color.white.opacity(0.10)
    static let recording = Color(red: 1.00, green: 0.28, blue: 0.36)
    static let paused = Color(red: 1.00, green: 0.65, blue: 0.24)
    static let indigo = Color(red: 0.48, green: 0.36, blue: 1.00)
    static let teal = Color(red: 0.17, green: 0.82, blue: 0.76)
    static let flowGradient = LinearGradient(
        colors: [recording, indigo, teal],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    static let softFlowGradient = LinearGradient(
        colors: [recording.opacity(0.18), indigo.opacity(0.18), teal.opacity(0.18)],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    static let strokeFlowGradient = LinearGradient(
        colors: [recording.opacity(0.34), indigo.opacity(0.34), teal.opacity(0.34)],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
    static let backgroundFlowGradient = LinearGradient(
        colors: [recording.opacity(0.08), indigo.opacity(0.06), teal.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension PrepPilotRecordingActivityAttributes {
    fileprivate static var preview: PrepPilotRecordingActivityAttributes {
        PrepPilotRecordingActivityAttributes(
            lectureTitle: "Cellular Respiration",
            courseName: "Biology"
        )
    }
}

extension PrepPilotRecordingActivityAttributes.ContentState {
    fileprivate static var recording: PrepPilotRecordingActivityAttributes.ContentState {
        PrepPilotRecordingActivityAttributes.ContentState(
            elapsedSeconds: 1_238,
            isPaused: false,
            audioLevel: 0.72,
            waveformLevels: [0.12, 0.22, 0.38, 0.64, 0.92, 0.50, 0.28, 0.70, 0.84, 0.32, 0.18, 0.42, 0.76, 0.95, 0.62, 0.36, 0.16, 0.52, 0.88, 0.44, 0.26, 0.66, 0.78, 0.34],
            statusText: "Recording"
        )
    }

    fileprivate static var paused: PrepPilotRecordingActivityAttributes.ContentState {
        PrepPilotRecordingActivityAttributes.ContentState(
            elapsedSeconds: 1_284,
            isPaused: true,
            audioLevel: 0.12,
            waveformLevels: Array(repeating: 0.08, count: 24),
            statusText: "Paused"
        )
    }
}

#Preview("Recording", as: .content, using: PrepPilotRecordingActivityAttributes.preview) {
    PrepPilotWidgetsLiveActivity()
} contentStates: {
    PrepPilotRecordingActivityAttributes.ContentState.recording
    PrepPilotRecordingActivityAttributes.ContentState.paused
}
