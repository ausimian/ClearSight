import Combine
import SwiftUI

@MainActor
final class EyeTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var testState: TestState = .idle
    @Published var currentDirections: [EDirection] = []
    @Published var currentRow: SnellenRow?
    @Published var userResponses: [EDirection] = []
    @Published var currentLetterHeight: CGFloat = 20
    @Published var distanceCm: Float = 33
    @Published var result: EyeTestResult?

    // MARK: - Private

    private let scoringService = EyeTestScoringService()
    private var rightEyeRows: [(row: SnellenRow, directions: [EDirection])] = []
    private var leftEyeRows: [(row: SnellenRow, directions: [EDirection])] = []
    private var rightEyeAttempts: [RowAttempt] = []
    private var leftEyeAttempts: [RowAttempt] = []
    private var currentRowIndex = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Test Flow

    func startTest(arService: ARFaceTrackingService) {
        // Generate randomised direction sets for both eyes
        rightEyeRows = scoringService.generateTestRows()
        leftEyeRows = scoringService.generateTestRows()
        rightEyeAttempts = []
        leftEyeAttempts = []

        // Subscribe to distance updates for live scaling
        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dist in
                self?.distanceCm = dist
                self?.updateLetterHeight()
            }
            .store(in: &cancellables)

        testState = .calibrating
    }

    func onCalibrated() {
        testState = .coveringEye(which: .left) // Cover left, test right first
    }

    func beginTestingEye(which: Eye) {
        currentRowIndex = 0
        userResponses = []

        let rows = (which == .right) ? rightEyeRows : leftEyeRows
        guard !rows.isEmpty else { return }

        currentRowIndex = 0
        currentRow = rows[0].row
        currentDirections = rows[0].directions
        userResponses = []
        updateLetterHeight()

        testState = .testingEye(which: which, currentRow: 0)
    }

    func submitDirection(_ direction: EDirection) {
        guard case .testingEye(let eye, _) = testState else { return }

        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let expectedCount = rows[currentRowIndex].directions.count

        // Ignore input if we've already completed this row
        guard userResponses.count < expectedCount else { return }

        HapticFeedback.letterTapped()
        userResponses.append(direction)

        if userResponses.count >= expectedCount {
            completeCurrentRow(eye: eye)
        }
    }

    func undoLastResponse() {
        guard case .testingEye = testState else { return }
        guard !userResponses.isEmpty else { return }
        userResponses.removeLast()
        HapticFeedback.letterTapped()
    }

    func skipRow() {
        guard case .testingEye(let eye, _) = testState else { return }
        // Fill remaining responses with a guaranteed-wrong direction
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let shown = rows[currentRowIndex].directions
        let filled = userResponses.count
        for i in filled..<shown.count {
            let wrong = EDirection.allCases.first { $0 != shown[i] }!
            userResponses.append(wrong)
        }
        completeCurrentRow(eye: eye)
    }

    // MARK: - Private

    private func loadRow(index: Int, eye: Eye) {
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        guard index < rows.count else { return }

        currentRowIndex = index
        currentRow = rows[index].row
        currentDirections = rows[index].directions
        userResponses = []
        updateLetterHeight()
    }

    private func completeCurrentRow(eye: Eye) {
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let attempt = RowAttempt(
            row: rows[currentRowIndex].row,
            shownDirections: rows[currentRowIndex].directions,
            userResponses: userResponses
        )

        if eye == .right {
            rightEyeAttempts.append(attempt)
        } else {
            leftEyeAttempts.append(attempt)
        }

        if attempt.passed {
            HapticFeedback.linePassed()
        } else {
            HapticFeedback.lineFailed()
        }

        // If failed or no more rows, finish this eye
        let nextIndex = currentRowIndex + 1
        if !attempt.passed || nextIndex >= rows.count {
            finishEye(eye)
        } else {
            loadRow(index: nextIndex, eye: eye)
            testState = .testingEye(which: eye, currentRow: nextIndex)
        }
    }

    private func finishEye(_ eye: Eye) {
        if eye == .right {
            // Move to left eye
            testState = .coveringEye(which: .right)
        } else {
            // Both eyes done — show results
            let rightScore = scoringService.score(attempts: rightEyeAttempts)
            let leftScore = scoringService.score(attempts: leftEyeAttempts)

            result = EyeTestResult(
                rightEye: rightScore,
                leftEye: leftScore,
                testDistanceCm: distanceCm,
                deviceModel: scoringService.deviceModel()
            )

            HapticFeedback.testComplete()
            testState = .showingResults
        }
    }

    private func updateLetterHeight() {
        guard let row = currentRow else { return }
        let height = ChartScaler.letterHeight(for: row, atDistanceCm: distanceCm)
        currentLetterHeight = max(height, ChartScaler.minimumLetterHeight)
    }

    func resetTest() {
        cancellables.removeAll()
        testState = .idle
        result = nil
        currentDirections = []
        currentRow = nil
        userResponses = []
        rightEyeAttempts = []
        leftEyeAttempts = []
    }
}
