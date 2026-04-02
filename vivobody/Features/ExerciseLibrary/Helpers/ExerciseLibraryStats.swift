import Foundation

struct ExerciseLibraryStats {
    var total: Int = 0
    var muscleGroups: Int = 0
    var performed: Int = 0
    var topGroup: String = "—"

    init() {}

    init(exercises: [Exercise]) {
        total = exercises.count

        let groups = Set(exercises.map(\.muscleGroup))
        muscleGroups = groups.count

        performed = exercises.count(where: { !$0.workoutExercises.isEmpty })

        let grouped = Dictionary(grouping: exercises.filter { !$0.workoutExercises.isEmpty }) { $0.muscleGroup }
        if let top = grouped.max(by: { $0.value.count < $1.value.count }) {
            topGroup = top.key.displayName.uppercased()
        }
    }
}
