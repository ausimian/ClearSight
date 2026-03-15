import SwiftUI

/// Square tumbling E optotype drawn on a 5×5 grid.
/// The base orientation has prongs pointing right.
private struct TumblingEShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 5
        var path = Path()

        // Left vertical bar (backbone)
        path.addRect(CGRect(x: 0, y: 0, width: unit, height: 5 * unit))
        // Top horizontal bar
        path.addRect(CGRect(x: unit, y: 0, width: 4 * unit, height: unit))
        // Middle horizontal bar
        path.addRect(CGRect(x: unit, y: 2 * unit, width: 4 * unit, height: unit))
        // Bottom horizontal bar
        path.addRect(CGRect(x: unit, y: 4 * unit, width: 4 * unit, height: unit))

        return path
    }
}

/// Renders a single row of tumbling E optotypes at the correct scaled size.
struct ChartView: View {
    let directions: [EDirection]
    let letterHeight: CGFloat
    let userResponseCount: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: letterSpacing) {
                ForEach(Array(directions.enumerated()), id: \.offset) { index, direction in
                    VStack(spacing: 4) {
                        TumblingEShape()
                            .fill(letterColor(at: index))
                            .frame(width: letterHeight, height: letterHeight)
                            .rotationEffect(.degrees(direction.rotationDegrees))

                        // Cursor indicator showing which E to identify next
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
        }
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.2), value: userResponseCount)
    }

    private var letterSpacing: CGFloat {
        max(letterHeight * 0.3, 4)
    }

    private func letterColor(at index: Int) -> Color {
        if index < userResponseCount {
            return .secondary.opacity(0.3) // Already answered
        } else if index == userResponseCount {
            return .accentColor // Current E
        }
        return .primary
    }
}
