//
//  BodyWeight.swift
//  vivobody
//
//  Lightweight body-weight tracking. One BodyWeightEntry per logged
//  data point. The model permits multiple entries per calendar day
//  — useful if you ever sync from Apple Health later, or simply
//  decide morning + evening weigh-ins matter to you — but the log
//  sheet steers daily users toward one-per-day by pre-loading and
//  overwriting today's existing entry when present. A saved daily
//  measurement also corrects the body-weight snapshot of workouts
//  started that day so effective-load analytics stay in sync.
//
//  Stored unit: pounds. The app is currently lb-only; whenever the
//  Units track lands, conversion happens at the formatter boundary,
//  not in storage.
//

import Foundation
import SwiftData

@Model
final class BodyWeightEntry: Identifiable {
    #Index<BodyWeightEntry>([\.date])
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0

    init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

// MARK: - Collection helpers

extension [BodyWeightEntry] {
    /// Entry whose date matches a given calendar day, when present.
    /// Used by the log sheet to detect that "today" already has a
    /// record so saving updates it instead of inserting a duplicate.
    func entry(on day: Date, calendar: Calendar = .current) -> BodyWeightEntry? {
        first(where: { calendar.isDate($0.date, inSameDayAs: day) })
    }
}

// MARK: - Workout snapshot synchronization

/// Keeps a same-day body-weight correction connected to the workout
/// snapshots derived from it. Sessions on other calendar days remain
/// immutable history: a genuinely new measurement must not rewrite the
/// load the user moved in an older workout.
@MainActor
enum BodyWeightSessionSynchronizer {
    /// Applies `weight` to every active or archived workout that began on
    /// `date`'s calendar day. Returning the affected sessions lets the save
    /// flow refresh active-session side effects after the transaction lands.
    static func apply(
        weight: Double,
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) throws -> [WorkoutSession] {
        guard weight.isFinite, weight > 0 else { return [] }

        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { session in
                session.startedAt >= dayStart && session.startedAt < dayEnd
            }
        )
        let sessions = try context.fetch(descriptor)
        for session in sessions {
            session.bodyweightAtStart = weight
        }
        return sessions
    }
}
