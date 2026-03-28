import Foundation
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
        reset()
    }

    func discard() {
        stopTimer()
        reset()
    }

    private func reset() {
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
