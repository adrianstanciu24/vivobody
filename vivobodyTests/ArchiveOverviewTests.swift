//
//  ArchiveOverviewTests.swift
//  vivobodyTests
//
//  Freezes archive PR membership for History rows and session exercise detail.
//

import Foundation
import Testing
@testable import vivobody

struct ArchiveOverviewTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func personalRecordsRetainTheirSessionAndExerciseIdentity() throws {
        let firstSessionID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        let targetSessionID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000102"))
        let laterSessionID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000103"))
        let firstBenchID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000201"))
        let weakerBenchID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000202"))
        let recordBenchID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000203"))
        let firstPressID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000204"))
        let equalBenchID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000205"))

        let accumulator = InsightsDimensionFixtures.replay([
            session(
                id: firstSessionID,
                daysAgo: 3,
                exercises: [exercise(id: firstBenchID, key: "bench", weight: 100)]
            ),
            session(
                id: targetSessionID,
                daysAgo: 2,
                exercises: [
                    exercise(id: weakerBenchID, key: "bench", weight: 90),
                    exercise(id: recordBenchID, key: "bench", weight: 110),
                    exercise(id: firstPressID, key: "press", weight: 60),
                ]
            ),
            session(
                id: laterSessionID,
                daysAgo: 1,
                exercises: [exercise(id: equalBenchID, key: "bench", weight: 110)]
            ),
        ])

        let overview = accumulator.archiveOverview(progress: [], now: now)

        #expect(overview.prSessionIDs == [firstSessionID, targetSessionID])
        #expect(overview.prExerciseIDsBySession[firstSessionID] == [firstBenchID])
        #expect(
            overview.prExerciseIDsBySession[targetSessionID]
                == [recordBenchID, firstPressID]
        )
        #expect(overview.prExerciseIDsBySession[laterSessionID] == nil)
    }

    private func exercise(
        id: UUID,
        key: String,
        weight: Double
    ) -> AnalyticsExerciseSnapshot {
        InsightsDimensionFixtures.exercise(
            [InsightsDimensionFixtures.set(8, weight: weight)],
            id: id,
            key: key
        )
    }

    private func session(
        id: UUID,
        daysAgo: TimeInterval,
        exercises: [AnalyticsExerciseSnapshot]
    ) -> AnalyticsSessionSnapshot {
        let date = now.addingTimeInterval(-daysAgo * 86400)
        return AnalyticsSessionSnapshot(
            id: id,
            startedAt: date,
            completedAt: date,
            bodyweightAtStart: 0,
            exercises: exercises
        )
    }
}
