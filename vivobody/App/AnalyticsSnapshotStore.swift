//
//  AnalyticsSnapshotStore.swift
//  vivobody
//
//  SwiftData-owned adapter between the workout archive and immutable analytics
//  input. A long-lived ModelActor performs the cold archive read and uses
//  persistent history to replace only session graphs touched by later saves.
//

import Foundation
import SwiftData

@ModelActor
actor AnalyticsSnapshotStore {
    nonisolated struct PreparedSnapshot {
        let snapshot: AnalyticsSnapshot
        let archiveRevision: Int
        let rebuiltSessionCount: Int
        let usedFullReload: Bool
        let didChangeArchive: Bool

        /// The actor publishes sessions newest-first. Binary search preserves
        /// the old any-session-on-this-day semantics even when clock changes
        /// leave future-dated sessions ahead of today's workout.
        func containsSession(
            on date: Date,
            calendar: Calendar = .current
        ) -> Bool {
            guard let interval = calendar.dateInterval(of: .day, for: date)
            else { return false }

            var lowerBound = 0
            var upperBound = snapshot.sessions.count
            while lowerBound < upperBound {
                let middle = lowerBound + (upperBound - lowerBound) / 2
                if snapshot.sessions[middle].date >= interval.end {
                    lowerBound = middle + 1
                } else {
                    upperBound = middle
                }
            }
            guard lowerBound < snapshot.sessions.count else { return false }
            return snapshot.sessions[lowerBound].date >= interval.start
        }
    }

    private var snapshotsBySessionID: [UUID: AnalyticsSessionSnapshot] = [:]
    private var ownerByPersistentID: [PersistentIdentifier: UUID] = [:]
    private var persistentIDsBySessionID: [UUID: Set<PersistentIdentifier>] = [:]
    private var assembledSnapshot = AnalyticsSnapshot(
        sessions: [AnalyticsSessionSnapshot]()
    )
    private var historyToken: DefaultHistoryToken?
    private var hasLoaded = false
    private var archiveRevision = 0

    private struct HistoryIdentifiers {
        var changed: Set<PersistentIdentifier> = []
        var deleted: Set<PersistentIdentifier> = []
    }

    func prepare(forceFullReload: Bool = false) throws -> PreparedSnapshot {
        if forceFullReload || !hasLoaded {
            return try logged(reloadAll(capturingHistoryToken: true))
        }

        do {
            return try logged(applyPersistentHistory())
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as SwiftDataError where error == .historyTokenExpired {
            return try logged(reloadAll(capturingHistoryToken: true))
        } catch {
            // Persistent history may be unavailable for a recovery store. Keep
            // correctness by rebuilding on this actor rather than returning a
            // stale archive or moving model access back to MainActor.
            return try logged(reloadAll(capturingHistoryToken: false))
        }
    }

    private func logged(_ prepared: PreparedSnapshot) -> PreparedSnapshot {
        AppDiagnostics.analyticsSnapshotRefresh(
            usedFullReload: prepared.usedFullReload,
            didChangeArchive: prepared.didChangeArchive,
            rebuiltSessionCount: prepared.rebuiltSessionCount
        )
        return prepared
    }

    private func applyPersistentHistory() throws -> PreparedSnapshot {
        let transactions = try transactions(after: historyToken)
        guard !transactions.isEmpty else {
            return prepared(rebuiltSessionCount: 0, usedFullReload: false)
        }

        let identifiers = try historyIdentifiers(in: transactions)
        let affectedSessionIDs = affectedSessionIDs(for: identifiers)

        var nextSnapshots = snapshotsBySessionID
        var nextOwners = ownerByPersistentID
        var nextIdentifiers = persistentIDsBySessionID
        var rebuiltSessionCount = 0
        var archiveChanged = false
        for sessionID in affectedSessionIDs {
            try Task.checkCancellation()
            let result = try replaceSnapshot(
                for: sessionID,
                snapshots: &nextSnapshots,
                owners: &nextOwners,
                identifiersBySession: &nextIdentifiers
            )
            rebuiltSessionCount += result.rebuilt ? 1 : 0
            archiveChanged = archiveChanged || result.changed
        }

        historyToken = transactions.map(\.token).max()
        if !affectedSessionIDs.isEmpty {
            snapshotsBySessionID = nextSnapshots
            ownerByPersistentID = nextOwners
            persistentIDsBySessionID = nextIdentifiers
        }
        if archiveChanged {
            archiveRevision &+= 1
            rebuildAssembledSnapshot()
        }
        return prepared(
            rebuiltSessionCount: rebuiltSessionCount,
            usedFullReload: false,
            didChangeArchive: archiveChanged
        )
    }

    private func historyIdentifiers(
        in transactions: [DefaultHistoryTransaction]
    ) throws -> HistoryIdentifiers {
        var identifiers = HistoryIdentifiers()
        for transaction in transactions {
            try Task.checkCancellation()
            for change in transaction.changes {
                switch change {
                case .insert, .update:
                    identifiers.changed.insert(change.changedPersistentIdentifier)
                case .delete:
                    identifiers.deleted.insert(change.changedPersistentIdentifier)
                @unknown default:
                    identifiers.changed.insert(change.changedPersistentIdentifier)
                }
            }
        }
        return identifiers
    }

    private func affectedSessionIDs(
        for identifiers: HistoryIdentifiers
    ) -> Set<UUID> {
        var affectedSessionIDs: Set<UUID> = []
        for identifier in identifiers.deleted {
            if let owner = ownerByPersistentID[identifier] {
                affectedSessionIDs.insert(owner)
            }
        }
        for identifier in identifiers.changed {
            if let owner = ownerByPersistentID[identifier]
                ?? sessionID(containing: identifier)
            {
                affectedSessionIDs.insert(owner)
            }
        }
        return affectedSessionIDs
    }

    private func reloadAll(
        capturingHistoryToken: Bool
    ) throws -> PreparedSnapshot {
        // Capture the high-water mark before fetching. A concurrent save after
        // this point is either visible in the fetch and harmlessly replayed or
        // is picked up by the next history catch-up.
        let baselineToken = capturingHistoryToken
            ? try latestHistoryToken()
            : nil
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        let sessions = try modelContext.fetch(descriptor)

        var nextSnapshots: [UUID: AnalyticsSessionSnapshot] = [:]
        var nextOwners: [PersistentIdentifier: UUID] = [:]
        var nextIdentifiers: [UUID: Set<PersistentIdentifier>] = [:]
        for session in sessions {
            try Task.checkCancellation()
            installSnapshot(
                for: session,
                snapshots: &nextSnapshots,
                owners: &nextOwners,
                identifiersBySession: &nextIdentifiers
            )
        }

        snapshotsBySessionID = nextSnapshots
        ownerByPersistentID = nextOwners
        persistentIDsBySessionID = nextIdentifiers
        historyToken = baselineToken
        hasLoaded = true
        archiveRevision &+= 1
        rebuildAssembledSnapshot()
        return prepared(
            rebuiltSessionCount: sessions.count,
            usedFullReload: true,
            didChangeArchive: true
        )
    }

    private func replaceSnapshot(
        for sessionID: UUID,
        snapshots: inout [UUID: AnalyticsSessionSnapshot],
        owners: inout [PersistentIdentifier: UUID],
        identifiersBySession: inout [UUID: Set<PersistentIdentifier>]
    ) throws -> (rebuilt: Bool, changed: Bool) {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.id == sessionID && $0.completedAt != nil
            }
        )
        descriptor.fetchLimit = 1
        guard let session = try modelContext.fetch(descriptor).first else {
            let existed = snapshots.removeValue(forKey: sessionID) != nil
            removePersistentIDs(
                for: sessionID,
                owners: &owners,
                identifiersBySession: &identifiersBySession
            )
            return (false, existed)
        }

        let previous = snapshots[sessionID]
        removePersistentIDs(
            for: sessionID,
            owners: &owners,
            identifiersBySession: &identifiersBySession
        )
        installSnapshot(
            for: session,
            snapshots: &snapshots,
            owners: &owners,
            identifiersBySession: &identifiersBySession
        )
        return (true, previous != snapshots[sessionID])
    }

    private func installSnapshot(
        for session: WorkoutSession,
        snapshots: inout [UUID: AnalyticsSessionSnapshot],
        owners: inout [PersistentIdentifier: UUID],
        identifiersBySession: inout [UUID: Set<PersistentIdentifier>]
    ) {
        let snapshot = makeSnapshot(session)
        snapshots[session.id] = snapshot

        var identifiers: Set<PersistentIdentifier> = [session.persistentModelID]
        for exercise in session.exercises {
            identifiers.insert(exercise.persistentModelID)
            for set in exercise.sets {
                identifiers.insert(set.persistentModelID)
            }
        }
        identifiersBySession[session.id] = identifiers
        for identifier in identifiers {
            owners[identifier] = session.id
        }
    }

    private func removePersistentIDs(
        for sessionID: UUID,
        owners: inout [PersistentIdentifier: UUID],
        identifiersBySession: inout [UUID: Set<PersistentIdentifier>]
    ) {
        guard let identifiers = identifiersBySession.removeValue(
            forKey: sessionID
        ) else { return }
        for identifier in identifiers {
            owners.removeValue(forKey: identifier)
        }
    }

    private func sessionID(
        containing identifier: PersistentIdentifier
    ) -> UUID? {
        switch identifier.entityName {
        case Schema.entityName(for: WorkoutSession.self):
            self[identifier, as: WorkoutSession.self]?.id
        case Schema.entityName(for: Exercise.self):
            self[identifier, as: Exercise.self]?.session?.id
        case Schema.entityName(for: WorkoutSet.self):
            self[identifier, as: WorkoutSet.self]?.exercise?.session?.id
        default:
            nil
        }
    }

    private func rebuildAssembledSnapshot() {
        let sessions = snapshotsBySessionID.values.sorted { left, right in
            if left.date == right.date {
                return left.id.uuidString < right.id.uuidString
            }
            return left.date > right.date
        }
        assembledSnapshot = AnalyticsSnapshot(sessions: sessions)
    }

    private func prepared(
        rebuiltSessionCount: Int,
        usedFullReload: Bool,
        didChangeArchive: Bool = false
    ) -> PreparedSnapshot {
        PreparedSnapshot(
            snapshot: assembledSnapshot,
            archiveRevision: archiveRevision,
            rebuiltSessionCount: rebuiltSessionCount,
            usedFullReload: usedFullReload,
            didChangeArchive: didChangeArchive
        )
    }

    private func transactions(
        after token: DefaultHistoryToken?
    ) throws -> [DefaultHistoryTransaction] {
        if let token {
            return try modelContext.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(
                    predicate: #Predicate { $0.token > token }
                )
            )
        }
        return try modelContext.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>()
        )
    }

    private func latestHistoryToken() throws -> DefaultHistoryToken? {
        var descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
            sortBy: [SortDescriptor(\.transactionIdentifier, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetchHistory(descriptor).first?.token
    }

    private func makeSnapshot(
        _ session: WorkoutSession
    ) -> AnalyticsSessionSnapshot {
        let bodyweight = session.bodyweightAtStart
        let sanitizedBodyweight = bodyweight.isFinite && bodyweight > 0
            ? bodyweight
            : ExerciseLoad.unknownBodyweight
        let exercises = session.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { makeSnapshot($0, bodyweight: sanitizedBodyweight) }
        return AnalyticsSessionSnapshot(
            id: session.id,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            bodyweightAtStart: sanitizedBodyweight,
            exercises: exercises
        )
    }

    private func makeSnapshot(
        _ exercise: Exercise,
        bodyweight: Double
    ) -> AnalyticsExerciseSnapshot {
        let tracksResistance = exercise.tracksResistance
        let sets = exercise.sets
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { set in
                AnalyticsSetSnapshot(
                    weight: tracksResistance ? max(0, set.weight) : 0,
                    reps: set.reps,
                    duration: set.duration,
                    isCompleted: set.isCompleted,
                    repsInReserve: set.repsInReserve,
                    rirLogged: set.rirLogged
                )
            }
        return AnalyticsExerciseSnapshot(
            id: exercise.id,
            catalogID: exercise.catalogID,
            familyID: exercise.familyID,
            catalogItemID: exercise.catalogItemID,
            name: exercise.name,
            group: exercise.group,
            trackingMode: exercise.trackingMode,
            modality: exercise.modality,
            loadProfile: exercise.loadProfile,
            bodyweightAtSession: bodyweight,
            historyKey: exercise.historyKey,
            classification: exercise.classification,
            volumeCredits: exercise.muscleInvolvement.volumeCredits.filter {
                $0.value > 0
            },
            sets: sets
        )
    }
}
