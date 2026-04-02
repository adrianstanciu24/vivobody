import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseLibraryViewModelTests {
    private func makeExercises() -> [Exercise] {
        [
            Exercise(
                catalogID: "front_squat",
                name: "Front Squat",
                muscleGroup: .legs,
                category: .barbell,
                primaryTag: "QUADS",
                secondaryTags: "BILATERAL SQUAT · BILATERAL"
            ),
            Exercise(
                catalogID: "romanian_deadlift",
                name: "Romanian Deadlift",
                muscleGroup: .legs,
                category: .barbell,
                primaryTag: "GLUTES",
                secondaryTags: "HIP HINGE · BILATERAL"
            )
        ]
    }

    @Test func filtersAreDerivedFromCatalogTags() {
        let vm = ExerciseLibraryViewModel()
        let filters = vm.filters(for: makeExercises())

        #expect(filters.map(\.name) == ["RECENT", "ALL", "FAVORITES", "GLUTES", "QUADS"])
    }

    @Test func sectionsRespectSelectedFilter() {
        let vm = ExerciseLibraryViewModel()
        let sections = vm.sections(for: makeExercises(), selectedFilter: "QUADS")

        #expect(sections.count == 1)
        #expect(sections.first?.title == "Quads")
        #expect(sections.first?.exercises.map(\.name) == ["Front Squat"])
    }
}
