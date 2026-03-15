import Foundation

/// Standard Snellen chart rows with their optical properties.
/// Each row defines the acuity fraction, LogMAR value, and the reference
/// letter height at the standard 6-metre testing distance.
struct SnellenRow: Identifiable {
    let id: String
    let acuity: String
    let logMAR: Double
    let referenceHeightMM: Double // Height of letter at 6m standard
    let letterCount: Int

    init(acuity: String, logMAR: Double, referenceHeightMM: Double, letterCount: Int = 5) {
        self.id = acuity
        self.acuity = acuity
        self.logMAR = logMAR
        self.referenceHeightMM = referenceHeightMM
        self.letterCount = letterCount
    }
}

/// Direction the tumbling E optotype is pointing.
enum EDirection: CaseIterable {
    case up, down, left, right

    /// Rotation angle to apply to a right-facing "E" glyph.
    var rotationDegrees: Double {
        switch self {
        case .right: return 0
        case .down:  return 90
        case .left:  return 180
        case .up:    return 270
        }
    }

    var arrowSymbol: String {
        switch self {
        case .up:    return "arrow.up"
        case .down:  return "arrow.down"
        case .left:  return "arrow.left"
        case .right: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .up:    return "Up"
        case .down:  return "Down"
        case .left:  return "Left"
        case .right: return "Right"
        }
    }
}

enum VisualAcuityScale {
    /// Standard Snellen rows from largest (worst acuity) to smallest (best acuity).
    /// Reference heights calculated from the standard: 6/6 letter subtends 5 arcmin at 6m = 8.73mm.
    /// Each step scales proportionally to the acuity denominator.
    static let standardRows: [SnellenRow] = [
        SnellenRow(acuity: "6/60", logMAR: 1.0, referenceHeightMM: 87.3, letterCount: 1),
        SnellenRow(acuity: "6/48", logMAR: 0.9, referenceHeightMM: 69.8, letterCount: 2),
        SnellenRow(acuity: "6/36", logMAR: 0.8, referenceHeightMM: 52.4, letterCount: 3),
        SnellenRow(acuity: "6/24", logMAR: 0.6, referenceHeightMM: 34.9, letterCount: 4),
        SnellenRow(acuity: "6/18", logMAR: 0.5, referenceHeightMM: 26.2, letterCount: 5),
        SnellenRow(acuity: "6/12", logMAR: 0.3, referenceHeightMM: 17.5, letterCount: 5),
        SnellenRow(acuity: "6/9",  logMAR: 0.2, referenceHeightMM: 13.1, letterCount: 6),
        SnellenRow(acuity: "6/7.5", logMAR: 0.1, referenceHeightMM: 10.9, letterCount: 6),
        SnellenRow(acuity: "6/6",  logMAR: 0.0, referenceHeightMM: 8.73, letterCount: 7),
        SnellenRow(acuity: "6/5",  logMAR: -0.1, referenceHeightMM: 7.28, letterCount: 7),
        SnellenRow(acuity: "6/4",  logMAR: -0.2, referenceHeightMM: 5.82, letterCount: 8),
    ]

    /// Generate a randomised set of directions for a given row.
    /// No consecutive duplicates, matching clinical chart conventions.
    static func randomDirections(count: Int) -> [EDirection] {
        var result: [EDirection] = []
        for _ in 0..<count {
            let candidates = EDirection.allCases.filter { $0 != result.last }
            result.append(candidates.randomElement()!)
        }
        return result
    }
}
