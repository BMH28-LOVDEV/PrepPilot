import SwiftUI

struct PremiumBackground<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .indigo.opacity(0.18),
                    .clear,
                    .teal.opacity(0.10),
                    .pink.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
    }
}

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .premiumCard(padding: padding)
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                        .font(.headline)
                }
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(PrepPilotTheme.studyGradient, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .disabled(isLoading)
        .pressableScale()
        .accessibilityLabel(title)
    }
}

struct ToolbarIconButton: View {
    let systemImage: String
    let title: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(PrepPilotTheme.studyGradient)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 20)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color

    var body: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

struct WaveformView: View {
    let levels: [CGFloat]
    var tint: Color = .indigo

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint.gradient)
                        .frame(width: barWidth, height: max(6, proxy.size.height * max(0.06, min(level, 1))))
                        .animation(.spring(response: 0.22, dampingFraction: 0.76), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

struct LectureRow: View {
    let lecture: Lecture
    var noteCount: Int
    var cardCount: Int
    var quizCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                    .fill(PrepPilotTheme.accent(lecture.accentName).opacity(0.16))
                Image(systemName: "waveform")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PrepPilotTheme.accent(lecture.accentName))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(lecture.title)
                        .font(.headline)
                        .lineLimit(1)
                    if lecture.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(rowSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(noteCount)", systemImage: "doc.text")
                    Label("\(cardCount)", systemImage: "rectangle.on.rectangle")
                    Label("\(quizCount)", systemImage: "checklist")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var rowSubtitle: String {
        let date = PrepPilotFormatters.shortDate.string(from: lecture.createdAt)
        let duration = PrepPilotFormatters.durationString(lecture.duration)
        if lecture.course.isEmpty {
            return "\(date) • \(duration)"
        }
        return "\(lecture.course) • \(duration)"
    }
}

struct StudyTaskRow: View {
    let task: StudyTask
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : iconName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(task.isComplete ? .green : .indigo)
                    .frame(width: 34, height: 34)
                    .background((task.isComplete ? Color.green : Color.indigo).opacity(0.12), in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(task.subtitle) • Due \(PrepPilotFormatters.relative.localizedString(for: task.dueDate, relativeTo: .now))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isComplete ? "Mark incomplete" : "Mark complete")
    }

    private var iconName: String {
        switch task.kind {
        case .review: "book.closed"
        case .flashcards: "rectangle.on.rectangle"
        case .quiz: "checklist"
        case .notes: "doc.text"
        }
    }
}

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
