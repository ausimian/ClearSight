import Foundation
import UIKit

/// Manages test progression and scoring. Generates direction rows, records
/// responses, and computes the final EyeScore for each eye.
final class EyeTestScoringService {

    /// Generate a fresh set of randomised directions for all rows.
    func generateTestRows() -> [(row: SnellenRow, directions: [EDirection])] {
        VisualAcuityScale.standardRows.map { row in
            (row: row, directions: VisualAcuityScale.randomDirections(count: row.letterCount))
        }
    }

    /// Evaluate a completed set of row attempts and return the best acuity achieved.
    func score(attempts: [RowAttempt]) -> EyeScore {
        // Find the last (smallest) row that was passed
        var lastPassedIndex = -1
        for (index, attempt) in attempts.enumerated() {
            if attempt.passed {
                lastPassedIndex = index
            } else {
                // Stop at first failure — standard clinical protocol
                break
            }
        }

        if lastPassedIndex >= 0 {
            let passedRow = attempts[lastPassedIndex].row
            return EyeScore(
                snellenFraction: passedRow.acuity,
                logMAR: passedRow.logMAR,
                linesRead: lastPassedIndex + 1
            )
        } else {
            // Could not read even the largest line
            return EyeScore(
                snellenFraction: "<6/60",
                logMAR: 1.1,
                linesRead: 0
            )
        }
    }

    /// Get the device model identifier (e.g. "iPhone15,2").
    func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
