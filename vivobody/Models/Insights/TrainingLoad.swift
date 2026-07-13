//
//  TrainingLoad.swift
//  vivobody
//
//  The macro recovery lens for the Insights tab. Every other section
//  reads DISTRIBUTION — which muscle, which lift, which rep range.
//  This reads TREND: is total systemic load ramping faster than the
//  body has adapted to?
//
//  It's the acute:chronic workload ratio (ACWR) coaches use to flag
//  overreaching. Load is measured in tonnage (weight × reps), summed
//  per session:
//    • acute   = tonnage over the last 7 days.
//    • chronic = average WEEKLY tonnage over the last 28 days.
//    • ratio   = acute / chronic.
//
//  A ratio near 1.0 means this week matches the month's habit; well
//  above means you're ramping hard (recovery debt, niggle risk);
//  well below means load is dropping (deload or detraining).
//
//  The chronic baseline is the 28-day tonnage total divided by the
//  number of weeks of history actually on hand (rounded, capped at
//  four) — so a three-week log isn't false-flagged as a spike because
//  its sum got spread over a flat four. Under three weeks of history
//  the ratio can't be trusted, so the verdict reads `.insufficient`
//  and the UI counts down the days.
//
//  Pure value-type computation on injected dates (see
//  `TrainingLoadTests`).
//

import Foundation

// MARK: - Verdict

/// Where the acute:chronic ratio lands. Bands follow the sports-
/// science convention: 0.8–1.3 is the productive "sweet spot", above
/// 1.5 is the elevated-risk zone.
nonisolated enum LoadVerdict: Hashable {
    /// Under two weeks of history — the ratio isn't meaningful yet.
    case insufficient
    /// Ratio < 0.8 — load is dropping (deload or detraining).
    case detraining
    /// Ratio 0.8–1.3 — this week tracks the month's baseline.
    case optimal
    /// Ratio 1.3–1.5 — ramping hard but still inside reason.
    case pushing
    /// Ratio > 1.5 — load spiking past adaptation; back off.
    case overreaching

    static func from(ratio: Double) -> LoadVerdict {
        switch ratio {
        case ..<0.8:     return .detraining
        case 0.8..<1.3:  return .optimal
        case 1.3..<1.5:  return .pushing
        default:         return .overreaching
        }
    }
}

// MARK: - Weekly load

/// One calendar week's total tonnage — the bars of the Insights
/// training-load chart. Weeks without sessions carry zero so a
/// skipped week reads as the gap it was.
nonisolated struct LoadWeek: Identifiable, Hashable {
    var id: Date { weekStart }
    let weekStart: Date
    /// Total tonnage (canonical lb) for the week.
    let load: Double
    /// `true` for the week containing `now` — still being written.
    let isCurrent: Bool
}

// MARK: - Report

nonisolated struct TrainingLoadReport: Hashable {
    /// Tonnage (canonical lb) over the last 7 days.
    let acuteLoad: Double
    /// Average weekly tonnage baseline over the last 28 days.
    let chronicWeekly: Double
    /// acute / chronicWeekly. Zero when there's no baseline.
    let ratio: Double
    let verdict: LoadVerdict
    /// Whole days from the first logged session to `now` — drives the
    /// "keep logging" copy while the baseline is still forming.
    let daysLogged: Int
    /// Weekly tonnage over the trailing 12 calendar weeks (oldest →
    /// newest, zero-filled), clipped to weeks since the first session.
    let weeks: [LoadWeek]

    /// Enough history (≥ 2 weeks) and a real baseline to judge.
    var hasEnoughHistory: Bool { verdict != .insufficient }
}

// MARK: - Aggregation

extension Array where Element == WorkoutSession {
    /// Acute:chronic workload report as of `now`, load measured in
    /// tonnage. Only sessions with completed work contribute.
    func trainingLoad(now: Date = Date()) -> TrainingLoadReport {
        let dated: [(date: Date, load: Double)] = compactMap { session in
            let load = session.totalVolume
            guard load > 0 else { return nil }
            return (session.completedAt ?? session.startedAt, load)
        }

        guard let first = dated.map(\.date).min() else {
            return TrainingLoadReport(
                acuteLoad: 0, chronicWeekly: 0, ratio: 0,
                verdict: .insufficient, daysLogged: 0, weeks: []
            )
        }

        let acuteCutoff = now.addingTimeInterval(-7 * 86_400)
        let chronicCutoff = now.addingTimeInterval(-28 * 86_400)
        let acute = dated.filter { $0.date > acuteCutoff }.reduce(0) { $0 + $1.load }
        let chronicSum = dated.filter { $0.date > chronicCutoff }.reduce(0) { $0 + $1.load }

        let daysSinceFirst = Swift.max(0, Int(now.timeIntervalSince(first) / 86_400))
        // Spread the 28-day total over the weeks actually logged
        // (rounded, 1…4) so a short history reports a fair weekly
        // baseline instead of a deflated one that fakes a spike.
        let weeksLogged = Swift.min(4.0, Swift.max(1.0, (Double(daysSinceFirst) / 7.0).rounded()))
        let chronicWeekly = chronicSum / weeksLogged
        let ratio = chronicWeekly > 0 ? acute / chronicWeekly : 0

        let enough = daysSinceFirst >= 21 && chronicWeekly > 0
        let verdict: LoadVerdict = enough ? LoadVerdict.from(ratio: ratio) : .insufficient

        return TrainingLoadReport(
            acuteLoad: acute,
            chronicWeekly: chronicWeekly,
            ratio: ratio,
            verdict: verdict,
            daysLogged: daysSinceFirst,
            weeks: Self.weeklyLoads(dated: dated, firstSession: first, now: now)
        )
    }

    /// Zero-filled weekly tonnage columns for the trailing 12 calendar
    /// weeks, starting no earlier than the week of the first session.
    private static func weeklyLoads(
        dated: [(date: Date, load: Double)],
        firstSession: Date,
        now: Date
    ) -> [LoadWeek] {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }

        var loadByWeek: [Date: Double] = [:]
        for entry in dated {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: entry.date)?.start else { continue }
            loadByWeek[weekStart, default: 0] += entry.load
        }

        let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: firstSession)?.start ?? currentWeekStart

        var weeks: [LoadWeek] = []
        for offset in stride(from: -11, through: 0, by: 1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart),
                  weekStart >= firstWeekStart
            else { continue }
            weeks.append(
                LoadWeek(
                    weekStart: weekStart,
                    load: loadByWeek[weekStart] ?? 0,
                    isCurrent: offset == 0
                )
            )
        }
        return weeks
    }
}
