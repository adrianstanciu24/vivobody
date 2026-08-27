//
//  ExerciseBestHeroCard.swift
//  vivobody
//
//  The exercise detail screen's standing-record card: the huge
//  monospaced best-set numeral over its date, plus a frequency footer
//  (sessions · per week · last performed) behind a hairline. The
//  footer restores the useful core of the removed Last/Times
//  half-cards as plain facts — it never carries a verdict; progression
//  advice stays with the Effort section. Extracted from
//  ExerciseDetailSections to keep that file under its size ratchet.
//

import SwiftUI
import VivoKit

extension ExerciseDetailScreen {
    // MARK: - Best hero card

    /// The standing record gets a hero card with the huge monospaced
    /// numeral — the screen's one editorial moment.
    var bestHeroCard: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Best set")
                .sectionLabelStyle(Opacity.soft)

            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(bestValueString)
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                if showsBestUnit {
                    Text(unit.symbol)
                        .font(Typography.statValueCompact)
                        .foregroundStyle(Ink.tertiary)
                }
                if let fragment = bestSetFragment {
                    Text(fragment)
                        .font(Typography.statValueCompact)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            Text(bestSetDate ?? " ")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)

            if hasHistory {
                frequencyFooter
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard(bright: true)
        .accessibilityElement(children: .combine)
    }

    /// Unit symbol rides beside the hero numeral only when the record
    /// is an actual load — duration and unranked records have none.
    var showsBestUnit: Bool {
        item.performanceSemanticKind.comparesLoad && bestValueString != "—"
    }

    /// The record's reps/duration fragment ("× 8", "× 0:45"), kept
    /// separate from the date so the hero card can set it at medium
    /// scale next to the numeral instead of burying it in a caption.
    var bestSetFragment: String? {
        guard let source = bestRecordSource else { return nil }
        if !item.tracksResistance, item.trackingMode == .reps {
            return "reps"
        }
        switch item.performanceSemanticKind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            return "× \(source.reps)"
        case .isometricLoadAndDuration:
            return "× \(DurationFormatter.string(source.duration))"
        case .isometricDuration, .unrankedReps, .unrankedDuration:
            return nil
        }
    }

    var bestSetDate: String? {
        bestRecordSource.map { RelativeDate.short($0.date) }
    }

    /// Resolves the same record `bestValueString` describes, as raw
    /// values: the progress-series record point when a trend exists,
    /// else the single logged instance.
    private var bestRecordSource: (reps: Int, duration: TimeInterval, date: Date)? {
        if let prog = progress {
            guard let best = bestDisplayPoint(in: prog) else { return nil }
            return (best.topReps, best.topDuration, best.date)
        }
        guard let last = lastInstance else { return nil }
        return (last.topReps, last.topDuration, last.sessionDate)
    }

    // MARK: - Frequency footer

    /// Sessions · per week · last performed, split by hairlines. All
    /// three facts come from the cached history index and progress
    /// series; the footer hides entirely until the exercise has been
    /// logged once.
    var frequencyFooter: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Surface.edge)
                .frame(height: 0.5)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                frequencyCell(
                    label: "SESSIONS",
                    value: "\(frequencySessionCount)",
                    accessibility: "\(frequencySessionCount) \(frequencySessionCount == 1 ? "session" : "sessions")"
                )
                frequencyDivider
                frequencyCell(
                    label: "PER WEEK",
                    value: frequencyPerWeek.map { "\(InsightsFormat.perWeekLabel($0))×" } ?? "—",
                    accessibility: frequencyPerWeek
                        .map { "\(InsightsFormat.perWeekLabel($0)) per week" }
                        ?? "Weekly frequency not yet available"
                )
                frequencyDivider
                frequencyCell(
                    label: "LAST",
                    value: frequencyLastDate.map { RelativeDate.short($0) } ?? "—",
                    accessibility: "Last \(frequencyLastDate.map { RelativeDate.short($0) } ?? "unknown")"
                )
            }
            .padding(.top, Space.md)
        }
        .padding(.top, Space.xs)
    }

    private func frequencyCell(
        label: String,
        value: String,
        accessibility: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.quaternary)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var frequencyDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(width: 0.5, height: 26)
            .padding(.horizontal, Space.md)
            .accessibilityHidden(true)
    }

    /// All-time archived session count for this exercise, preferring
    /// the cached history index; the direct archive count remains the
    /// preview fallback.
    var frequencySessionCount: Int {
        sessionAnalytics?.exerciseHistorySummaries[historyKey]?.sessionCount
            ?? sessionCount
    }

    /// Typical weekly frequency from the progress-series dates. Nil
    /// until two sessions span at least a week.
    var frequencyPerWeek: Double? {
        guard let progress else { return nil }
        return ExerciseFrequency.perWeek(sessionDates: progress.points.map(\.date))
    }

    var frequencyLastDate: Date? {
        lastInstance?.sessionDate
    }
}
