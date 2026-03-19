import Foundation

struct EyeScore: Codable {
    let snellenFraction: String   // e.g. "6/12"
    let logMAR: Double            // e.g. 0.3
    let linesRead: Int

    /// Severity category for traffic-light display.
    var severity: AcuitySeverity {
        if logMAR <= 0.2 { return .normal }        // 6/6 – 6/9
        if logMAR <= 0.5 { return .mild }           // 6/12 – 6/18
        return .significant                         // 6/24+
    }
}

enum AcuitySeverity: String, Codable {
    case normal
    case mild
    case significant

    var label: String {
        switch self {
        case .normal: return "Normal vision"
        case .mild: return "Mild impairment — consider an eye test"
        case .significant: return "Significant impairment — recommend optometrist"
        }
    }
}

struct EyeTestResult: Codable, Identifiable {
    let id: UUID
    let date: Date
    let rightEye: EyeScore
    let leftEye: EyeScore
    let testDistanceCm: Float
    let deviceModel: String

    init(date: Date = Date(), rightEye: EyeScore, leftEye: EyeScore, testDistanceCm: Float, deviceModel: String) {
        self.id = UUID()
        self.date = date
        self.rightEye = rightEye
        self.leftEye = leftEye
        self.testDistanceCm = testDistanceCm
        self.deviceModel = deviceModel
    }

    /// Plain text summary suitable for sharing.
    var shareSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return """
        AcuityPro Eye Test Results
        Date: \(formatter.string(from: date))

        Right Eye: \(rightEye.snellenFraction) (LogMAR \(String(format: "%.1f", rightEye.logMAR)))
        Left Eye:  \(leftEye.snellenFraction) (LogMAR \(String(format: "%.1f", leftEye.logMAR)))

        Test distance: \(String(format: "%.0f", testDistanceCm)) cm
        Device: \(deviceModel)

        This is a screening tool only and does not replace a clinical eye examination.
        """
    }
}
