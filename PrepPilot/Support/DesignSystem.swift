import SwiftUI

enum PrepPilotTheme {
    static let cornerRadius: CGFloat = 8
    static let compactSpacing: CGFloat = 8
    static let contentSpacing: CGFloat = 16
    static let sectionSpacing: CGFloat = 24

    static func accent(_ name: String) -> Color {
        switch name {
        case "teal": .teal
        case "mint": .mint
        case "coral": .pink
        case "amber": .orange
        case "blue": .blue
        default: .indigo
        }
    }

    static let studyGradient = LinearGradient(
        colors: [.indigo, .teal, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum PrepPilotFormatters {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static let duration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    static func durationString(_ interval: TimeInterval) -> String {
        duration.string(from: interval) ?? "0:00"
    }
}

extension View {
    func premiumCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
    }

    func pressableScale() -> some View {
        buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
