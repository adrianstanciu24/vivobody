import Foundation

struct ExerciseCatalogFilter: Identifiable, Hashable {
    let name: String
    let count: Int?
    var isSpecial: Bool = false

    var id: String {
        name
    }
}

struct ExerciseCatalogSection: Identifiable {
    let title: String
    let exercises: [Exercise]

    var id: String {
        title
    }
}

@MainActor
enum ExerciseCatalogPresenter {
    static let recentFilter = "RECENT"
    static let allFilter = "ALL"
    static let favoritesFilter = "FAVORITES"

    static func filters(from exercises: [Exercise]) -> [ExerciseCatalogFilter] {
        let grouped = Dictionary(grouping: exercises, by: filterName(for:))

        let muscleGroupFilters = grouped.keys.sorted().map { key in
            ExerciseCatalogFilter(name: key, count: grouped[key]?.count)
        }

        let special: [ExerciseCatalogFilter] = [
            ExerciseCatalogFilter(name: recentFilter, count: nil, isSpecial: true),
            ExerciseCatalogFilter(name: allFilter, count: nil, isSpecial: true),
            ExerciseCatalogFilter(name: favoritesFilter, count: nil, isSpecial: true)
        ]

        return special + muscleGroupFilters
    }

    static func sections(
        from exercises: [Exercise],
        selectedFilter: String
    ) -> [ExerciseCatalogSection] {
        let filteredExercises: [Exercise] = if selectedFilter == "ALL" {
            exercises.sorted(by: exerciseSort)
        } else {
            exercises
                .filter { filterName(for: $0) == selectedFilter }
                .sorted(by: exerciseSort)
        }

        let grouped = Dictionary(grouping: filteredExercises) { exercise in
            filterName(for: exercise)
        }

        return grouped.keys.sorted().compactMap { key in
            guard let groupedExercises = grouped[key] else { return nil }
            return ExerciseCatalogSection(title: displayTitle(for: key), exercises: groupedExercises)
        }
    }

    static func recentExercises(
        from workouts: [Workout],
        limit: Int = 4
    ) -> [Exercise] {
        var seenCatalogIDs = Set<String>()
        var recentExercises: [Exercise] = []

        for workout in workouts.sorted(by: { $0.startedAt > $1.startedAt }) {
            for workoutExercise in workout.exercises.sorted(by: { $0.order < $1.order }) {
                guard let exercise = workoutExercise.exercise else { continue }
                guard seenCatalogIDs.insert(exercise.catalogID).inserted else { continue }

                recentExercises.append(exercise)

                if recentExercises.count == limit {
                    return recentExercises
                }
            }
        }

        return recentExercises
    }

    static func quickPicks(
        from exercises: [Exercise],
        limit: Int = 3
    ) -> [Exercise] {
        Array(exercises.sorted(by: exerciseSort).prefix(limit))
    }

    static func suggestions(
        from exercises: [Exercise],
        excluding excludedCatalogIDs: Set<String>,
        limit: Int = 3
    ) -> [Exercise] {
        Array(
            exercises
                .filter { !excludedCatalogIDs.contains($0.catalogID) }
                .sorted(by: exerciseSort)
                .prefix(limit)
        )
    }

    private static func filterName(for exercise: Exercise) -> String {
        if !exercise.primaryTag.isEmpty {
            return exercise.primaryTag.uppercased()
        }

        return exercise.muscleGroup.displayName.uppercased()
    }

    private static func displayTitle(for filterName: String) -> String {
        filterName
            .split(separator: " ")
            .map(\.capitalized)
            .joined(separator: " ")
    }

    private static func exerciseSort(_ lhs: Exercise, _ rhs: Exercise) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
