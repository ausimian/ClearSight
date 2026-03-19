import SwiftUI

/// Overlay shown between test phases, instructing the user to cover one eye.
struct EyeCoverPromptView: View {
    let eyeToCover: Eye
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: eyeIcon)
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)

            VStack(spacing: 12) {
                Text("Cover your \(eyeToCover.displayName) eye")
                    .font(.title.bold())

                Text("Use your hand to gently cover your \(eyeToCover.displayName.lowercased()) eye. Keep both eyes open behind your hand.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Text("Testing: \(eyeToCover.opposite.displayName) eye")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                onReady()
            } label: {
                Text("I'm Ready")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var eyeIcon: String {
        switch eyeToCover {
        case .left: return "eye.trianglebadge.exclamationmark"
        case .right: return "eye.trianglebadge.exclamationmark"
        }
    }
}
