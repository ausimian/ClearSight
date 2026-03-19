import SwiftUI

struct OnboardingView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var navigateToTest = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                HStack(spacing: 16) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)

                    Text("AcuityPro")
                        .font(.largeTitle.bold())
                }

                Text("A quick visual acuity screening using your iPhone's TrueDepth camera.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)

                if !viewModel.deviceSupported {
                    unsupportedDeviceView
                } else if viewModel.hasDeniedPermissions {
                    permissionDeniedView
                } else {
                    startButton
                }

                Spacer()

                Text("This is a screening tool only and does not replace a clinical eye examination.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            .navigationDestination(isPresented: $navigateToTest) {
                EyeTestView(arService: arService)
                    .navigationBarBackButtonHidden()
            }
        }
        .onAppear {
            viewModel.checkCapabilities()
        }
    }

    private var startButton: some View {
        Button {
            Task {
                await viewModel.requestAllPermissions()
                if viewModel.allPermissionsGranted {
                    navigateToTest = true
                }
            }
        } label: {
            Text("Begin Eye Test")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 40)
    }

    private var unsupportedDeviceView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("This device does not have a TrueDepth camera and cannot run this test.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            permissionRow("Camera", granted: viewModel.cameraAuthorized)
            permissionRow("Microphone", granted: viewModel.microphoneAuthorized)

            Text("All permissions are required. Please enable them in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 4)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func permissionRow(_ name: String, granted: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(granted ? .green : .red)
            Text(name)
                .font(.subheadline)
        }
    }
}
