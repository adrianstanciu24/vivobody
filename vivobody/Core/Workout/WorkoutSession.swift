import Foundation
import SwiftUI

@Observable
final class WorkoutSession {
    var isActive = false
    var workoutName = "Custom Workout"
    var startTime: Date?
    var elapsedSeconds = 0
    var totalVolume = 0
    var setsDone = 0
    var exerciseCount = 0
    var currentExercise: String?

    private var timer: Timer?

    var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(name: String = "Custom Workout") {
        isActive = true
        workoutName = name
        startTime = .now
        elapsedSeconds = 0
        totalVolume = 0
        setsDone = 0
        exerciseCount = 0
        currentExercise = nil
        startTimer()
    }

    func finish() {
        stopTimer()
        isActive = false
    }

    func discard() {
        stopTimer()
        isActive = false
        elapsedSeconds = 0
        totalVolume = 0
        setsDone = 0
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
