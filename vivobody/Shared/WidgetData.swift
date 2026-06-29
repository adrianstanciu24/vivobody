//
//  WidgetData.swift
//  vivobody
//
//  Codable snapshots exchanged through the App Group. The app writes
//  these plain value payloads from SwiftData; WidgetKit and ActivityKit
//  read them without importing the app target or persistence models.
//

import Foundation

nonisolated enum WidgetShared {
    static let appGroup = "group.astanciu.vivobody"
    static let upNextKind = "vivobody.upNext"
    static let consistencyKind = "vivobody.consistency"
    static let signatureKind = "vivobody.signature"
    static let activeWorkoutKind = "vivobody.activeWorkout"
    static let upNextSnapshotKey = "widgets.upNext.snapshot"
    static let consistencySnapshotKey = "widgets.consistency.snapshot"
    static let signatureSnapshotKey = "widgets.signature.snapshot"
    static let activeWorkoutSnapshotKey = "widgets.activeWorkout.snapshot"
    static let weightUnitKey = "settings.weightUnit"
    static let startWorkoutRequestKey = "widgets.intent.startWorkoutRequestedAt"
    static let completeSetRequestKey = "widgets.intent.completeSetRequestedAt"
    static let startTemplateWorkoutRequestKey = "widgets.intent.startTemplateId"
    static let templatesSnapshotKey = "widgets.templates.snapshot"
}

struct UpNextSnapshot: Codable, Hashable {
    enum KindValue: String, Codable, Hashable {
        case scheduled, rest, unscheduled
    }

    enum RestReasonValue: String, Codable, Hashable {
        case offDay, doneToday
    }

    var kind: KindValue
    var templateName: String?
    var exerciseCount: Int
    var totalSets: Int
    var totalVolume: Double
    var easeOff: Bool
    var restReason: RestReasonValue?
    var nextTemplateName: String?
    var daysUntil: Int
    var readinessPhrase: String?
    var exercises: [UpNextExerciseSnapshot]

    static let placeholder = UpNextSnapshot(
        kind: .scheduled,
        templateName: "Push Day",
        exerciseCount: 4,
        totalSets: 12,
        totalVolume: 12_600,
        easeOff: false,
        restReason: nil,
        nextTemplateName: nil,
        daysUntil: 0,
        readinessPhrase: "Fresh and in the zone.",
        exercises: [
            UpNextExerciseSnapshot(name: "Bench Press", setSpec: "3 x 8 @ 135 lb"),
            UpNextExerciseSnapshot(name: "Overhead Press", setSpec: "3 x 8 @ 95 lb"),
            UpNextExerciseSnapshot(name: "Incline Press", setSpec: "3 x 10 @ 105 lb"),
        ]
    )

    static let empty = UpNextSnapshot(
        kind: .unscheduled,
        templateName: nil,
        exerciseCount: 0,
        totalSets: 0,
        totalVolume: 0,
        easeOff: false,
        restReason: nil,
        nextTemplateName: nil,
        daysUntil: 0,
        readinessPhrase: nil,
        exercises: []
    )
}

struct UpNextExerciseSnapshot: Codable, Hashable, Identifiable {
    var id: String { name + setSpec }
    var name: String
    var setSpec: String
}

struct ConsistencySnapshot: Codable, Hashable {
    var weeks: [[ConsistencyDaySnapshot]]
    var sessionsPerWeek: Double
    var weekStreak: Int
    var averageRIR: Double?
    var daysTrained: Int
    var weeklyVolume: [Int]

    static let placeholder = ConsistencySnapshot(
        weeks: WidgetSampleData.consistencyWeeks,
        sessionsPerWeek: 2.5,
        weekStreak: 3,
        averageRIR: 2.1,
        daysTrained: 38,
        weeklyVolume: [8, 12, 9, 15, 18, 11, 13, 16, 20, 18, 17, 22, 12, 14, 19, 24, 21, 16, 13, 20, 23, 18, 25, 22, 17, 19]
    )

    static let empty = ConsistencySnapshot(
        weeks: WidgetSampleData.emptyWeeks,
        sessionsPerWeek: 0,
        weekStreak: 0,
        averageRIR: nil,
        daysTrained: 0,
        weeklyVolume: Array(repeating: 0, count: 26)
    )
}

