//
//  ExerciseDetailSections.swift
//  vivobody
//
//  Section view builders and derived properties for
//  ExerciseDetailScreen, extracted to keep the main file
//  focused on composition and state.
//

import VivoKit
import SwiftUI
import SwiftData
import Charts

extension ExerciseDetailScreen {
    // MARK: - Hero

    var hero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(item.group.displayName)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)

            Text(item.name)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(metaLine)
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)

            if hasStatusPill {
                statusPill
            }
        }
    }

    /// True when the hero has a plateau or readiness pill to show —
    /// gates the conditional include so the VStack spacing doesn't
    /// leave a gap when neither fires.
    var hasStatusPill: Bool {
        plateauStatus != nil || effortSummary?.verdict == .ready
    }

    /// Plateau wins over readiness when both could fire — a stall is
    /// the more urgent signal. Renders nothing when neither applies.
    @ViewBuilder
    var statusPill: some View {
        if let plateau = plateauStatus {
            pill(text: "Stalled · \(plateau.sessions) sessions", accent: false)
        } else if effortSummary?.verdict == .ready {
            pill(text: "Ready to add load", accent: true)
        }
    }

    func pill(text: String, accent: Bool) -> some View {
        Text(text)
            .font(Typography.metricUnit)
            .foregroundStyle(accent ? Tint.complete : Ink.tertiary)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .background(Capsule().fill(Surface.cardTint))
            .overlay(Capsule().stroke(accent ? Tint.primaryDim : Surface.edge, lineWidth: 1))
    }

    /// Sentence-case classification line: equipment · pattern (when
    /// compound) · mechanic · plane · unilateral (only when it is —
    /// bilateral is the unremarkable default, so we omit it). Replaces
    /// the old chip strip with plain type, same vocabulary as the
    /// catalog row meta.
    var metaLine: String {
        var parts = [item.equipment.displayName]
        if item.mechanic == .compound, let pattern = item.pattern {
            parts.append(pattern.displayName)
        }
        parts.append(item.mechanic.displayName)
        parts.append(item.plane.displayName)
        if item.laterality == .unilateral {
            parts.append(item.laterality.displayName)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Stats row

    var statsRow: some View {
        HStack(spacing: 0) {
            statCard(
                label: "Last",
                value: lastValueString,
                detail: lastDetailString
            )
            statDivider
            statCard(
                label: "Best",
                value: bestValueString,
                detail: bestDetailString
            )
            statDivider
            statCard(
                label: "Times",
                value: countString,
                detail: countDetailString
            )
        }
    }

    func statCard(label: String, value: String, detail: String?) -> some View {
        VStack(spacing: Space.sm) {
            Text(value)
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .sectionLabelStyle(Opacity.soft)
            if let detail {
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text(" ")
                    .font(Typography.caption)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    var statDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(width: 0.5, height: 54)
            .accessibilityHidden(true)
    }

    // MARK: - One-rep max

    /// Dedicated, tappable 1RM row. Shows a user-measured max (the
    /// precise, hand-entered value) when set; otherwise the estimated
    /// e1RM from logged sets; otherwise an empty "tap to add" prompt
    /// when there's nothing to show yet. Tapping opens the scrubber
    /// editor. Reps-only — holds have no meaningful 1RM.
    var oneRepMaxRow: some View {
        let measured = item.oneRepMax
        let value = measured ?? estimatedOneRepMax
        return Button {
            Haptics.soft()
            isEditingOneRepMax = true
        } label: {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1RM")
                        .sectionLabelStyle(Opacity.soft)
                    Text(oneRepMaxSubLabel(measured: measured))
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }

                Spacer(minLength: Space.sm)

                if let value {
                    Text(WeightFormatter.string(value, unit: unit))
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .monospacedDigit()
                } else {
                    Text("Add")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Tint.complete)
                }

                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .padding(Space.lg)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Surface.cardTint)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("One-rep max")
    }

    /// Sub-label under the "1RM" caption: distinguishes a precise
    /// measured value from the estimate (with the date the estimate
    /// peaked), or invites the user to add one.
    func oneRepMaxSubLabel(measured: Double?) -> String {
        if measured != nil { return "Measured" }
        guard estimatedOneRepMax != nil else {
            return "Tap to enter your tested max"
        }
        if let date = estimatedOneRepMaxDate {
            return "Estimated · \(RelativeDate.short(date))"
        }
        return "Estimated"
    }

    // MARK: - Chart section

    var chartSection: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Progress")
                .sectionLabelStyle(Opacity.medium)

            if item.trackingMode == .reps {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(ChartMetric.allCases) { m in
                            metricChip(m)
                        }
                    }
                }
            }

            chart

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(TimeRange.allCases) { r in
                        rangeChip(r)
                    }
                }
            }
        }
    }

    func metricChip(_ m: ChartMetric) -> some View {
        let isSelected = m == chartMetric
        return Button {
            Haptics.selection()
            chartMetric = m
        } label: {
            Text(m.label)
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minHeight: Space.tapMin)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    var chart: some View {
        // Resolve the series ONCE: `progress` rebuilds its points
        // (and their UUIDs) on every access, so the visible slice and
        // the PR-id set must derive from the same instance to line up.
        let prog = progress
        let visible = visiblePoints(from: prog)
        let prIDs = prPointIDs(from: prog)
        return Chart {
            ForEach(visible) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Metric", chartValue(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Ink.primary.opacity(Opacity.strong))

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Metric", chartValue(for: point))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Ink.primary.opacity(0.20), Ink.primary.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                if prIDs.contains(point.id) {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Metric", chartValue(for: point))
                    )
                    .symbol(.circle)
                    .symbolSize(60)
                    .foregroundStyle(prColor)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.primary.opacity(Opacity.medium))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Surface.edge)
                AxisValueLabel()
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.primary.opacity(Opacity.medium))
            }
        }
        .frame(height: 200)
        .accessibilityLabel("Progress chart")
    }

    func rangeChip(_ r: TimeRange) -> some View {
        let isSelected = r == range
        return Button {
            Haptics.selection()
            range = r
        } label: {
            Text(r.label)
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minWidth: Space.tapMin, minHeight: Space.tapMin)
                .padding(.horizontal, 12)
                .coloredGlassControl(cornerRadius: Radius.pill, fill: isSelected ? Tint.inProgress : nil)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // MARK: - Effort

    /// Average RIR + a one-line "what to do next" verdict. Self-gates
    /// to nothing for timed holds and for lifts without enough logged
    /// RIR readings (see `effortSummary`).
    @ViewBuilder
    var effortSection: some View {
        if let effort = effortSummary {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Effort")
                    .sectionLabelStyle(Opacity.medium)

                HStack(alignment: .center, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "RIR %.1f", effort.avgRIR))
                            .font(Typography.statValue)
                            .foregroundStyle(Ink.primary)
                            .monospacedDigit()
                        Text("Last · \(effort.lastSessionSetCount) \(effort.lastSessionSetCount == 1 ? "set" : "sets")")
                            .font(Typography.caption)
                            .foregroundStyle(Ink.quaternary)
                    }

                    Spacer(minLength: 8)

                    if let headline = effort.verdict.headline {
                        Text(headline)
                            .font(Typography.sectionLabel)
                            .foregroundStyle(verdictColor(effort.verdict))
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Surface.cardTint)
                )
            }
        }
    }

    func verdictColor(_ verdict: ProgressionVerdict) -> Color {
        switch verdict {
        case .ready: return Tint.complete
        case .grind: return Tint.danger
        case .push:  return Ink.tertiary
        case .none:  return Ink.tertiary
        }
    }

    // MARK: - Muscles

    /// Primary / secondary muscle involvement for the lift, resolved
    /// from the curated catalog map. Rendered as middot-joined text
    /// lines (matching the hero meta line) rather than chips, in step
    /// with the app's move away from chip strips. Hidden entirely for
    /// custom exercises the map doesn't know (`.empty`).
    @ViewBuilder
    var muscleBreakdownSection: some View {
        let involvement = item.muscleInvolvement
        if !involvement.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Muscles")
                    .sectionLabelStyle(Opacity.medium)

                let primary = involvement.primary
                let secondary = involvement.secondary
                if !primary.isEmpty {
                    muscleRow(label: "Primary", muscles: primary, prominent: true)
                }
                if !secondary.isEmpty {
                    muscleRow(label: "Secondary", muscles: secondary, prominent: false)
                }
            }
        }
    }

    func muscleRow(label: String, muscles: [Muscle], prominent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
                .frame(width: 100, alignment: .leading)
                .minimumScaleFactor(0.7)
            Text(muscles.map(\.displayName).joined(separator: " · "))
                .font(Typography.body)
                .foregroundStyle(prominent ? Ink.secondary : Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Recent sessions

    var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Recent sessions")
                .sectionLabelStyle(Opacity.medium)

            let rows = recentRows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                    if idx > 0 { SectionDivider() }
                    recentRow(row)
                }
            }
        }
    }

    func recentRow(_ row: RecentSessionRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: row.date))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                    .minimumScaleFactor(0.7)
                Text(RelativeDate.short(row.date))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 110, alignment: .leading)

            Text(recentMetricLabel(row))
                .font(Typography.metricUnit)
                .foregroundStyle(row.isPR ? Tint.complete : Ink.primary)
                .monospacedDigit()

            Spacer()

            Text("× \(row.setCount)")
                .font(Typography.caption)
                .foregroundStyle(Ink.tertiary)

            if row.isPR {
                Text("PR")
                    .font(Typography.metricMicro)
                    .foregroundStyle(Tint.onAccent)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(prColor))
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Defaults

    var defaultsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Defaults")
                .sectionLabelStyle(Opacity.medium)

            HStack(spacing: Space.lg) {
                switch item.trackingMode {
                case .reps:
                    defaultStat(label: "Weight", value: WeightFormatter.string(item.defaultWeight(forUnit: unit), unit: unit))
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(width: 0.5, height: 32)
                        .accessibilityHidden(true)
                    defaultStat(label: "Reps", value: "\(item.defaultReps)")
                case .duration:
                    defaultStat(label: "Hold", value: DurationFormatter.string(item.defaultDuration))
                    if item.defaultWeight > 0 {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(width: 0.5, height: 32)
                            .accessibilityHidden(true)
                        defaultStat(label: "Load", value: WeightFormatter.string(item.defaultWeight(forUnit: unit), unit: unit))
                    }
                }
                Spacer()
                Text("Used when first picked")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
        }
    }

    func defaultStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
        }
    }

    // MARK: - CTA

    var addToWorkoutCTA: some View {
        Button {
            Haptics.thunk()
            onPickAndDismiss?(item)
        } label: {
            HStack(spacing: 0) {
                Text("Add to Workout")
                    .font(Typography.title)
                    .tracking(0.4)
                Spacer(minLength: 8)
                Image(systemName: "arrow.right")
                    .font(Typography.sectionHeading)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Tint.onAccent)
            .padding(.horizontal, Space.xxl)
            .padding(.vertical, Space.xl)
            .frame(maxWidth: .infinity)
            .coloredGlassControl(cornerRadius: Radius.card, fill: Tint.inProgress, interactive: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, 8)
        .padding(.top, 12)
    }

    // MARK: - Derived

    /// Captures one row in the Recent Sessions table.
    struct RecentSessionRow {
        let date: Date
        let topWeight: Double
        let topReps: Int
        let topDuration: TimeInterval
        let setCount: Int
        let isPR: Bool
    }

    /// Mode-aware top-set label for a recent row — "145 lb × 8" for
    /// strength, "0:45" (or "25 lb × 0:45" when loaded) for a hold.
    func recentMetricLabel(_ row: RecentSessionRow) -> String {
        switch item.trackingMode {
        case .reps:
            return "\(WeightFormatter.string(row.topWeight, unit: unit)) × \(row.topReps)"
        case .duration:
            let time = DurationFormatter.string(row.topDuration)
            return row.topWeight > 0
                ? "\(WeightFormatter.string(row.topWeight, unit: unit)) × \(time)"
                : time
        }
    }

    /// Stable lookup keys matching `lastInstanceByExercise()` and
    /// `progressByExercise()`. The name key is only a fallback for
    /// legacy history written before copied catalog IDs existed.
    var historyKey: String { item.historyKey }
    var legacyHistoryKey: String { item.legacyHistoryKey }

    /// All progress points for this exercise across history. Nil
    /// when the user has fewer than 2 sessions (matches the
    /// >=2 filter inside `progressByExercise`). The chart needs
    /// at least 2 points to be more than a dot.
    var progress: ExerciseProgress? {
        let allProgress = sessionAnalytics?.progress ?? completedSessions.progressByExercise
        return allProgress.first { progress in
            if let catalogItemID = progress.catalogItemID {
                return catalogItemID == item.id
            }
            return progress.name.exerciseIdentityName == item.name.exerciseIdentityName
        }
    }

    /// Recent RIR read + progression verdict. Nil for timed holds and
    /// for lifts with fewer than three logged RIR readings — the card
    /// hides entirely in those cases.
    var effortSummary: ExerciseEffortSummary? {
        guard item.trackingMode == .reps else { return nil }
        return completedSessions.effortSummary(for: item)
    }

    /// Stall on the primary metric over the last N sessions, or nil
    /// when the lift is still progressing / lacks enough history.
    var plateauStatus: PlateauStatus? {
        progress?.plateauStatus(threshold: Self.plateauThreshold)
    }

    /// Most-recent top set + relative date + PR flag. Nil when the
    /// user has never logged this exercise.
    var lastInstance: LastExerciseInstance? {
        let lookup = completedSessions.lastInstanceByExercise()
        return lookup[historyKey] ?? lookup[legacyHistoryKey]
    }

    /// Number of archived sessions that include this exercise.
    var sessionCount: Int {
        completedSessions.reduce(0) { acc, session in
            acc + (session.orderedExercises.contains(where: {
                $0.matchesCatalogItem(item)
                && $0.sets.contains(where: \.isCompleted)
            }) ? 1 : 0)
        }
    }

    /// True if there's any history at all (>=1 session). Distinct
    /// from `progress != nil` which requires >=2 sessions — the
    /// chart hides on 0 or 1 sessions, but the recent-sessions
    /// table can still surface a single instance.
    var hasHistory: Bool { lastInstance != nil }

    /// Latest 5 sessions for this exercise (newest first), with
    /// top set + total completed-set count + PR flag computed.
    var recentRows: [RecentSessionRow] {
        // Walk archive newest-first (already sorted that way via
        // the @Query order: .reverse), pick up to 5 sessions that
        // include this exercise. The "best" axis is mode-aware:
        // heaviest weight for reps, longest hold for duration.
        let isDuration = item.trackingMode == .duration
        let completedSets = completedSessions
            .flatMap(\.orderedExercises)
            .filter { $0.matchesCatalogItem(item) }
            .flatMap { $0.sets.filter(\.isCompleted) }
        let allTimeBest = isDuration
            ? (completedSets.map(\.duration).max() ?? 0)
            : (completedSets.map(\.weight).max() ?? 0)

        var rows: [RecentSessionRow] = []
        for session in completedSessions {
            guard let exercise = session.orderedExercises.first(where: {
                $0.matchesCatalogItem(item)
            }) else { continue }
            let completed = exercise.sets.filter(\.isCompleted)
            guard !completed.isEmpty else { continue }

            let top = isDuration
                ? completed.max { a, b in a.duration < b.duration }!
                : completed.max { a, b in
                    if a.weight == b.weight { return a.reps < b.reps }
                    return a.weight < b.weight
                }!
            let date = session.completedAt ?? session.startedAt
            let metric = isDuration ? top.duration : top.weight

            rows.append(RecentSessionRow(
                date: date,
                topWeight: top.weight,
                topReps: top.reps,
                topDuration: top.duration,
                setCount: completed.count,
                isPR: metric >= allTimeBest && metric > 0
            ))

            if rows.count >= 5 { break }
        }
        return rows
    }

    // MARK: - Display strings (stats row)

    /// "145 × 8" (in user's unit) when there's history; "—" otherwise.
    /// Mode-aware via `LastExerciseInstance.metricLabel`.
    var lastValueString: String {
        guard let last = lastInstance else { return "—" }
        return last.metricLabel(unit: unit)
    }

    var lastDetailString: String? {
        guard let last = lastInstance else { return nil }
        return RelativeDate.short(last.sessionDate)
    }

    var bestValueString: String {
        let isDuration = item.trackingMode == .duration
        guard let prog = progress else {
            // Progress requires >=2 sessions. If we have 1, surface
            // that single top set as the "best" so the column isn't
            // empty when the user is just getting started.
            if let last = lastInstance {
                return isDuration
                    ? DurationFormatter.string(last.topDuration)
                    : WeightFormatter.string(last.topWeight, unit: unit, includeUnit: false)
            }
            return "—"
        }
        return isDuration
            ? DurationFormatter.string(prog.bestDuration)
            : WeightFormatter.string(prog.bestWeight, unit: unit, includeUnit: false)
    }

    var bestDetailString: String? {
        let isDuration = item.trackingMode == .duration
        guard let prog = progress else {
            // For a one-session user the "best" IS today's session.
            guard let last = lastInstance else { return nil }
            return RelativeDate.short(last.sessionDate)
        }
        // Find when the all-time best was achieved (on the active axis).
        let bestPoint = isDuration
            ? prog.points.first(where: { $0.topDuration == prog.bestDuration })
            : prog.points.first(where: { $0.topWeight == prog.bestWeight })
        if let bestPoint {
            return RelativeDate.short(bestPoint.date)
        }
        return nil
    }

    /// All-time best estimated 1RM (canonical lb), or nil when there
    /// are no reps to estimate from. Falls back to a single session's
    /// Epley estimate before a 2-session trend exists. Drives the
    /// estimated fallback in the dedicated 1RM row.
    var estimatedOneRepMax: Double? {
        if let prog = progress {
            return prog.bestE1RM > 0 ? prog.bestE1RM : nil
        }
        if let last = lastInstance, last.topReps > 0 {
            return last.topWeight * (1.0 + Double(last.topReps) / 30.0)
        }
        return nil
    }

    /// When the estimated 1RM peaked — surfaced as the row's "Estimated
    /// · 7d ago" sub-label.
    var estimatedOneRepMaxDate: Date? {
        if let prog = progress, let point = prog.bestE1RMPoint {
            return point.date
        }
        if let last = lastInstance, last.topReps > 0 {
            return last.sessionDate
        }
        return nil
    }

    /// Value the editor opens on: the measured max if set, else the
    /// estimate, else the heaviest logged weight or the catalog
    /// default — anything to avoid scrubbing up from zero.
    var oneRepMaxSeed: Double {
        if let measured = item.oneRepMax { return measured }
        if let estimate = estimatedOneRepMax { return estimate }
        if let prog = progress, prog.bestWeight > 0 { return prog.bestWeight }
        let seed = item.defaultWeight(forUnit: unit)
        if seed > 0 { return seed }
        return 135
    }

    var countString: String {
        sessionCount > 0 ? "\(sessionCount)" : "—"
    }

    var countDetailString: String? {
        guard sessionCount > 0 else { return nil }
        return sessionCount == 1 ? "session" : "sessions"
    }

    // MARK: - Chart helpers

    /// Filter a resolved series by the selected time range. Takes the
    /// series as a parameter (rather than reading `progress` again) so
    /// the chart's visible slice and PR-id set share one instance —
    /// `progress` mints fresh point UUIDs on every access.
    func visiblePoints(from prog: ExerciseProgress?) -> [ExerciseProgressPoint] {
        guard let prog else { return [] }
        guard let cutoff = range.cutoff else { return prog.points }
        return prog.points.filter { $0.date >= cutoff }
    }

    /// IDs of the points that set a new high on the *currently
    /// selected* metric, computed with a running max over the full
    /// chronological series (not just the visible window) so a PR dot
    /// only appears where the value beat everything before it.
    func prPointIDs(from prog: ExerciseProgress?) -> Set<UUID> {
        guard let prog else { return [] }
        var ids = Set<UUID>()
        var runningMax = -Double.infinity
        for point in prog.points {
            let value = metricValue(for: point)
            if value > runningMax {
                runningMax = value
                ids.insert(point.id)
            }
        }
        return ids
    }

    /// The y-value for a chart point in the user's display unit.
    /// Duration exercises always plot hold length; strength exercises
    /// follow the selected `chartMetric`.
    func chartValue(for point: ExerciseProgressPoint) -> Double {
        guard item.trackingMode == .reps else { return point.topDuration }
        switch chartMetric {
        case .weight: return WeightFormatter.toDisplay(point.topWeight, unit: unit)
        case .e1rm:   return WeightFormatter.toDisplay(point.estimated1RM, unit: unit)
        case .volume: return WeightFormatter.toDisplay(point.totalVolume, unit: unit)
        }
    }

    /// Raw (canonical) metric for PR detection — same axis selection
    /// as `chartValue` but without unit conversion, which is
    /// monotonic and so doesn't affect the running-max comparison.
    func metricValue(for point: ExerciseProgressPoint) -> Double {
        guard item.trackingMode == .reps else { return point.topDuration }
        switch chartMetric {
        case .weight: return point.topWeight
        case .e1rm:   return point.estimated1RM
        case .volume: return point.totalVolume
        }
    }
}
