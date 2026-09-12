//
//  AnalyticsSnapshotStoreTests.swift
//  vivobodyTests
//
//  Proves the SwiftData ModelActor snapshots a cold archive once, then
//  replaces or removes only session graphs named by persistent history.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

@MainActor
struct AnalyticsSnapshotStoreTests {
    @Test func insertedSessionReusesTheExistingArchive() async throws {
        let harness = try makeHarness()
        let first = makeSession(name: "First", completedAt: date(1), reps: 5)
        let second = makeSession(name: "Second", completedAt: date(2), reps: 6)
        harness.context.insert(first)
        harness.context.insert(second)
        try harness.context.saveOrRollback()

        let store = AnalyticsSnapshotStore(modelContainer: harness.container)
        let initial = try await store.prepare()
        #expect(initial.usedFullReload)
        #expect(initial.rebuiltSessionCount == 2)
        #expect(
            initial.snapshot == AnalyticsSnapshot(sessions: [second, first])
        )

        let third = makeSession(name: "Third", completedAt: date(3), reps: 7)
        harness.context.insert(third)
        try harness.context.saveOrRollback()

        let updated = try await store.prepare()
        #expect(!updated.usedFullReload)
        #expect(updated.rebuiltSessionCount == 1)
        #expect(
            updated.snapshot == AnalyticsSnapshot(
                sessions: [third, second, first]
            )
        )
        #expect(updated.snapshot.sessions.map(\.id) == [third.id, second.id, first.id])
        #expect(updated.archiveRevision == initial.archiveRevision + 1)
    }

    @Test func deletedSessionIsRemovedWithoutRebuildingSurvivors() async throws {
        let harness = try makeHarness()
        let first = makeSession(name: "First", completedAt: date(1), reps: 5)
        let second = makeSession(name: "Second", completedAt: date(2), reps: 6)
        harness.context.insert(first)
        harness.context.insert(second)
        try harness.context.saveOrRollback()

        let store = AnalyticsSnapshotStore(modelContainer: harness.container)
        let initial = try await store.prepare()
        harness.context.delete(second)
        try harness.context.saveOrRollback()

        let updated = try await store.prepare()
        #expect(!updated.usedFullReload)
        #expect(updated.rebuiltSessionCount == 0)
        #expect(updated.snapshot.sessions.map(\.id) == [first.id])
        #expect(updated.archiveRevision == initial.archiveRevision + 1)
    }

    @Test func nestedSetChangeRebuildsItsSessionAndNeutralUpdateDoesNotPublish() async throws {
        let harness = try makeHarness()
        let session = makeSession(name: "Changed", completedAt: date(1), reps: 5)
        harness.context.insert(session)
        try harness.context.saveOrRollback()

        let store = AnalyticsSnapshotStore(modelContainer: harness.container)
        let initial = try await store.prepare()
        session.exercises[0].sets[0].reps = 12
        try harness.context.saveOrRollback()

        let changed = try await store.prepare()
        #expect(changed.rebuiltSessionCount == 1)
        #expect(changed.snapshot.sessions[0].exercises[0].sets[0].reps == 12)
        #expect(changed.archiveRevision == initial.archiveRevision + 1)

        session.healthKitWorkoutUUID = UUID()
        try harness.context.saveOrRollback()

        let neutral = try await store.prepare()
        #expect(neutral.rebuiltSessionCount == 1)
        #expect(neutral.snapshot == changed.snapshot)
        #expect(neutral.archiveRevision == changed.archiveRevision)
    }

    @Test func activeSessionEntersArchiveOnlyAfterCompletion() async throws {
        let harness = try makeHarness()
        let session = makeSession(name: "Active", completedAt: date(1), reps: 5)
        session.completedAt = nil
        harness.context.insert(session)
        try harness.context.saveOrRollback()

        let store = AnalyticsSnapshotStore(modelContainer: harness.container)
        let initial = try await store.prepare()
        #expect(initial.snapshot.sessions.isEmpty)

        session.exercises[0].sets[0].reps = 9
        try harness.context.saveOrRollback()
        let activeUpdate = try await store.prepare()
        #expect(activeUpdate.snapshot.sessions.isEmpty)
        #expect(activeUpdate.archiveRevision == initial.archiveRevision)

        session.completedAt = date(2)
        try harness.context.saveOrRollback()
        let archived = try await store.prepare()
        #expect(archived.rebuiltSessionCount == 1)
        #expect(archived.snapshot.sessions.map(\.id) == [session.id])
        #expect(archived.snapshot.sessions[0].exercises[0].sets[0].reps == 9)
        #expect(archived.archiveRevision == initial.archiveRevision + 1)
    }

    @Test func dayLookupSkipsFutureDatedSessions() async throws {
        let harness = try makeHarness()
        let today = date(2)
        harness.context.insert(
            makeSession(name: "Today", completedAt: today, reps: 5)
        )
        harness.context.insert(
            makeSession(name: "Future", completedAt: date(4), reps: 6)
        )
        try harness.context.saveOrRollback()

        let store = AnalyticsSnapshotStore(modelContainer: harness.container)
        let prepared = try await store.prepare()
        #expect(prepared.containsSession(on: today))
        #expect(!prepared.containsSession(on: date(3)))
    }

    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeHarness() throws -> Harness {
        let configuration = ModelConfiguration(
            schema: VivobodyStore.schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: VivobodyStore.schema,
            configurations: [configuration]
        )
        return Harness(
            container: container,
            context: ModelContext(container)
        )
    }

    private func makeSession(
        name: String,
        completedAt: Date,
        reps: Int
    ) -> WorkoutSession {
        let exercise = Exercise(
            name: name,
            catalogID: name.lowercased(),
            group: .chest,
            plannedSets: 1,
            plannedReps: reps,
            plannedWeight: 100
        )
        exercise.sets[0].isCompleted = true
        let session = WorkoutSession(
            exercises: [exercise],
            startedAt: completedAt.addingTimeInterval(-1800)
        )
        session.completedAt = completedAt
        return session
    }

    private func date(_ day: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + Double(day * 86400))
    }
}
