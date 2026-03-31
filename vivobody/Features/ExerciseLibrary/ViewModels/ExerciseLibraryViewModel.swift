import Foundation

@MainActor
@Observable
final class ExerciseLibraryViewModel {
    func filters(for exercises: [Exercise]) -> [ExerciseCatalogFilter] {
        ExerciseCatalogPresenter.filters(from: exercises)
    }

    func sections(
        for exercises: [Exercise],
        selectedFilter: String
    ) -> [ExerciseCatalogSection] {
        ExerciseCatalogPresenter.sections(from: exercises, selectedFilter: selectedFilter)
    }
}
