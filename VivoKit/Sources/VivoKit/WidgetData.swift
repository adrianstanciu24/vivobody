//
//  WidgetData.swift
//  vivobody
//
//  Codable snapshots exchanged through the App Group. The app writes
//  these plain value payloads from SwiftData; WidgetKit and ActivityKit
//  read them without importing the app target or persistence models.
//

import Foundation

public nonisolated enum WidgetShared {
    public static let appGroup = "group.astanciu.vivobody"
    public static let upNextKind = "vivobody.upNext"
    public static let consistencyKind = "vivobody.consistency"
    public static let signatureKind = "vivobody.signature"
    public static let strengthKind = "vivobody.strength"
    public static let activeWorkoutKind = "vivobody.activeWorkout"
    public static let startWorkoutControlKind = "vivobody.startWorkoutControl"
    public static let upNextSnapshotKey = "widgets.upNext.snapshot"
    public static let consistencySnapshotKey = "widgets.consistency.snapshot"
    public static let signatureSnapshotKey = "widgets.signature.snapshot"
    public static let strengthSnapshotKey = "widgets.strength.snapshot"
    public static let activeWorkoutSnapshotKey = "widgets.activeWorkout.snapshot"
    public static let weightUnitKey = "settings.weightUnit"
    public static let startWorkoutRequestKey = "widgets.intent.startWorkoutRequestedAt"
    public static let completeSetRequestKey = "widgets.intent.completeSetRequestedAt"
    public static let startTemplateWorkoutRequestKey = "widgets.intent.startTemplateId"
    public static let templatesSnapshotKey = "widgets.templates.snapshot"
    /// Bool — whether the Pro lifetime unlock is owned. Written by the
    /// app's ProStore on every entitlement change; read by the
    /// Signature and Consistency widgets to decide between real
    /// content and the locked placeholder. Widgets never touch
    /// StoreKit themselves.
    public static let proUnlockedKey = "settings.proUnlocked"
}

// MARK: - Versioned envelope

/// Wraps every widget snapshot written to the App Group so future
/// shape changes can be detected at decode time instead of silently
/// failing. The writer stamps `version` with the current schema
/// version; the reader checks it before extracting `payload`. Old
/// unversioned data (written before the envelope existed) is handled
/// by `WidgetSnapshotCodec.decode` which falls back to a raw decode.
public struct VersionedSnapshot<T: Codable>: Codable {
    public var version: Int
    public var payload: T

    public init(version: Int, payload: T) {
        self.version = version
        self.payload = payload
    }
}

/// Current snapshot schema version. Bump when any snapshot type's
/// fields change so the reader can reject stale data instead of
/// decoding garbage.
public nonisolated enum WidgetSnapshotVersion {
    public static let current = 1
}

