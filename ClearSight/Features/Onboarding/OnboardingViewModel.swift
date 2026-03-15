import AVFoundation
import ARKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var microphoneAuthorized = false
    @Published var deviceSupported = true
    @Published var hasCheckedPermissions = false

    var allPermissionsGranted: Bool {
        cameraAuthorized && microphoneAuthorized
    }

    var hasDeniedPermissions: Bool {
        hasCheckedPermissions && !allPermissionsGranted
    }

    func checkCapabilities() {
        deviceSupported = ARFaceTrackingConfiguration.isSupported
        checkCurrentStatus()
    }

    func requestAllPermissions() async {
        // Camera
        if !cameraAuthorized {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        }

        // Microphone (still needed for AR face tracking)
        if !microphoneAuthorized {
            let granted = await AVAudioApplication.requestRecordPermission()
            microphoneAuthorized = granted
        }

        hasCheckedPermissions = true
    }

    private func checkCurrentStatus() {
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (cameraStatus == .authorized)

        // Microphone
        microphoneAuthorized = (AVAudioApplication.shared.recordPermission == .granted)

        // If any have been explicitly denied/granted, we've checked
        let cameraDetermined = cameraStatus != .notDetermined
        hasCheckedPermissions = cameraDetermined
    }
}
