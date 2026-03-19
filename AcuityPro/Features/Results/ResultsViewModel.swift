import SwiftUI

@MainActor
final class ResultsViewModel: ObservableObject {
    let result: EyeTestResult

    init(result: EyeTestResult) {
        self.result = result
    }

    func shareText() -> String {
        result.shareSummary
    }
}
