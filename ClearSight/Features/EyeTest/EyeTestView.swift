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
            
            // Letter counter showing progress through current row
            letterProgressView

            // Voice input
            voiceInputView

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

    // MARK: - Voice Input

    private var voiceInputView: some View {
        VStack(spacing: 12) {
            // Error state
            if let error = viewModel.speechService.error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    
                    if viewModel.speechService.authorizationStatus == .denied {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
            } else {
                // Last recognized letter with undo
                HStack(spacing: 16) {
                    if let letter = viewModel.speechService.lastRecognizedLetter {
                        Text(String(letter))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.tint)
                            .transition(.scale.combined(with: .opacity))
                            .id(viewModel.userResponses.count)
                    }

                    if !viewModel.userResponses.isEmpty {
                        Button {
                            viewModel.undoLastLetter()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.title)
                                .foregroundStyle(.orange)
                        }
                        .accessibilityLabel("Undo last letter")
                    }
                }

                // Listening indicator with processing state
                if viewModel.speechService.isListening {
                    if viewModel.speechService.isProcessing {
                        // Processing speech
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Processing...")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        // Ready for input
                        HStack(spacing: 8) {
                            Image(systemName: "mic.fill")
                                .foregroundStyle(.green)
                                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
                            Text("Ready — speak now")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.slash.fill")
                            .foregroundStyle(.secondary)
                        Text("Microphone not active")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
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
            }
        }
        .frame(height: 140)
        .animation(.easeInOut(duration: 0.2), value: viewModel.speechService.lastRecognizedLetter)
        .animation(.easeInOut(duration: 0.2), value: viewModel.speechService.error)
        .animation(.easeInOut(duration: 0.15), value: viewModel.speechService.isProcessing)
    }
    
    private var letterProgressView: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.blue)
                .imageScale(.small)
            
            Text("Letter \(viewModel.userResponses.count + 1) of \(viewModel.currentLetters.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            
            // Show recent responses
            if !viewModel.userResponses.isEmpty {
                HStack(spacing: 4) {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    
                    Text(viewModel.userResponses.map { String($0) }.joined(separator: " "))
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
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
