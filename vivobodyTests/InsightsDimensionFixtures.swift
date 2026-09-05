//
//  InsightsDimensionFixtures.swift
//  vivobodyTests
//
// Immutable fixtures shared by coverage, muscle-role, and stamina boundary tests.

import Foundation
@testable import vivobody

enum InsightsDimensionFixtures {
    static let now = Date(timeIntervalSince1970: 1_780_000_000)

    static func set(_ reps: Int = 10, weight: Double = 100, rir: Int? = nil,
                    completed: Bool = true, duration: Double = 0) -> AnalyticsSetSnapshot {
        AnalyticsSetSnapshot(weight: weight, reps: reps, duration: duration,
                             isCompleted: completed, repsInReserve: rir ?? 0, rirLogged: rir != nil)
    }

    static func exercise(_ sets: [AnalyticsSetSnapshot], key: String = "bench",
                         family: String? = "horizontal-press", planes: [MovementPlane]? = [.sagittal],
                         pattern: MovementPattern? = .push,
                         roles: [Muscle: Double] = [.bicepsBrachii: 0.5, .triceps: 1],
                         modality: ExerciseModality = .dynamicStrength,
                         tracking: TrackingMode = .reps, mode: ExerciseLoadMode = .external,
                         bodyweight: Double = 0) -> AnalyticsExerciseSnapshot {
        AnalyticsExerciseSnapshot(
            catalogID: key, familyID: family, catalogItemID: nil, name: key,
            group: .chest, trackingMode: tracking, modality: modality,
            loadProfile: .init(mode: mode, bodyweightFraction: mode == .bodyweightAdded ? 0.7 : 0),
            bodyweightAtSession: bodyweight, historyKey: key,
            classification: planes.map {
                ExerciseClassification(equipment: .barbell, mechanic: pattern == nil ? .isolation : .compound,
                                       trainingRole: .push, pattern: pattern,
                                       direction: pattern == .push || pattern == .pull ? .horizontal : nil,
                                       planes: $0, laterality: .bilateral)
            }, volumeCredits: roles, sets: sets
        )
    }

    static func session(_ exercises: [AnalyticsExerciseSnapshot], daysAgo: Double = 1,
                        completed: Bool = true) -> AnalyticsSessionSnapshot {
        let date = now.addingTimeInterval(-daysAgo * 86400)
        return AnalyticsSessionSnapshot(startedAt: date, completedAt: completed ? date : nil,
                                        bodyweightAtStart: 0, exercises: exercises)
    }

    static func replay(_ sessions: [AnalyticsSessionSnapshot]) -> AnalyticsAccumulator {
        AnalyticsAccumulator.replay(AnalyticsSnapshot(sessions: sessions))
    }
}
