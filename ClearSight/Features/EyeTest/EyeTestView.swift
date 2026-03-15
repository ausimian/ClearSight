import SwiftUI

/// Main test screen that orchestrates calibration, eye cover prompts,
/// chart display, directional input, and results.
struct EyeTestView: View {
    @ObservedObject var arService: ARFaceTrackingService
    @StateObject private var viewModel = EyeTestViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch viewModel.testState {
            case .idle:
                Color.clear.onAppear {
                    viewModel.startTest(arService: arService)
                }

            case .calibrating:
                CalibrationView(arService: arService) {
                    viewModel.onCalibrated()
                }

            case .coveringEye(let which):
                EyeCoverPromptView(eyeToCover: which) {
                    viewModel.beginTestingEye(which: which.opposite)
                }

            case .testingEye:
                testingView

            case .showingResults:
                if let result = viewModel.result {
                    ResultsView(result: result) {
                        viewModel.resetTest()
                        dismiss()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Eye Test")
    }

    // MARK: - Testing View

    private var testingView: some View {
        VStack(spacing: 0) {
            // Header with current acuity line and distance
            testHeader

            Spacer()

            // Chart — rotated E optotypes
            ChartView(
                directions: viewModel.currentDirections,
                letterHeight: viewModel.currentLetterHeight,
                userResponseCount: viewModel.userResponses.count
            )
            .padding()

            Spacer()

            // Progress indicator
            progressIndicator

            // Direction progress
            directionProgressView

            // Directional input buttons
            directionalInputView

            // Skip/Can't read button
            Button("Can't read this line") {
                viewModel.skipRow()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
    }

    private var testHeader: some View {
        HStack {
            if case .testingEye(let eye, _) = viewModel.testState {
                Label(
                    "\(eye.displayName) Eye",
                    systemImage: "eye.fill"
                )
                .font(.headline)
            }

            Spacer()

            if let row = viewModel.currentRow {
                Text(row.acuity)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(viewModel.distanceCm)) cm")
                .font(.subheadline.monospaced())
                .foregroundStyle(distanceColor)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var distanceColor: Color {
        let deviation = abs(viewModel.distanceCm - DistanceMeasurementService.targetDistanceCm)
        if deviation <= DistanceMeasurementService.toleranceCm { return .green }
        if deviation <= DistanceMeasurementService.toleranceCm * 2 { return .orange }
        return .red
    }

    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<VisualAcuityScale.standardRows.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(progressColor(for: index))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func progressColor(for index: Int) -> Color {
        guard case .testingEye(_, let currentRow) = viewModel.testState else {
            return .secondary.opacity(0.2)
        }
        if index < currentRow { return .green }
        if index == currentRow { return .blue }
        return .secondary.opacity(0.2)
    }

    // MARK: - Directional Input

    private var directionalInputView: some View {
        VStack(spacing: 8) {
            // Undo button
            if !viewModel.userResponses.isEmpty {
                Button {
                    viewModel.undoLastResponse()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .padding(.bottom, 4)
            }

            // Direction buttons in a cross layout
            VStack(spacing: 4) {
                directionButton(.up)

                HStack(spacing: 24) {
                    directionButton(.left)
                    directionButton(.right)
                }

                directionButton(.down)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
    }

    private func directionButton(_ direction: EDirection) -> some View {
        Button {
            viewModel.submitDirection(direction)
        } label: {
            Image(systemName: direction.arrowSymbol)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(.tint.opacity(0.15))
                .clipShape(Circle())
        }
        .accessibilityLabel(direction.label)
    }

    private var directionProgressView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
                .imageScale(.small)

            Text("\(viewModel.userResponses.count + 1) of \(viewModel.currentDirections.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if !viewModel.userResponses.isEmpty {
                HStack(spacing: 4) {
                    Text("·")
                        .foregroundStyle(.tertiary)

                    ForEach(0..<viewModel.userResponses.count, id: \.self) { i in
                        Image(systemName: viewModel.userResponses[i].arrowSymbol)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
