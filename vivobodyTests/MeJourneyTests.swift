//
//  MeJourneyTests.swift
//  vivobodyTests
//
//  Guards milestone target selection and ensures each progress track
//  represents the exact current/target ratio printed on its card.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MeJourneyTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func sessions(count: Int) -> [WorkoutSession] {
        (0..<count).map { offset in
            let date = now.addingTimeInterval(TimeInterval(-offset * 86_400))
            let session = WorkoutSession(startedAt: date)
            session.completedAt = date
            return session
        }
    }

    private func volumeSession(volume: Double) -> WorkoutSession {
        let exercise = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        exercise.sets.append(
            WorkoutSet(weight: volume, reps: 1, isCompleted: true)
        )
        let session = WorkoutSession(exercises: [exercise], startedAt: now)
        session.completedAt = now
        return session
    }

    @Test func countProgressMatchesDisplayedTargetRatio() {
        let milestone = sessions(count: 12).milestones(unit: .kg, prCount: 0)[0]

        #expect(milestone.valueLabel == "12")
        #expect(milestone.targetLabel == "50")
        #expect(abs(milestone.targetProgress - 0.24) < 0.001)
        #expect(milestone.achieved == false)
    }

    @Test func reachingThresholdAdvancesToNextVisibleTarget() {
        let milestone = sessions(count: 50).milestones(unit: .kg, prCount: 0)[0]

        #expect(milestone.valueLabel == "50")
        #expect(milestone.targetLabel == "100")
        #expect(abs(milestone.targetProgress - 0.5) < 0.001)
    }

    @Test func volumeProgressIsUnitInvariant() {
        let sessions = [volumeSession(volume: 80_000)]
        let kilograms = sessions.milestones(unit: .kg, prCount: 0)[1]
        let pounds = sessions.milestones(unit: .lb, prCount: 0)[1]

        #expect(abs(kilograms.targetProgress - 0.8) < 0.001)
        #expect(kilograms.targetProgress == pounds.targetProgress)
    }

    @Test func completedLadderUsesFullTrackWithoutTarget() {
        let milestone = [WorkoutSession]().milestones(unit: .kg, prCount: 100)[2]

        #expect(milestone.legend == "PRs")
        #expect(milestone.targetLabel == nil)
        #expect(milestone.targetProgress == 1)
        #expect(milestone.achieved)
    }
}
