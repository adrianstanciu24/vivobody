import Foundation
import SwiftData

@Model
final class Workout {
    #Index<Workout>([\.startedAt], [\.completedAt])

    var startedAt: Date
    var completedAt: Date?
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(startedAt: Date = .now, notes: String = "") {
        self.startedAt = startedAt
        self.notes = notes
        exercises = []
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    var durationFormatted: String {
        guard let duration else { return "00:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var totalVolume: Int {
        exercises.reduce(0) { total, workoutExercise in
            total + workoutExercise.sets.filter(\.isCompleted).reduce(0) { sum, exerciseSet in
                sum + (exerciseSet.reps ?? 0) * Int(exerciseSet.weight ?? 0)
            }
        }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var exerciseCount: Int {
        exercises.count
    }

    var exerciseSummary: String {
        let muscles = exercises.map { $0.displayMuscleGroup.lowercased() }
        let unique = Array(Set(muscles)).sorted()
        let prefix = "\(exerciseCount) exercises"
        if unique.isEmpty { return prefix }
        return "\(prefix) \u{00B7} \(unique.joined(separator: ", "))"
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: startedAt).uppercased()
    }

    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: startedAt)
    }

    var dayOfWeekIndex: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: startedAt)
        return String(format: "%02d", weekday)
    }

    var relativeTimeAgo: String {
        let calendar = Calendar.current
        let now = Date.now
        let components = calendar.dateComponents([.minute, .hour, .day], from: startedAt, to: now)

        if let days = components.day, days == 0 {
            if let hours = components.hour, hours > 0 {
                return "\(hours)h ago"
            }
            if let minutes = components.minute {
                return "\(max(1, minutes))m ago"
            }
            return "Just now"
        }
        if let days = components.day, days == 1 {
            return "Yesterday"
        }
        if let days = components.day, days < 7 {
            return "\(days)d ago"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: startedAt)
    }

    var volumeFormatted: String {
        let vol = totalVolume
        if vol >= 1000 {
            return String(format: "%d,%03d lb", vol / 1000, vol % 1000)
        }
        return "\(vol) lb"
    }

    var setsFormatted: String {
        "\(totalSets) sets"
    }
}
