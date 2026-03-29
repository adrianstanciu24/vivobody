import Foundation
import SwiftData
import SwiftUI

@Observable
final class WorkoutSession {
    var isActive = false
    var workoutName = "Custom Workout"
    var startTime: Date?
    var elapsedSeconds = 0
    var exercises: [SessionExercise] = []
    var currentExercise: String?

    private var timer: Timer?

    var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var exerciseCount: Int {
        exercises.count
    }

    var setsDone: Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter(\.completed).count
        }
    }

    var totalVolume: Int {
        exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter(\.completed).reduce(0) { $0 + $1.reps * $1.weight }
        }
    }

    func start(name: String = "Custom Workout") {
        isActive = true
        workoutName = name
        startTime = .now
        elapsedSeconds = 0
        exercises = []
        currentExercise = nil
        startTimer()
    }

    func addExercise(name: String, tags: String, sets: [SessionSet]? = nil) {
        let exercise = SessionExercise(
            name: name,
            tags: tags,
            sets: sets ?? Self.defaultSets()
        )
        exercises.append(exercise)
        currentExercise = name
    }

    func logSet(exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if let setIndex = exercises[index].sets.firstIndex(where: { !$0.completed }) {
            exercises[index].sets[setIndex].completed = true
        }
    }

    func finish() {
        stopTimer()
    }

    func save(modelContext: ModelContext) {
        let workout = Workout(startedAt: startTime ?? .now)
        workout.completedAt = .now

        for (index, sessionExercise) in exercises.enumerated() {
            let exercise = findOrCreateExercise(
                name: sessionExercise.name,
                tags: sessionExercise.tags,
                modelContext: modelContext
            )
            let workoutExercise = WorkoutExercise(
                order: index,
                workout: workout,
                exercise: exercise
            )

            for sessionSet in sessionExercise.sets where sessionSet.completed {
                let exerciseSet = ExerciseSet(
                    order: sessionSet.order,
                    reps: sessionSet.reps,
                    weight: Double(sessionSet.weight),
                    isCompleted: true,
                    workoutExercise: workoutExercise
                )
                workoutExercise.sets.append(exerciseSet)
            }

            workout.exercises.append(workoutExercise)
        }

        modelContext.insert(workout)
    }

    private func findOrCreateExercise(
        name: String,
        tags: String,
        modelContext: ModelContext
    ) -> Exercise {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == name }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        let muscleGroup = parseMuscleGroup(from: tags)
        let category = parseCategory(from: tags)
        let exercise = Exercise(name: name, muscleGroup: muscleGroup, category: category)
        modelContext.insert(exercise)
        return exercise
    }

    private func parseMuscleGroup(from tags: String) -> MuscleGroup {
        let lower = tags.lowercased()
        for group in MuscleGroup.allCases where lower.contains(group.rawValue) {
            return group
        }
        if lower.contains("chest") { return .chest }
        if lower.contains("back") { return .back }
        if lower.contains("shoulder") || lower.contains("delt") { return .shoulders }
        if lower.contains("bicep") { return .biceps }
        if lower.contains("tricep") { return .triceps }
        if lower.contains("leg") || lower.contains("quad") || lower.contains("ham") { return .legs }
        return .other
    }

    private func parseCategory(from tags: String) -> ExerciseCategory {
        let lower = tags.lowercased()
        for cat in ExerciseCategory.allCases where lower.contains(cat.rawValue) {
            return cat
        }
        return .other
    }

    func discard() {
        stopTimer()
        reset()
    }

    func reset() {
        isActive = false
        elapsedSeconds = 0
        exercises = []
        currentExercise = nil
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private static func defaultSets() -> [SessionSet] {
        (1 ... 4).map { order in
            SessionSet(order: order, reps: 8, weight: 185, rir: max(0, 4 - order))
        }
    }
}

// MARK: - Session Models

struct SessionExercise: Identifiable {
    let id = UUID()
    let name: String
    let tags: String
    var sets: [SessionSet]

    var currentSetNumber: Int {
        (sets.firstIndex(where: { !$0.completed }) ?? sets.count) + 1
    }

    var totalSets: Int {
        sets.count
    }

    var setProgress: String {
        "SET \(String(format: "%02d", currentSetNumber))/\(String(format: "%02d", totalSets))"
    }
}

struct SessionSet: Identifiable {
    let id = UUID()
    let order: Int
    var reps: Int
    var weight: Int
    var rir: Int
    var completed = false
}
