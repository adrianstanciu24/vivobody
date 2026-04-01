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
    var modelContext: ModelContext?

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

    func start(from template: WorkoutTemplate) {
        start(name: template.name)
        let sorted = template.exercises.sorted { $0.order < $1.order }
        for templateExercise in sorted {
            let muscleGroup = templateExercise.exercise?.muscleGroup ?? .other
            let exercise = SessionExercise(
                catalogID: templateExercise.catalogID,
                name: templateExercise.name,
                primaryTag: templateExercise.primaryTag,
                secondaryTags: templateExercise.secondaryTags,
                muscleGroup: muscleGroup,
                sets: (1 ... templateExercise.targetSets).map { order in
                    SessionSet(
                        order: order,
                        reps: templateExercise.targetReps,
                        weight: 0,
                        rir: max(0, 4 - order)
                    )
                }
            )
            exercises.append(exercise)
        }
        currentExercise = exercises.first?.name
        template.timesUsed += 1
        template.lastUsedAt = .now
    }

    func addExercise(_ selectedExercise: Exercise, sets: [SessionSet]? = nil) {
        let exercise = SessionExercise(
            catalogID: selectedExercise.catalogID,
            name: selectedExercise.name,
            primaryTag: selectedExercise.primaryTag,
            secondaryTags: selectedExercise.secondaryTags,
            muscleGroup: selectedExercise.muscleGroup,
            sets: sets ?? Self.defaultSets()
        )
        exercises.append(exercise)
        currentExercise = exercise.name
    }

    func updateCurrentSet(exerciseID: UUID, reps: Int, weight: Int, rir: Int) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if let setIndex = exercises[index].sets.firstIndex(where: { !$0.completed }) {
            exercises[index].sets[setIndex].reps = reps
            exercises[index].sets[setIndex].weight = weight
            exercises[index].sets[setIndex].rir = rir
        }
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

    func save() {
        guard let modelContext else { return }
        let workout = Workout(startedAt: startTime ?? .now)
        workout.completedAt = .now

        for (index, sessionExercise) in exercises.enumerated() {
            let exercise = findOrCreateExercise(
                sessionExercise,
                modelContext: modelContext
            )
            let workoutExercise = WorkoutExercise(
                order: index,
                exerciseCatalogIDSnapshot: sessionExercise.catalogID,
                exerciseNameSnapshot: sessionExercise.name,
                exercisePrimaryTagSnapshot: sessionExercise.primaryTag,
                exerciseSecondaryTagsSnapshot: sessionExercise.secondaryTags,
                exerciseMuscleGroupSnapshot: sessionExercise.muscleGroup.displayName,
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
        _ sessionExercise: SessionExercise,
        modelContext: ModelContext
    ) -> Exercise {
        let catalogID = sessionExercise.catalogID
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.catalogID == catalogID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let name = sessionExercise.name
        let fallbackDescriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == name }
        )
        if let existingByName = try? modelContext.fetch(fallbackDescriptor).first {
            existingByName.catalogID = sessionExercise.catalogID
            existingByName.primaryTag = sessionExercise.primaryTag
            existingByName.secondaryTags = sessionExercise.secondaryTags
            existingByName.muscleGroup = sessionExercise.muscleGroup
            return existingByName
        }

        let exercise = Exercise(
            catalogID: sessionExercise.catalogID,
            name: sessionExercise.name,
            muscleGroup: sessionExercise.muscleGroup,
            category: parseCategory(from: sessionExercise.tags),
            primaryTag: sessionExercise.primaryTag,
            secondaryTags: sessionExercise.secondaryTags
        )
        modelContext.insert(exercise)
        return exercise
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
    let catalogID: String
    let name: String
    let primaryTag: String
    let secondaryTags: String
    let muscleGroup: MuscleGroup
    var sets: [SessionSet]

    var tags: String {
        guard !secondaryTags.isEmpty else { return primaryTag }
        return "\(primaryTag) · \(secondaryTags)"
    }

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
