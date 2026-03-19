import UIKit

/// Converts clinical Snellen letter sizes to SwiftUI points based on the
/// user's real-time distance from the screen.
///
/// The Snellen chart is designed for 6 metres. Since the phone is held at
/// ~33cm, letters are scaled down so that their angular size matches what
/// the patient would see at 6m.
struct ChartScaler {

    // MARK: - Device PPI Lookup

    /// Native PPI for the current device. Falls back to 326 (standard Retina).
    static var nativePPI: CGFloat {
        // Common iPhone PPI values by model identifier prefix
        let model = deviceModelIdentifier()
        // iPhone X and later with Super Retina (458–460 PPI)
        if model.hasPrefix("iPhone10,3") || model.hasPrefix("iPhone10,6") || // X
           model.hasPrefix("iPhone11")   || // XS, XS Max, XR(326)
           model.hasPrefix("iPhone12")   || // 11 series
           model.hasPrefix("iPhone13")   || // 12 series
           model.hasPrefix("iPhone14")   || // 13 series
           model.hasPrefix("iPhone15")   || // 14 series
           model.hasPrefix("iPhone16")   || // 15 series
           model.hasPrefix("iPhone17") {    // 16 series
            // XR and 11 are 326 PPI but they're 2x scale, so the formula still works
            // Most Face ID iPhones are 458-460 PPI at 3x
            let scale = UIScreen.main.scale
            if scale >= 3.0 {
                return 460
            }
            return 326
        }
        return 326  // Safe fallback
    }

    /// Points per millimetre on the current display.
    static var pointsPerMM: CGFloat {
        let scale = UIScreen.main.scale
        return (nativePPI / scale) / 25.4
    }

    // MARK: - Scaling

    /// Compute the SwiftUI point height for a letter on a given Snellen row
    /// at the given viewing distance.
    ///
    /// - Parameters:
    ///   - row: The Snellen row being displayed.
    ///   - distanceCm: The user's current distance from the screen in cm.
    /// - Returns: The letter height in SwiftUI points.
    static func letterHeight(for row: SnellenRow, atDistanceCm distanceCm: Float) -> CGFloat {
        let scaleFactor = CGFloat(distanceCm) / 600.0  // 600cm = 6 metres
        let scaledHeightMM = row.referenceHeightMM * scaleFactor
        return scaledHeightMM * pointsPerMM
    }

    /// Minimum letter height that is physically renderable (1 point).
    static let minimumLetterHeight: CGFloat = 1.0

    // MARK: - Private

    private static func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
