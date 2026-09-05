//
//  MovementCoverageTests.swift
//  vivobodyTests
//
// Coverage conserves hard-set credit and keeps unknown and resisted work honest.

import Foundation
import Testing
@testable import vivobody

@MainActor
struct MovementCoverageTests {
    private typealias F = InsightsDimensionFixtures

    @Test func dividesCreditAcrossUniquePlanesWithoutCatalogMultiplicity() {
        let single = F.exercise([F.set(), F.set()], planes: [.sagittal])
        let multi = F.exercise([F.set(), F.set(), F.set()], planes: [.sagittal, .frontal, .transverse])
        let report = F.replay([F.session([single, multi])]).movementCoverage(now: F.now)
        #expect(report.totalSets == 5)
        #expect(report.setsByPlane[.sagittal] == 3)
        #expect(report.setsByPlane[.frontal] == 1)
        #expect(report.setsByPlane[.transverse] == 1)
        #expect(MovementPlane.allCases.reduce(0) { $0 + report.percentage($1) } == 100)
    }

    @Test func usesEffortCreditAcrossAllHistoryAndExcludesLiveAndFutureWork() {
        let exercise = F.exercise([F.set(rir: 4)])
        let archive = [F.session([exercise], daysAgo: 0), F.session([exercise], daysAgo: 28),
                       F.session([exercise], daysAgo: 730),
                       F.session([exercise], daysAgo: -1), F.session([exercise], completed: false)]
        let report = F.replay(archive).movementCoverage(now: F.now)
        #expect(abs(report.totalSets - 1.92) < 0.000001)
    }

    @Test func unknownPlanesAndFamilyStayOutsideKnownCoverage() {
        let custom = F.exercise([F.set()], family: nil, planes: nil)
        let report = F.replay([F.session([custom])]).movementCoverage(now: F.now)
        #expect(!report.hasData)
        #expect(report.unclassifiedSets == 1)
        #expect(report.unknownActionSets == 1)
        #expect(report.percentage(.sagittal) == 0)
    }

    @Test func resistedActionsDoNotClaimProducedActionsOrStabilizers() {
        let carry = F.exercise([F.set(0, duration: 30)], family: "suitcase-carry", planes: [.frontal],
                               modality: .isometricStrength, tracking: .duration)
        let report = F.replay([F.session([carry], daysAgo: 730)]).movementCoverage(now: F.now)
        #expect(report.totalSets == 1)
        #expect(!report.missingPlanes.contains(.frontal))
        #expect(!report.missingActions.contains { $0.action.actionID == "spine.lateralFlexion" && $0.action.kind == .resisted })
        #expect(report.missingActions.contains { $0.action.actionID == "spine.lateralFlexion" && $0.action.kind == .produced })
        #expect(report.missingActions.contains { $0.action.actionID == "knee.extension" && $0.action.kind == .produced })
    }

    @Test func powerIncompleteAndEmptySetsEarnNoCoverage() {
        let power = F.exercise([F.set()], modality: .power)
        let empty = F.exercise([F.set(0), F.set(completed: false)])
        #expect(F.replay([F.session([power, empty])]).movementCoverage(now: F.now).totalSets == 0)
    }

    @Test func roundingConservesOneHundredForThirds() {
        let report = F.replay([F.session([F.exercise([F.set()], planes: MovementPlane.allCases)])])
            .movementCoverage(now: F.now)
        #expect(report.percentage(.sagittal) == 34)
        #expect(report.percentage(.frontal) == 33)
        #expect(report.percentage(.transverse) == 33)
    }

    @Test func snapshotCopiesFamilyIdentityBeforeModelMutation() {
        let exercise = Exercise(name: "Bench", familyID: "horizontal-press", group: .chest, plannedWeight: 100)
        let snapshot = AnalyticsExerciseSnapshot(exercise, bodyweightAtSession: 0)
        exercise.familyID = "vertical-press"
        #expect(snapshot.familyID == "horizontal-press")
    }
}
