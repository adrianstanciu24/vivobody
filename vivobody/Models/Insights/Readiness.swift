//
//  Readiness.swift
//  vivobody
//
//  The body figure's voice on the Today screen. The 3D model shows
//  WHERE you've trained; this one line says HOW READY you are to train
//  again right now — a short, glanceable verdict, not a dashboard.
//
//  It reads two cheap signals already on hand:
//    • freshness — whole days since your last completed session.
//    • trend     — the rolling workload status (`TrainingLoad`), once
//                  there's enough personal history for comparison.
//
//  The dominant signal wins so the line stays a few words. High load
//  prompts a lighter session, otherwise a rested body leads. Before
//  the load model has four weeks of history it falls back to recency.
//
//  Pure value-type derivation on injected dates (see `ReadinessTests`).
//  Returns nil only at cold start (no sessions), where the caller keeps
//  the colour-decode legend instead.
//

import Foundation

/// A two-part readiness sentence: a brightened `lead` clause and a
/// dimmer `tail` nudge (which may be empty). Kept split so the view can
/// weight the two clauses without re-parsing copy.
nonisolated struct ReadinessLine: Hashable {
    let lead: String
    let tail: String

    /// The whole sentence, for accessibility and tests.
    var phrase: String {
        tail.isEmpty ? lead : lead + " " + tail
    }
}

extension Array where Element == WorkoutSession {
    /// The readiness verdict as of `now`, or nil when nothing has been
    /// logged yet (cold start).
    func readiness(now: Date = Date(), calendar: Calendar = .current) -> ReadinessLine? {
        guard let last = compactMap({ $0.completedAt }).max() else { return nil }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        // Trained today already — recovery is the only message that
        // matters; freshness and trend are moot.
        if days <= 0 {
            return ReadinessLine(lead: "Today's in the bank.", tail: "Recover well.")
        }

        let report = trainingLoad(now: now)

        // Until the load model has enough history, lead with recency.
        guard report.hasEnoughHistory else { return Self.formingLine(days: days) }

        // Enough history: the trend verdict dominates, with freshness
        // colouring the productive case.
        switch report.verdict {
        case .high:
            return ReadinessLine(lead: "Training load is high.", tail: "Keep today lighter.")
        case .productive:
            return days >= 2
                ? ReadinessLine(lead: "Fresh and on plan.", tail: "")
                : ReadinessLine(lead: "Productive training load.", tail: "Keep the rhythm.")
        case .low:
            return ReadinessLine(lead: "Load is lighter lately.", tail: "Build when ready.")
        case .insufficient:
            return Self.formingLine(days: days)
        }
    }

    /// Recency-only voice for before the load baseline has formed.
    private static func formingLine(days: Int) -> ReadinessLine {
        switch days {
        case ..<2:
            return ReadinessLine(lead: "One day's rest.", tail: "Ready when you are.")
        case 2...3:
            return ReadinessLine(lead: "Fresh — \(days) days' rest.", tail: "Good to go.")
        case 4...6:
            return ReadinessLine(lead: "\(days) days off.", tail: "Ease back in.")
        default:
            return ReadinessLine(lead: "It's been \(days) days.", tail: "Welcome back.")
        }
    }
}
