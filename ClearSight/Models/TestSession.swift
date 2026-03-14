import Foundation

/// Which eye is being tested or covered.
enum Eye: String, Codable {
    case left
    case right

    var displayName: String {
        switch self {
        case .left: return "LEFT"
        case .right: return "RIGHT"
        }
    }

    var opposite: Eye {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

/// How the user identifies chart letters.
enum InputMode: String, CaseIterable {
    case tap
    case voice
}

/// State machine for the eye test flow.
enum TestState: Equatable {
    case idle
    case calibrating
    case coveringEye(which: Eye)
    case testingEye(which: Eye, currentRow: Int)
    case showingResults

    static func == (lhs: TestState, rhs: TestState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.calibrating, .calibrating): return true
        case (.coveringEye(let a), .coveringEye(let b)): return a == b
        case (.testingEye(let a1, let a2), .testingEye(let b1, let b2)): return a1 == b1 && a2 == b2
        case (.showingResults, .showingResults): return true
        default: return false
        }
    }
}

/// Tracks letters shown and user responses for a single row.
struct RowAttempt {
    let row: SnellenRow
    let shownLetters: [Character]
    var userResponses: [Character] = []

    var isComplete: Bool {
        userResponses.count >= shownLetters.count
    }

    var correctCount: Int {
        zip(shownLetters, userResponses).filter { $0 == $1 }.count
    }

    var percentCorrect: Double {
        guard !shownLetters.isEmpty else { return 0 }
        return Double(correctCount) / Double(shownLetters.count)
    }

    /// A line is passed if ≥60% of letters are correct.
    var passed: Bool {
        percentCorrect >= 0.6
    }
}
