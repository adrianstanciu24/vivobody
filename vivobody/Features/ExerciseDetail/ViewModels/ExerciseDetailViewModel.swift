import Foundation

@MainActor
@Observable
final class ExerciseDetailViewModel {
    private(set) var profile: ExerciseProfile?

    func loadProfile(for exercise: Exercise) {
        guard !exercise.catalogID.isEmpty else { return }
        do {
            let store = try BundledExerciseProfileStore()
            profile = try store.loadProfile(catalogID: exercise.catalogID)
        } catch {
            profile = nil
        }
    }

    var hasProfile: Bool {
        profile != nil
    }
}
