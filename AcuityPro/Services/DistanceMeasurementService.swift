import Combine
import Foundation

/// Monitors distance from the AR service and determines when the user
/// has held the phone at the correct distance long enough to "lock" calibration.
@MainActor
final class DistanceMeasurementService: ObservableObject {

    // MARK: - Constants

    static let targetDistanceCm: Float = 33.0
    static let toleranceCm: Float = 3.0
    static let lockDurationSec: TimeInterval = 2.0

    // MARK: - Published State

    @Published var isInRange = false
    @Published var isLocked = false
    @Published var lockProgress: Double = 0  // 0.0 to 1.0

    // MARK: - Private

    private var lockStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?

    // MARK: - Monitoring

    func startMonitoring(arService: ARFaceTrackingService) {
        isLocked = false
        lockProgress = 0
        lockStartTime = nil

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .sink { [weak self] distance in
                self?.handleDistanceUpdate(distance)
            }
            .store(in: &cancellables)
    }

    func stopMonitoring() {
        cancellables.removeAll()
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func reset() {
        stopMonitoring()
        isLocked = false
        isInRange = false
        lockProgress = 0
        lockStartTime = nil
    }

    // MARK: - Private

    private func handleDistanceUpdate(_ distance: Float) {
        let inRange = abs(distance - Self.targetDistanceCm) <= Self.toleranceCm
        self.isInRange = inRange

        if inRange {
            if lockStartTime == nil {
                lockStartTime = Date()
                startProgressTimer()
            }
        } else {
            lockStartTime = nil
            lockProgress = 0
            isLocked = false
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard let startTime = lockStartTime else {
            lockProgress = 0
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)
        lockProgress = min(elapsed / Self.lockDurationSec, 1.0)

        if elapsed >= Self.lockDurationSec {
            isLocked = true
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }
}
