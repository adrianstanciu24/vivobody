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
    var restTimers: [UUID: Int] = [:]

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
                },
                targetRestSeconds: templateExercise.restSeconds
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
            sets: sets ?? Self.defaultSets(),
            targetRestSeconds: 120
        )
        exercises.append(exercise)
        currentExercise = exercise.name
    }

    func updateSet(exerciseID: UUID, setIndex: Int, values: SetValues) {
        guard let exIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              exercises[exIndex].sets.indices.contains(setIndex)
        else { return }
        exercises[exIndex].sets[setIndex].reps = values.reps
        exercises[exIndex].sets[setIndex].weight = values.weight
        exercises[exIndex].sets[setIndex].rir = values.rir
        exercises[exIndex].sets[setIndex].rom = values.rom
        exercises[exIndex].sets[setIndex].tempo = values.tempo
        exercises[exIndex].sets[setIndex].grip = values.grip
        exercises[exIndex].sets[setIndex].stance = values.stance
    }

    func logSet(exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        if let setIndex = exercises[index].sets.firstIndex(where: { !$0.completed }) {
            exercises[index].sets[setIndex].completed = true
            let hasMore = exercises[index].sets.contains(where: { !$0.completed })
            if hasMore {
                restTimers[exerciseID] = exercises[index].targetRestSeconds
            } else {
                restTimers.removeValue(forKey: exerciseID)
            }
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
                    rir: sessionSet.rir,
                    rom: sessionSet.rom,
                    tempo: sessionSet.tempo,
                    grip: sessionSet.grip,
                    stance: sessionSet.stance,
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
        restTimers = [:]
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.elapsedSeconds += 1
                self.tickRestTimers()
            }
        }
    }

    private func tickRestTimers() {
        for key in restTimers.keys {
            if let remaining = restTimers[key], remaining > 0 {
                restTimers[key] = remaining - 1
            }
        }
    }

    func restTimeRemaining(for exerciseID: UUID) -> Int {
        restTimers[exerciseID] ?? 0
    }

    func skipRestTimer(for exerciseID: UUID) {
        restTimers[exerciseID] = 0
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
    var targetRestSeconds: Int = 120

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

    var hasLoggedSet: Bool {
        sets.contains(where: \.completed)
    }

    var allSetsCompleted: Bool {
        !sets.isEmpty && sets.allSatisfy(\.completed)
    }

    var restTimerVisible: Bool {
        hasLoggedSet && !allSetsCompleted
    }
}

struct SetValues {
    let reps: Int
    let weight: Int
    let rir: Int
    let rom: String
    let tempo: String
    let grip: String
    let stance: String
}

struct SessionSet: Identifiable {
    let id = UUID()
    let order: Int
    var reps: Int
    var weight: Int
    var rir: Int
    var rom: String
    var tempo: String
    var grip: String
    var stance: String
    var completed = false

    init(
        order: Int,
        reps: Int,
        weight: Int,
        rir: Int,
        rom: String = "FULL",
        tempo: String = "CONTROLLED",
        grip: String = "NORMAL",
        stance: String = "NORMAL",
        completed: Bool = false
    ) {
        self.order = order
        self.reps = reps
        self.weight = weight
        self.rir = rir
        self.rom = rom
        self.tempo = tempo
        self.grip = grip
        self.stance = stance
        self.completed = completed
    }
}
