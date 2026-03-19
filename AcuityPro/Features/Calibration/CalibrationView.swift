import SwiftUI

struct CalibrationView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject private var viewModel = CalibrationViewModel()
    let onCalibrated: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Distance ring
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .foregroundStyle(.quaternary)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: viewModel.lockProgress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.lockProgress)

                VStack(spacing: 4) {
                    if viewModel.isTrackingFace {
                        Text("\(Int(viewModel.distanceCm))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("cm")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Looking for face...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Instructions
            VStack(spacing: 8) {
                Text(instructionText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("Target: \(Int(DistanceMeasurementService.targetDistanceCm)) cm")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear {
            viewModel.startCalibration(arService: arService)
        }
        .onDisappear {
            viewModel.stopCalibration(arService: arService)
        }
        .onChange(of: viewModel.isLocked) { _, locked in
            if locked {
                HapticFeedback.distanceLocked()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onCalibrated()
                }
            }
        }
    }

    private var ringColor: Color {
        if viewModel.isLocked { return .green }
        if viewModel.isInRange { return .green }
        return .orange
    }

    private var instructionText: String {
        if viewModel.isLocked {
            return "Locked! Starting test..."
        }
        if viewModel.isInRange {
            return "Hold steady..."
        }
        if !viewModel.isTrackingFace {
            return "Hold your phone at arm's length, screen facing you"
        }
        if viewModel.distanceCm < DistanceMeasurementService.targetDistanceCm - DistanceMeasurementService.toleranceCm {
            return "Move the phone further away"
        }
        return "Bring the phone a little closer"
    }
}
