import Foundation
import SwiftData

@Observable
final class HistoryViewModel {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func completedWorkoutsCount() -> Int {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
