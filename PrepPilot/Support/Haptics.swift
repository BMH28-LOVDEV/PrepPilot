import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    static func light() {
        impact(.light)
    }

    static func medium() {
        impact(.medium)
    }

    static func success() {
        notify(.success)
    }

    static func warning() {
        notify(.warning)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type)
        #endif
    }
}
