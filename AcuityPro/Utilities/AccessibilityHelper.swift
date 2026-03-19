import UIKit

/// Provides haptic feedback at key moments during the test.
enum HapticFeedback {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// Distance locked during calibration.
    static func distanceLocked() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// User passed a line.
    static func linePassed() {
        impactLight.impactOccurred()
    }

    /// User failed a line (test for this eye ends).
    static func lineFailed() {
        impactMedium.impactOccurred()
    }

    /// Test complete — results ready.
    static func testComplete() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Letter tapped.
    static func letterTapped() {
        impactLight.impactOccurred(intensity: 0.5)
    }
}