struct ConsistencyDaySnapshot: Codable, Hashable, Identifiable {
    var id: String { date.timeIntervalSinceReferenceDate.description }
    var date: Date
    var level: Int
    var isInRange: Bool
    var isToday: Bool
}

struct SignatureSnapshot: Codable, Hashable {
    var petals: [SignaturePetalSnapshot]
    var intensity: Double
    var cadence: Double
    var balance: Double
    var dominantGroup: String?
    var hasSignature: Bool
    var verdictLine: String
    var weekStreak: Int

    static let placeholder = SignatureSnapshot(
        petals: [
            SignaturePetalSnapshot(group: "Chest", volumeShare: 0.24, development: 0.72),
            SignaturePetalSnapshot(group: "Back", volumeShare: 0.31, development: 0.86),
            SignaturePetalSnapshot(group: "Shoulders", volumeShare: 0.13, development: 0.58),
            SignaturePetalSnapshot(group: "Legs", volumeShare: 0.18, development: 0.62),
            SignaturePetalSnapshot(group: "Arms", volumeShare: 0.09, development: 0.45),
            SignaturePetalSnapshot(group: "Core", volumeShare: 0.05, development: 0.28),
        ],
        intensity: 0.68,
        cadence: 2.5,
        balance: 0.78,
        dominantGroup: "Back",
        hasSignature: true,
        verdictLine: "Back-led. Trained close to failure, 2.5x a week.",
        weekStreak: 3
    )

    static let empty = SignatureSnapshot(
        petals: [],
        intensity: 0.5,
        cadence: 0,
        balance: 0,
        dominantGroup: nil,
        hasSignature: false,
        verdictLine: "Log training to see your signature",
        weekStreak: 0
    )
}

struct SignaturePetalSnapshot: Codable, Hashable, Identifiable {
    var id: String { group }
    var group: String
    var volumeShare: Double
    var development: Double
}

struct ActiveWorkoutSnapshot: Codable, Hashable {
    var isActive: Bool
    var exerciseName: String?
    var exerciseIndex: Int
    var totalExercises: Int
    var setNumber: Int
    var plannedSets: Int
    var setSpec: String?
    var isResting: Bool
    var restEndsAt: Date?
    var restDuration: TimeInterval
    var totalVolume: Double
    var totalSetsCompleted: Int

    static let placeholder = ActiveWorkoutSnapshot(
        isActive: true,
        exerciseName: "Bench Press",
        exerciseIndex: 0,
        totalExercises: 4,
        setNumber: 3,
        plannedSets: 5,
        setSpec: "225 x 5",
        isResting: true,
        restEndsAt: Date().addingTimeInterval(83),
        restDuration: 120,
        totalVolume: 8_420,
        totalSetsCompleted: 12
    )

    static let empty = ActiveWorkoutSnapshot(
        isActive: false,
        exerciseName: nil,
        exerciseIndex: 0,
        totalExercises: 0,
        setNumber: 0,
        plannedSets: 0,
        setSpec: nil,
        isResting: false,
        restEndsAt: nil,
        restDuration: 0,
        totalVolume: 0,
        totalSetsCompleted: 0
    )
}

enum WidgetSampleData {
    static var consistencyWeeks: [[ConsistencyDaySnapshot]] {
        makeWeeks(active: true)
    }

    static var emptyWeeks: [[ConsistencyDaySnapshot]] {
        makeWeeks(active: false)
    }

    private static func makeWeeks(active: Bool) -> [[ConsistencyDaySnapshot]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = calendar.component(.weekday, from: today) - 1
        let currentWeekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: today) ?? today
        let start = calendar.date(byAdding: .day, value: -7 * 25, to: currentWeekStart) ?? today

        return (0..<26).map { week in
            (0..<7).map { day in
                let date = calendar.date(byAdding: .day, value: week * 7 + day, to: start) ?? today
                let level = active && date <= today && (week + day) % 3 == 0 ? ((week + day) % 4) + 1 : 0
                return ConsistencyDaySnapshot(
                    date: date,
                    level: level,
                    isInRange: date <= today,
                    isToday: calendar.isDate(date, inSameDayAs: today)
                )
            }
        }
    }
}
