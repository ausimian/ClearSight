import SwiftUI

/// Main test screen that orchestrates calibration, eye cover prompts,
/// chart display, letter input, and results.
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

            // Chart letters
            ChartView(
                letters: viewModel.currentLetters,
                letterHeight: viewModel.currentLetterHeight,
                userResponseCount: viewModel.userResponses.count
            )
            .padding()

            Spacer()

            // Progress indicator
            progressIndicator

            // Letter input — tap grid or voice indicator
            if viewModel.inputMode == .tap {
                letterInputGrid
            } else {
                voiceInputView
            }

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

            Button {
                viewModel.toggleInputMode()
            } label: {
                Image(systemName: viewModel.inputMode == .tap ? "mic.fill" : "hand.tap.fill")
                    .font(.subheadline)
            }
            .accessibilityLabel(viewModel.inputMode == .tap ? "Switch to voice input" : "Switch to tap input")

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
        if index == currentRow { return .accentColor }
        return .secondary.opacity(0.2)
    }

    // MARK: - Voice Input

    private var voiceInputView: some View {
        VStack(spacing: 12) {
            // Last recognized letter
            if let letter = viewModel.speechService.lastRecognizedLetter {
                Text(String(letter))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                    .transition(.scale.combined(with: .opacity))
                    .id(viewModel.userResponses.count) // re-animate on each new letter
            }

            // Listening indicator
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
                Text("Listening — say each letter aloud")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Valid letters reference
            HStack(spacing: 6) {
                ForEach(VisualAcuityScale.sloanLetters, id: \.self) { letter in
                    Text(String(letter))
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 4)

            if let error = viewModel.speechService.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(height: 140)
        .animation(.easeInOut(duration: 0.2), value: viewModel.speechService.lastRecognizedLetter)
    }

    // MARK: - Letter Input

    private var letterInputGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(VisualAcuityScale.sloanLetters, id: \.self) { letter in
                Button {
                    viewModel.submitLetter(letter)
                } label: {
                    Text(String(letter))
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
