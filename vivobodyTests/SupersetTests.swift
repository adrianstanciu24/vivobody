//
//  SupersetTests.swift
//  vivobodyTests
//
//  Guards the superset feature's three layers: the completion
//  choreography (partner hand-off without rest, rest between rounds,
//  uneven set counts, out-of-order completion), the structural
//  grouping edits (seam link/unlink, merge, split, normalization,
//  A1-style tags), and the spawn paths that must carry supersetID
//  from templates and repeated workouts into fresh sessions.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

// MARK: - Choreography

@MainActor
struct SupersetChoreographyTests {

    private func exercise(
        _ name: String,
        sets: Int,
        sortOrder: Int
    ) -> Exercise {
        Exercise(
            name: name,
            group: .chest,
            plannedSets: sets,
            plannedReps: 8,
            plannedWeight: 100,
            sortOrder: sortOrder
        )
    }

    private func linkedPair(
        setsA: Int = 3,
        setsB: Int = 3
    ) -> (session: WorkoutSession, a: Exercise, b: Exercise) {
        let a = exercise("Bench Press", sets: setsA, sortOrder: 0)
        let b = exercise("Bent-Over Row", sets: setsB, sortOrder: 1)
        let id = UUID()
        a.supersetID = id
        b.supersetID = id
        return (WorkoutSession(exercises: [a, b]), a, b)
    }

    @Test func firstMemberHandsOffToPartnerWithoutRest() {
        let (session, a, b) = linkedPair()

        let outcome = session.completeActiveSet(for: a)

        if case .supersetPartner(let partner) = outcome {
            #expect(partner.id == b.id)
        } else {
            Issue.record("Expected partner hand-off, got \(outcome)")
        }
        #expect(!session.isResting)
    }

    @Test func lastMemberOfRoundRestsAndResumesAtFirst() {
        let (session, a, b) = linkedPair()
        session.completeActiveSet(for: a)

        let outcome = session.completeActiveSet(for: b)

        if case .supersetRoundRest(let resume) = outcome {
            #expect(resume.id == a.id)
        } else {
            Issue.record("Expected round rest, got \(outcome)")
        }
        #expect(session.isResting)
    }

    @Test func unevenSetCountsFinishOnTheLongerMember() {
        let (session, a, b) = linkedPair(setsA: 2, setsB: 1)

        var outcome = session.completeActiveSet(for: a)
        if case .supersetPartner(let partner) = outcome {
            #expect(partner.id == b.id)
        } else {
            Issue.record("Round 1: expected hand-off to B, got \(outcome)")
        }

        session.skipRest()
        outcome = session.completeActiveSet(for: b)
        if case .supersetRoundRest(let resume) = outcome {
            #expect(resume.id == a.id)
        } else {
            Issue.record("Round 1 end: expected rest resuming at A, got \(outcome)")
        }

        session.skipRest()
        outcome = session.completeActiveSet(for: a)
        if case .exerciseComplete = outcome {
        } else {
            Issue.record("Final set: expected group completion, got \(outcome)")
        }
        #expect(!session.isResting)
    }

    @Test func outOfOrderCompletionCatchesThePartnerUp() {
        let (session, a, b) = linkedPair()

        // The user swiped ahead and worked B first — the choreography
        // walks them back to the member that's behind.
        let outcome = session.completeActiveSet(for: b)

        if case .supersetPartner(let partner) = outcome {
            #expect(partner.id == a.id)
        } else {
            Issue.record("Expected hand-off back to A, got \(outcome)")
        }
        #expect(!session.isResting)
    }

    @Test func straightSetsStillRestBetweenSets() {
        let ex = exercise("Squat", sets: 2, sortOrder: 0)
        let session = WorkoutSession(exercises: [ex])

        let first = session.completeActiveSet(for: ex)
        if case .rest = first {} else {
            Issue.record("Expected plain rest, got \(first)")
        }
        #expect(session.isResting)

        session.skipRest()
        let second = session.completeActiveSet(for: ex)
        if case .exerciseComplete = second {} else {
            Issue.record("Expected exercise completion, got \(second)")
        }
        #expect(!session.isResting)
    }

    @Test func singletonGroupBehavesAsStraightSets() {
        let ex = exercise("Squat", sets: 2, sortOrder: 0)
        ex.supersetID = UUID()
        let session = WorkoutSession(exercises: [ex])

        #expect(!session.isInSuperset(ex))
        let outcome = session.completeActiveSet(for: ex)
        if case .rest = outcome {} else {
            Issue.record("Expected plain rest, got \(outcome)")
        }
    }

    @Test func roundCountIsTheLongestMember() {
        let (session, a, _) = linkedPair(setsA: 4, setsB: 3)
        #expect(session.supersetRoundCount(of: a) == 4)
    }

    @Test func sessionTagsFollowGroupOrder() {
        let (session, a, b) = linkedPair()
        #expect(session.supersetTag(for: a) == "A1")
        #expect(session.supersetTag(for: b) == "A2")
    }
}

// MARK: - Grouping edits

@MainActor
struct SupersetGroupingTests {

    private func members(_ count: Int) -> [TemplateExercise] {
        (0..<count).map { i in
            TemplateExercise(
                name: "Exercise \(i)",
                group: .chest,
                plannedWeight: 100,
                sortOrder: i
            )
        }
    }

    @Test func linkSeamCreatesAPair() {
        let m = members(3)
        SupersetGrouping.linkSeam(at: 0, in: m)

        #expect(m[0].supersetID != nil)
        #expect(m[0].supersetID == m[1].supersetID)
        #expect(m[2].supersetID == nil)
        #expect(SupersetGrouping.isSeamLinked(at: 0, in: m))
        #expect(!SupersetGrouping.isSeamLinked(at: 1, in: m))
    }

