import SwiftUI

/// Renders a single row of Snellen chart letters at the correct scaled size.
struct ChartView: View {
    let letters: [Character]
    let letterHeight: CGFloat
    let userResponseCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: letterSpacing) {
                ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                    VStack(spacing: 4) {
                        Text(String(letter))
                            .font(.system(size: letterHeight, weight: .medium, design: .monospaced))
                            .foregroundStyle(letterColor(at: index))
                        
                        // Cursor indicator showing which letter to read next
                        if index == userResponseCount {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.accentColor)
                                .frame(width: max(letterHeight * 0.8, 8), height: 3)
                                .transition(.opacity)
                        } else {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.clear)
                                .frame(width: max(letterHeight * 0.8, 8), height: 3)
                        }
                    }
                }
            }
            
            // Instruction text
            Text("Read from left to right, including duplicate letters")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .accessibilityHidden(true) // Don't announce chart letters via VoiceOver
        .animation(.easeInOut(duration: 0.2), value: userResponseCount)
    }

    private var letterSpacing: CGFloat {
        max(letterHeight * 0.3, 4)
    }

    private func letterColor(at index: Int) -> Color {
        if index < userResponseCount {
            return .secondary.opacity(0.3) // Already answered
        } else if index == userResponseCount {
            return .accentColor // Current letter
        }
        return .primary
    }
}
