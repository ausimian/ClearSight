import SwiftUI

struct ResultsView: View {
    let result: EyeTestResult
    let onTestAgain: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)

                    Text("Test Complete")
                        .font(.title.bold())
                }
                .padding(.top, 32)

                // Eye results
                HStack(spacing: 16) {
                    eyeResultCard(title: "Left Eye", score: result.leftEye)
                    eyeResultCard(title: "Right Eye", score: result.rightEye)
                }
                .padding(.horizontal)

                // Disclaimer
                Text("This is a screening tool only and does not replace a clinical eye examination.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Actions
                VStack(spacing: 12) {
                    ShareLink(
                        item: result.shareSummary,
                        preview: SharePreview("ClearSight Results", image: Image(systemName: "eye.circle"))
                    ) {
                        Label("Share Results", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 40)

                    Button {
                        onTestAgain()
                    } label: {
                        Text("Test Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 40)
                }
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }

    private func eyeResultCard(title: String, score: EyeScore) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)

            Text(score.snellenFraction)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("LogMAR \(String(format: "%.1f", score.logMAR))")
                .font(.caption)
                .foregroundStyle(.secondary)

            severityBadge(score.severity)

            Text("\(score.linesRead) lines read")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground(for: score.severity))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func severityBadge(_ severity: AcuitySeverity) -> some View {
        Text(severity.label)
            .font(.caption2)
            .foregroundStyle(severityColor(severity))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor(severity).opacity(0.1))
            .clipShape(Capsule())
    }

    private func severityColor(_ severity: AcuitySeverity) -> Color {
        switch severity {
        case .normal: return .green
        case .mild: return .orange
        case .significant: return .red
        }
    }

    private func cardBackground(for severity: AcuitySeverity) -> some ShapeStyle {
        severityColor(severity).opacity(0.05)
    }
}