/// Encode/decode helpers that wrap payloads in a `VersionedSnapshot`
/// envelope. On decode, tries the versioned envelope first and falls
/// back to a raw decode for backward compatibility with data written
/// before versioning was introduced.
public nonisolated enum WidgetSnapshotCodec {
    public static func encode<T: Codable>(_ value: T) -> Data? {
        let envelope = VersionedSnapshot(version: WidgetSnapshotVersion.current, payload: value)
        return try? JSONEncoder().encode(envelope)
    }

    public static func decode<T: Codable>(_ type: T.Type, from data: Data) -> T? {
        if let envelope = try? JSONDecoder().decode(VersionedSnapshot<T>.self, from: data) {
            guard envelope.version == WidgetSnapshotVersion.current else { return nil }
            return envelope.payload
        }
        // Fall back to unversioned data (pre-versioning writes).
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

public struct UpNextSnapshot: Codable, Hashable, Sendable {
    public enum KindValue: String, Codable, Hashable, Sendable {
        case scheduled, rest, unscheduled
    }

    public enum RestReasonValue: String, Codable, Hashable, Sendable {
        case offDay, doneToday
    }

    public var kind: KindValue
    public var templateName: String?
    public var exerciseCount: Int
    public var totalSets: Int
    public var totalVolume: Double
    public var easeOff: Bool
    public var restReason: RestReasonValue?
    public var nextTemplateName: String?
    public var daysUntil: Int
    public var readinessPhrase: String?
    public var exercises: [UpNextExerciseSnapshot]

    public init(
        kind: KindValue,
        templateName: String?,
        exerciseCount: Int,
        totalSets: Int,
        totalVolume: Double,
        easeOff: Bool,
        restReason: RestReasonValue?,
        nextTemplateName: String?,
        daysUntil: Int,
        readinessPhrase: String?,
        exercises: [UpNextExerciseSnapshot]
    ) {
        self.kind = kind
        self.templateName = templateName
        self.exerciseCount = exerciseCount
        self.totalSets = totalSets
        self.totalVolume = totalVolume
        self.easeOff = easeOff
        self.restReason = restReason
        self.nextTemplateName = nextTemplateName
        self.daysUntil = daysUntil
        self.readinessPhrase = readinessPhrase
        self.exercises = exercises
    }

    public static let placeholder = UpNextSnapshot(
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

    public static let empty = UpNextSnapshot(
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

public struct UpNextExerciseSnapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { name + setSpec }
    public var name: String
    public var setSpec: String

    public init(name: String, setSpec: String) {
        self.name = name
        self.setSpec = setSpec
    }
}

public struct ConsistencySnapshot: Codable, Hashable, Sendable {
    public var weeks: [[ConsistencyDaySnapshot]]
    public var sessionsPerWeek: Double
    public var weekStreak: Int
    public var averageRIR: Double?
    public var daysTrained: Int
    public var weeklyVolume: [Int]

    public init(
        weeks: [[ConsistencyDaySnapshot]],
        sessionsPerWeek: Double,
        weekStreak: Int,
        averageRIR: Double?,
        daysTrained: Int,
        weeklyVolume: [Int]
    ) {
        self.weeks = weeks
        self.sessionsPerWeek = sessionsPerWeek
        self.weekStreak = weekStreak
        self.averageRIR = averageRIR
        self.daysTrained = daysTrained
        self.weeklyVolume = weeklyVolume
    }

    public static let placeholder = ConsistencySnapshot(
        weeks: WidgetSampleData.consistencyWeeks,
        sessionsPerWeek: 2.5,
        weekStreak: 3,
        averageRIR: 2.1,
        daysTrained: 38,
        weeklyVolume: [8, 12, 9, 15, 18, 11, 13, 16, 20, 18, 17, 22, 12, 14, 19, 24, 21, 16, 13, 20, 23, 18, 25, 22, 17, 19]
    )

    public static let empty = ConsistencySnapshot(
        weeks: WidgetSampleData.emptyWeeks,
        sessionsPerWeek: 0,
        weekStreak: 0,
        averageRIR: nil,
        daysTrained: 0,
        weeklyVolume: Array(repeating: 0, count: 26)
    )
}

public struct ConsistencyDaySnapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { date.timeIntervalSinceReferenceDate.description }
    public var date: Date
    public var level: Int
    public var isInRange: Bool
    public var isToday: Bool

    public init(date: Date, level: Int, isInRange: Bool, isToday: Bool) {
        self.date = date
        self.level = level
        self.isInRange = isInRange
        self.isToday = isToday
    }
}

public struct SignatureSnapshot: Codable, Hashable, Sendable {
    public var petals: [SignaturePetalSnapshot]
    public var intensity: Double
    public var cadence: Double
    public var balance: Double
    public var dominantGroup: String?
    public var hasSignature: Bool
    public var verdictLine: String
    public var weekStreak: Int

    public init(
        petals: [SignaturePetalSnapshot],
        intensity: Double,
        cadence: Double,
        balance: Double,
        dominantGroup: String?,
        hasSignature: Bool,
        verdictLine: String,
        weekStreak: Int
    ) {
        self.petals = petals
        self.intensity = intensity
        self.cadence = cadence
        self.balance = balance
        self.dominantGroup = dominantGroup
        self.hasSignature = hasSignature
        self.verdictLine = verdictLine
        self.weekStreak = weekStreak
    }

    public static let placeholder = SignatureSnapshot(
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

    public static let empty = SignatureSnapshot(
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

public struct SignaturePetalSnapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { group }
    public var group: String
    public var volumeShare: Double
    public var development: Double

    public init(group: String, volumeShare: Double, development: Double) {
        self.group = group
        self.volumeShare = volumeShare
        self.development = development
    }
}

public struct StrengthSnapshot: Codable, Hashable, Sendable {
    /// Keeps the App Group payload small; the chart only needs the
    /// recent shape of the curve, not the full lift history.
    public static let maxPoints = 40

    /// The lead lift the board surfaces first (climbing lifts ahead
    /// of stalls and slides).
    public var exercise: String
    /// e1RM samples in canonical lb; the widget converts at display.
    public var points: [StrengthPointSnapshot]
    public var currentE1RM: Double
    public var bestE1RM: Double
    /// Precomputed in the app ("PR", "~3w", "flat", "down", ...) so the
    /// widget never re-derives trend logic.
    public var trendLabel: String
    public var climbingCount: Int
    public var stalledCount: Int
    public var slippingCount: Int
    public var hasData: Bool

    public init(
        exercise: String,
        points: [StrengthPointSnapshot],
        currentE1RM: Double,
        bestE1RM: Double,
        trendLabel: String,
        climbingCount: Int,
        stalledCount: Int,
        slippingCount: Int,
        hasData: Bool
    ) {
        self.exercise = exercise
        self.points = points
        self.currentE1RM = currentE1RM
        self.bestE1RM = bestE1RM
        self.trendLabel = trendLabel
        self.climbingCount = climbingCount
        self.stalledCount = stalledCount
        self.slippingCount = slippingCount
        self.hasData = hasData
    }

    public static let placeholder = StrengthSnapshot(
        exercise: "Bench Press",
        points: WidgetSampleData.strengthPoints,
        currentE1RM: 245,
        bestE1RM: 245,
        trendLabel: "PR",
        climbingCount: 1,
        stalledCount: 0,
        slippingCount: 0,
        hasData: true
    )

    public static let empty = StrengthSnapshot(
        exercise: "",
        points: [],
        currentE1RM: 0,
        bestE1RM: 0,
        trendLabel: "-",
        climbingCount: 0,
        stalledCount: 0,
        slippingCount: 0,
        hasData: false
    )
}

public struct StrengthPointSnapshot: Codable, Hashable, Identifiable, Sendable {
    public var id: String { date.timeIntervalSinceReferenceDate.description }
    public var date: Date
    /// Estimated 1-rep max in canonical lb.
    public var e1RM: Double
    /// This sample set a new all-time best when it was logged.
    public var isPR: Bool

    public init(date: Date, e1RM: Double, isPR: Bool) {
        self.date = date
        self.e1RM = e1RM
        self.isPR = isPR
    }
}

public struct ActiveWorkoutSnapshot: Codable, Hashable, Sendable {
    public var isActive: Bool
    public var exerciseName: String?
    public var exerciseIndex: Int
    public var totalExercises: Int
    public var setNumber: Int
    public var plannedSets: Int
    public var setSpec: String?
    public var isResting: Bool
    public var restEndsAt: Date?
    public var restDuration: TimeInterval
    public var totalVolume: Double
    public var totalSetsCompleted: Int

    public init(
        isActive: Bool,
        exerciseName: String?,
        exerciseIndex: Int,
        totalExercises: Int,
        setNumber: Int,
        plannedSets: Int,
        setSpec: String?,
        isResting: Bool,
        restEndsAt: Date?,
        restDuration: TimeInterval,
        totalVolume: Double,
        totalSetsCompleted: Int
    ) {
        self.isActive = isActive
        self.exerciseName = exerciseName
        self.exerciseIndex = exerciseIndex
        self.totalExercises = totalExercises
        self.setNumber = setNumber
        self.plannedSets = plannedSets
        self.setSpec = setSpec
        self.isResting = isResting
        self.restEndsAt = restEndsAt
        self.restDuration = restDuration
        self.totalVolume = totalVolume
        self.totalSetsCompleted = totalSetsCompleted
    }

    public static let placeholder = ActiveWorkoutSnapshot(
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

    public static let empty = ActiveWorkoutSnapshot(
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

public enum WidgetSampleData {
    public static var consistencyWeeks: [[ConsistencyDaySnapshot]] {
        makeWeeks(active: true)
    }

    public static var strengthPoints: [StrengthPointSnapshot] {
        let values: [Double] = [185, 190, 190, 195, 200, 205, 205, 212, 218, 225, 232, 245]
        let today = Calendar.current.startOfDay(for: Date())
        var runningMax = -Double.infinity
        return values.enumerated().map { index, value in
            let isPR = value > runningMax
            if isPR { runningMax = value }
            let date = Calendar.current.date(byAdding: .day, value: -7 * (values.count - 1 - index), to: today) ?? today
            return StrengthPointSnapshot(date: date, e1RM: value, isPR: isPR)
        }
    }

    public static var emptyWeeks: [[ConsistencyDaySnapshot]] {
        makeWeeks(active: false)
    }

    private static func makeWeeks(active: Bool) -> [[ConsistencyDaySnapshot]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
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
