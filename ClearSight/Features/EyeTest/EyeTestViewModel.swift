import Combine
import SwiftUI

@MainActor
final class EyeTestViewModel: ObservableObject {

    // MARK: - Published State

    @Published var testState: TestState = .idle
    @Published var currentLetters: [Character] = []
    @Published var currentRow: SnellenRow?
    @Published var userResponses: [Character] = []
    @Published var currentLetterHeight: CGFloat = 20
    @Published var distanceCm: Float = 33
    @Published var result: EyeTestResult?

    let speechService = SpeechRecognitionService()

    // MARK: - Private

    private let scoringService = EyeTestScoringService()
    private var rightEyeRows: [(row: SnellenRow, letters: [Character])] = []
    private var leftEyeRows: [(row: SnellenRow, letters: [Character])] = []
    private var rightEyeAttempts: [RowAttempt] = []
    private var leftEyeAttempts: [RowAttempt] = []
    private var currentRowIndex = 0
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Test Flow

    func startTest(arService: ARFaceTrackingService) {
        // Generate randomised letter sets for both eyes
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

        // Subscribe to speech recognition results
        speechService.recognizedLetterPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] letter in
                self?.submitLetter(letter)
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

        // Set up the first row (without starting speech yet)
        currentRowIndex = 0
        currentRow = rows[0].row
        currentLetters = rows[0].letters
        userResponses = []
        updateLetterHeight()
        
        testState = .testingEye(which: which, currentRow: 0)
        
        // Always request speech authorization and start listening
        Task {
            let authorized = await speechService.requestAuthorization()
            guard authorized else {
                print("⚠️ Speech recognition not authorized: \(speechService.authorizationStatus)")
                return
            }
            
            // Clear any stale recognition results
            speechService.lastRecognizedLetter = nil
            
            // Small delay to ensure clean start
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            do {
                try speechService.startListening()
                print("✓ Speech recognition started successfully")
            } catch {
                print("❌ Failed to start listening: \(error)")
            }
        }
    }

    func submitLetter(_ letter: Character) {
        guard case .testingEye(let eye, _) = testState else { return }

        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let expectedCount = rows[currentRowIndex].letters.count
        
        // Ignore letters if we've already completed this row
        guard userResponses.count < expectedCount else {
            print("⚠️ Ignoring extra letter '\(letter)' - row already complete")
            return
        }

        HapticFeedback.letterTapped()
        userResponses.append(letter)

        if userResponses.count >= expectedCount {
            completeCurrentRow(eye: eye)
        }
    }

    func undoLastLetter() {
        guard case .testingEye = testState else { return }
        guard !userResponses.isEmpty else { return }
        userResponses.removeLast()
        HapticFeedback.letterTapped()
    }

    func skipRow() {
        guard case .testingEye(let eye, _) = testState else { return }
        // Fill remaining responses with blanks (wrong answers)
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let remaining = rows[currentRowIndex].letters.count - userResponses.count
        for _ in 0..<remaining {
            userResponses.append("?")
        }
        completeCurrentRow(eye: eye)
    }

    // MARK: - Private

    private func loadRow(index: Int, eye: Eye) {
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        guard index < rows.count else { return }

        currentRowIndex = index
        currentRow = rows[index].row
        currentLetters = rows[index].letters
        userResponses = []
        updateLetterHeight()

        // Stop listening and clear any pending recognition
        speechService.stopListening()
        speechService.lastRecognizedLetter = nil
        
        // Small delay to ensure previous session is fully stopped
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            do {
                try speechService.startListening()
                print("✓ Restarted speech recognition for new row")
            } catch {
                print("❌ Failed to restart listening: \(error)")
            }
        }
    }

    private func completeCurrentRow(eye: Eye) {
        let rows = (eye == .right) ? rightEyeRows : leftEyeRows
        let attempt = RowAttempt(
            row: rows[currentRowIndex].row,
            shownLetters: rows[currentRowIndex].letters,
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

    private func stopVoice() {
        speechService.stopListening()
    }

    private func finishEye(_ eye: Eye) {
        stopVoice()
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
        speechService.reset()
        cancellables.removeAll()
        testState = .idle
        result = nil
        currentLetters = []
        currentRow = nil
        userResponses = []
        rightEyeAttempts = []
        leftEyeAttempts = []
    }
}
