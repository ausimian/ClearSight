import Combine
import Foundation

@MainActor
final class CalibrationViewModel: ObservableObject {
    @Published var distanceCm: Float = 0
    @Published var isInRange = false
    @Published var isLocked = false
    @Published var lockProgress: Double = 0
    @Published var isTrackingFace = false

    private let distanceService = DistanceMeasurementService()
    private var cancellables = Set<AnyCancellable>()

    func startCalibration(arService: ARFaceTrackingService) {
        arService.startSession()
        distanceService.startMonitoring(arService: arService)

        arService.$distanceCm
            .receive(on: DispatchQueue.main)
            .assign(to: &$distanceCm)

        arService.$isTrackingFace
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTrackingFace)

        distanceService.$isInRange
            .receive(on: DispatchQueue.main)
            .assign(to: &$isInRange)

        distanceService.$isLocked
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocked)

        distanceService.$lockProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockProgress)
    }

    func stopCalibration(arService: ARFaceTrackingService) {
        distanceService.stopMonitoring()
        // Don't stop AR session — it's needed for the test
    }

    func reset() {
        distanceService.reset()
    }
}