    @Test func linkSeamExtendsAndMergesGroups() {
        let m = members(4)
        SupersetGrouping.linkSeam(at: 0, in: m)
        SupersetGrouping.linkSeam(at: 2, in: m)
        #expect(m[0].supersetID != m[2].supersetID)

        // Linking the middle seam merges the two pairs into one
        // four-member group.
        SupersetGrouping.linkSeam(at: 1, in: m)
        let ids = Set(m.compactMap(\.supersetID))
        #expect(ids.count == 1)
    }

    @Test func unlinkSeamSplitsAndDissolvesSingletons() {
        let m = members(3)
        SupersetGrouping.linkSeam(at: 0, in: m)
        SupersetGrouping.linkSeam(at: 1, in: m)

        // Splitting a trio after the pair leaves [0,1] linked and 2
        // dissolved back to straight sets.
        SupersetGrouping.unlinkSeam(at: 1, in: m)
        #expect(m[0].supersetID != nil)
        #expect(m[0].supersetID == m[1].supersetID)
        #expect(m[2].supersetID == nil)

        // Splitting the remaining pair dissolves both.
        SupersetGrouping.unlinkSeam(at: 0, in: m)
        #expect(m.allSatisfy { $0.supersetID == nil })
    }

    @Test func unlinkMemberDissolvesAnOrphanedPair() {
        let m = members(2)
        SupersetGrouping.linkSeam(at: 0, in: m)

        SupersetGrouping.unlink(m[0], in: m)
        #expect(m.allSatisfy { $0.supersetID == nil })
    }

    @Test func normalizeSplitsNonContiguousReuse() {
        let m = members(5)
        let id = UUID()
        // [G, G, –, G, G] — the same ID reused across a gap (as a
        // reorder could produce) must become two distinct groups.
        m[0].supersetID = id
        m[1].supersetID = id
        m[3].supersetID = id
        m[4].supersetID = id

        SupersetGrouping.normalize(m)
        #expect(m[0].supersetID == m[1].supersetID)
        #expect(m[3].supersetID == m[4].supersetID)
        #expect(m[0].supersetID != m[3].supersetID)
        #expect(m[2].supersetID == nil)
    }

    @Test func normalizeDissolvesSingletonsAfterDelete() {
        let m = members(3)
        SupersetGrouping.linkSeam(at: 0, in: m)

        // Simulate deleting member 1 of the pair.
        let remaining = [m[0], m[2]]
        SupersetGrouping.normalize(remaining)
        #expect(remaining.allSatisfy { $0.supersetID == nil })
    }

    @Test func tagsLabelGroupsInOrderOfAppearance() {
        let m = members(5)
        SupersetGrouping.linkSeam(at: 0, in: m)
        SupersetGrouping.linkSeam(at: 3, in: m)

        #expect(SupersetGrouping.tag(for: m[0], in: m) == "A1")
        #expect(SupersetGrouping.tag(for: m[1], in: m) == "A2")
        #expect(SupersetGrouping.tag(for: m[2], in: m) == nil)
        #expect(SupersetGrouping.tag(for: m[3], in: m) == "B1")
        #expect(SupersetGrouping.tag(for: m[4], in: m) == "B2")
    }

    @Test func linkedRunsFindContiguousGroups() {
        let m = members(5)
        SupersetGrouping.linkSeam(at: 0, in: m)
        SupersetGrouping.linkSeam(at: 3, in: m)

        let runs = SupersetGrouping.linkedRuns(in: m)
        #expect(runs == [0...1, 3...4])
    }
}

// MARK: - Spawn paths

@MainActor
struct SupersetSpawnTests {

    @Test func templateSpawnCarriesSupersetID() {
        let id = UUID()
        let templateExercise = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedWeight: 135,
            sortOrder: 0
        )
        templateExercise.supersetID = id

        let spawned = Exercise(from: templateExercise)
        #expect(spawned.supersetID == id)
    }

    @Test func perSetTemplateSpawnCarriesSupersetID() {
        let id = UUID()
        let templateExercise = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedWeight: 135,
            sortOrder: 0
        )
        templateExercise.supersetID = id
        templateExercise.sets = [
            TemplateSet(weight: 135, reps: 8, sortOrder: 0),
            TemplateSet(weight: 155, reps: 6, sortOrder: 1),
        ]

        let spawned = Exercise(from: templateExercise)
        #expect(spawned.supersetID == id)
    }

    @Test func freshCopyCarriesSupersetID() {
        let id = UUID()
        let source = Exercise(
            name: "Bench Press",
            group: .chest,
            plannedSets: 3,
            plannedReps: 8,
            plannedWeight: 135,
            sortOrder: 0
        )
        source.supersetID = id

        let copy = Exercise.freshCopy(of: source)
        #expect(copy.supersetID == id)
    }

    @Test func editorDraftRoundTripsSupersetID() {
        let id = UUID()
        let templateExercise = TemplateExercise(
            name: "Bench Press",
            group: .chest,
            plannedWeight: 135,
            sortOrder: 0
        )
        templateExercise.supersetID = id

        // Template → draft (editor hydration) → template (save).
        let draft = ExerciseDraft(from: templateExercise)
        #expect(draft.supersetID == id)
        let saved = draft.makeTemplateExercise(sortOrder: 0)
        #expect(saved.supersetID == id)
    }
}
