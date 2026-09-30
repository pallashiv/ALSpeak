import UIKit

/// Haptic confirmations, behind a protocol so view models can be tested without UIKit feedback.
@MainActor
protocol HapticsProviding {
    /// A phrase was just spoken.
    func phraseSpoken()
    /// The emergency alert fired.
    func emergency()
}

@MainActor
final class Haptics: HapticsProviding {
    private let notification = UINotificationFeedbackGenerator()

    func phraseSpoken() {
        notification.notificationOccurred(.success)
    }

    func emergency() {
        notification.notificationOccurred(.warning)
    }
}
