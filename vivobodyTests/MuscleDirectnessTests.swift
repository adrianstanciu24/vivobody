//
//  MuscleDirectnessTests.swift
//  vivobodyTests
//
// Directness retains snapshotted roles, effort pricing, and primary-only examples.

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MuscleDirectnessTests {
    private typealias F = InsightsDimensionFixtures

    @Test func primaryAndSecondarySplitConservesMuscleVolume() throws {
        let direct = F.exercise([F.set(), F.set()], roles: [.bicepsBrachii: 1])
        let row = F.exercise([F.set(), F.set(), F.set(), F.set()], key: "row", roles: [.bicepsBrachii: 0.5])
        let report = F.replay([F.session([direct], daysAgo: 730), F.session([row])]).muscleDirectness(now: F.now)
        let biceps = try #require(report.rows.first { $0.muscle == .bicepsBrachii })
        #expect(biceps.direct == 2)
        #expect(biceps.indirect == 2)
        #expect(biceps.total == 4)
        #expect(biceps.indirectShare == 0.5)
        #expect(biceps.targetedSources.first?.name == "bench")
        #expect(biceps.targetedSources.first?.sets == 2)
        #expect(biceps.supportingSources.first?.name == "row")
        #expect(biceps.supportingSources.first?.sets == 2)
    }

    @Test func discountedSecondaryDoesNotBecomeDirectAndStabilizersEarnIndirectCredit() throws {
        let exercise = F.exercise([F.set(rir: 4)], roles: [.bicepsBrachii: 0.5, .triceps: 0.1])
        let report = F.replay([F.session([exercise])]).muscleDirectness(now: F.now)
        let biceps = try #require(report.supportingOnly.first)
        #expect(biceps.direct == 0)
        #expect(abs(biceps.indirect - 0.3) < 0.000001)
        #expect(biceps.indirectShare == 1)
        #expect(abs((report.rows.first { $0.muscle == .triceps }?.indirect ?? 0) - 0.06) < 1e-9)
    }

    @Test func includesAllHistoryAndExcludesFutureLiveAndPowerWork() {
        let row = F.exercise([F.set()])
        let archive = [F.session([row], daysAgo: 0), F.session([row], daysAgo: 28),
                       F.session([row], daysAgo: 730),
                       F.session([row], daysAgo: -1), F.session([row], completed: false),
                       F.session([F.exercise([F.set()], modality: .power)])]
        let report = F.replay(archive).muscleDirectness(now: F.now)
        #expect(report.supportingOnly.first?.indirect == 1.5)
    }

    @Test func sortsSupportingOnlyMusclesByCreditedVolume() {
        let big = F.exercise(Array(repeating: F.set(), count: 8), roles: [.bicepsBrachii: 0.5])
        let tiny = F.exercise([F.set()], key: "tiny", roles: [.deltoidPosterior: 0.5])
        let report = F.replay([F.session([big, tiny])]).muscleDirectness(now: F.now)
        #expect(report.supportingOnly.first?.muscle == .bicepsBrachii)
    }

    @Test func targetedMusclesLeadSupportingOnlyMusclesByCreditedVolume() {
        let largeTarget = F.exercise(
            [F.set(), F.set(), F.set()], roles: [.deltoidPosterior: 1, .triceps: 0.5]
        )
        let smallTarget = F.exercise([F.set()], key: "small", roles: [.bicepsBrachii: 1])
        let largeSupport = F.exercise(
            Array(repeating: F.set(), count: 10), key: "support", roles: [.obliques: 0.5]
        )
        let report = F.replay([F.session([largeTarget, smallTarget, largeSupport])])
            .muscleDirectness(now: F.now)

        #expect(report.ranked.map(\.muscle).prefix(3) == [
            .deltoidPosterior, .bicepsBrachii, .obliques,
        ])
    }

    @Test func examplesAreUniqueCurrentPrimaryExercisesOnly() {
        let report = F.replay([]).muscleDirectness(now: F.now)
        for row in report.rows {
            #expect(row.examples.count <= 3)
            #expect(Set(row.examples.map(\.id)).count == row.examples.count)
            for example in row.examples {
                #expect(CatalogData.record(forCatalogID: example.id)?.involvement.contains {
                    $0.muscle == row.muscle && $0.role == .primary
                } == true)
            }
        }
        #expect(report.rows.first { $0.muscle == .bicepsBrachii }?.examples.count == 3)
        #expect(report.trained.isEmpty)
    }
}
