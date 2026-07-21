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

            if !movementDefinition.isEmpty {
                Text(movementDefinition)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs)
            }

            if hasStatusPill {
                statusPill
            }
        }
    }

    /// True when the hero has a plateau or readiness pill to show —
    /// gates the conditional include so the VStack spacing doesn't
    /// leave a gap when neither fires.
    var hasStatusPill: Bool {
        plateauStatus != nil || readinessAction != nil
    }

    /// Resistance progression follows the exercise's load polarity.
    /// Machine-assisted work advances by reducing assistance.
    var readinessAction: String? {
        effortSummary?.verdict.progressionAction(for: item.loadMode)
    }

    /// Plateau wins over readiness when both could fire — a stall is
    /// the more urgent signal. Renders nothing when neither applies.
    @ViewBuilder
    var statusPill: some View {
        if let plateau = plateauStatus {
            pill(text: "Stalled · \(plateau.sessions) sessions", accent: false)
        } else if let readinessAction {
            pill(text: "Ready to \(readinessAction)", accent: true)
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
        if item.mechanic == .compound, let movementLabel = item.movementLabel {
            parts.append(movementLabel)
        }
        parts.append(item.mechanic.displayName)
        parts.append(item.plane.displayName)
        if item.laterality == .unilateral {
            parts.append(item.laterality.displayName)
        }
        return parts.joined(separator: " · ")
    }

    var movementDefinition: String {
        item.movementDefinition.trimmingCharacters(in: .whitespacesAndNewlines)
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
    /// editor. Dynamic-strength e1RM semantics only — power and holds
    /// never surface this row.
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
                        ForEach(availableChartMetrics) { m in
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
        let isSelected = m == effectiveChartMetric
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
                if let value = chartValue(for: point) {
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Metric", value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Ink.primary.opacity(Opacity.strong))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Metric", value)
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
                            y: .value("Metric", value)
                        )
                        .symbol(.circle)
                        .symbolSize(60)
                        .foregroundStyle(prColor)
                    }
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

    /// Free-tier stand-in for `chartSection`: the user's real chart,
    /// frozen behind a blur, with one quiet unlock row. Numeric stats
    /// above and below stay free — only the trend visualisation is
    /// part of Pro.
    var lockedChartSection: some View {
        ZStack {
            chartSection
                .blur(radius: 12)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: Space.md) {
                Text("Progress charts are part of Pro")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .multilineTextAlignment(.center)

                Button {
                    Haptics.soft()
                    isPaywallPresented = true
                } label: {
                    Text("Unlock")
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Tint.onAccent)
                        .padding(.horizontal, Space.xxl)
                        .frame(minHeight: Space.tapMin)
                        .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.inProgress)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock Vivobody Pro")
            }
            .padding(Space.xl)
        }
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

                    if let headline = effort.verdict.headline(for: item.loadMode) {
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

    /// A temporary anatomy map for the exercise being inspected. It
    /// uses authored visual roles (1 / 0.5 / 0.2), including power and
    /// stabilizers, and is intentionally separate from Today's chronic
    /// training-development estimate.
    @ViewBuilder
    var exerciseAnatomySection: some View {
        let involvement = item.muscleInvolvement
        if !involvement.isEmpty && involvement.contributions.contains(where: { $0.muscle.isVisualized }) {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Exercise anatomy")
                    .sectionLabelStyle(Opacity.medium)

                StagedBodyModel(
                    renderHeight: 310,
                    channels: involvement.anatomyNodeChannels,
                    warmth: 0.55
                )
                .frame(height: 310)
                .accessibilityElement()
                .accessibilityLabel("Muscles used by \(item.name). Primary muscles are most vivid, secondary muscles are medium, and stabilizers are faint.")

                HStack(spacing: Space.lg) {
                    anatomyLegend(role: .primary)
                    anatomyLegend(role: .secondary)
                    anatomyLegend(role: .stabilizer)
                }

                Text("Movement roles, not training development. Stabilizers are shown but receive no hypertrophy credit.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func anatomyLegend(role: MuscleRole) -> some View {
        let rgb = MuscleColor.rgb(
            for: MuscleMapChannels(intensity: role.visualIntensity),
            theme: colorScheme == .dark ? .dark : .light
        )
        return HStack(spacing: 5) {
            Circle()
                .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                .frame(width: 10, height: 10)
            Text(role.displayName)
                .font(Typography.metricMicro)
                .foregroundStyle(Ink.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

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
                let stabilizers = involvement.stabilizers
                if !primary.isEmpty {
                    muscleRow(label: "Primary", muscles: primary, prominent: true)
                }
                if !secondary.isEmpty {
                    muscleRow(label: "Secondary", muscles: secondary, prominent: false)
                }
                if !stabilizers.isEmpty {
                    muscleRow(label: "Stabilizers", muscles: stabilizers, prominent: false)
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
        let loadMode: ExerciseLoadMode
        let setCount: Int
        let isPR: Bool
    }

    /// Mode-aware top-set label for a recent row — "145 lb × 8" for
    /// strength, "0:45" (or "25 lb × 0:45" when loaded) for a hold.
    func recentMetricLabel(_ row: RecentSessionRow) -> String {
        switch item.trackingMode {
        case .reps:
            let load = row.loadMode.summaryLoadLabel(
                row.topWeight,
                unit: unit
            )
            return load.map { "\($0) × \(row.topReps)" } ?? "\(row.topReps) reps"
        case .duration:
            let time = DurationFormatter.string(row.topDuration)
            guard let load = row.loadMode.summaryLoadLabel(
                    row.topWeight,
                    unit: unit
                  ) else { return time }
            return "\(load) × \(time)"
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
        // Custom exercise IDs deliberately include their performance
        // semantics. Resolve that complete identity before consulting the
        // name-only key used by history from before copied IDs existed.
        return allProgress.first { $0.id == historyKey }
            ?? allProgress.first { $0.id == legacyHistoryKey }
    }

    /// Recent RIR read + progression verdict. Nil outside comparable
    /// dynamic strength and for lifts with fewer than three logged RIR
    /// readings — the card hides entirely in those cases.
    var effortSummary: ExerciseEffortSummary? {
        guard supportsEstimatedOneRepMax else { return nil }
        return completedSessions.effortSummary(for: item)
    }

    /// Stall on the primary metric over the last N sessions, or nil
    /// when the lift is still progressing / lacks enough history.
    var plateauStatus: PlateauStatus? {
        progress?.plateauStatus(threshold: Self.plateauThreshold)
    }

    /// Most-recent top set + relative date + PR flag. Nil when the
    /// user has never logged this exercise. Reads the cached lookup
    /// (same pattern as `progress` above); the recompute fallback
    /// only serves previews.
    var lastInstance: LastExerciseInstance? {
        let lookup = sessionAnalytics?.lastInstances ?? completedSessions.lastInstanceByExercise()
        return lookup[historyKey] ?? lookup[legacyHistoryKey]
    }

    /// Number of archived sessions that include this exercise.
    var sessionCount: Int {
        completedSessions.reduce(0) { acc, session in
            acc + (session.orderedExercises.contains(where: {
                $0.matchesCatalogItem(item)
                && $0.sets.contains(where: \.isAnalyticsEligible)
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
        // Walk archive newest-first (already sorted that way via the
        // @Query order: .reverse), pick up to 5 sessions that include
        // this exercise. The shared representative-set ordering handles
        // effective load, assistance polarity, reps, and hold duration.
        let completedExercises = completedSessions
            .flatMap(\.orderedExercises)
            .filter { $0.matchesCatalogItem(item) }
        let allTimeBest = completedExercises
            .compactMap(\.bestStrengthPerformance)
            .reduce(nil as StrengthPerformance?) { best, candidate in
                guard let best else { return candidate }
                return candidate.beats(best) ? candidate : best
            }

        var rows: [RecentSessionRow] = []
        for session in completedSessions {
            guard let exercise = session.orderedExercises.first(where: {
                $0.matchesCatalogItem(item)
            }) else { continue }
            let completed = exercise.sets.filter(\.isAnalyticsEligible)
            guard !completed.isEmpty,
                  let top = exercise.representativeTopSet else { continue }
            let date = session.completedAt ?? session.startedAt
            let performance = exercise.strengthPerformance(for: top)

            rows.append(RecentSessionRow(
                date: date,
                topWeight: top.weight,
                topReps: top.reps,
                topDuration: top.duration,
                loadMode: exercise.loadMode,
                setCount: completed.count,
                isPR: supportsPerformanceRecord && performance != nil && performance == allTimeBest
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
        guard let prog = progress else {
            // Progress requires >=2 sessions. If we have 1, surface
            // that single top set as the "best" so the column isn't
            // empty when the user is just getting started.
            guard let last = lastInstance else { return "—" }
            if item.performanceSemanticKind.comparesLoad {
                return last.loadMode.loggedLoadLabel(
                    last.topWeight,
                    unit: unit,
                    includeUnit: false
                ) ?? "—"
            }
            if item.trackingMode == .duration {
                return DurationFormatter.string(last.topDuration)
            }
            return last.loadMode.loggedLoadLabel(
                last.topWeight,
                unit: unit,
                includeUnit: false
            ) ?? "—"
        }

        guard let best = bestDisplayPoint(in: prog) else { return "—" }
        if best.performanceSemanticKind.comparesLoad {
            return best.loadMode.loggedLoadLabel(
                best.topWeight,
                unit: unit,
                includeUnit: false
            ) ?? "—"
        }
        if best.trackingMode == .duration {
            return DurationFormatter.string(best.topDuration)
        }
        return best.loadMode.loggedLoadLabel(
            best.topWeight,
            unit: unit,
            includeUnit: false
        ) ?? "—"
    }

    var bestDetailString: String? {
        guard let prog = progress else {
            // For a one-session user the "best" IS today's session.
            guard let last = lastInstance else { return nil }
            return bestDetail(
                reps: last.topReps,
                duration: last.topDuration,
                date: last.sessionDate
            )
        }
        guard let best = bestDisplayPoint(in: prog) else { return nil }
        return bestDetail(
            reps: best.topReps,
            duration: best.topDuration,
            date: best.date
        )
    }

    /// Standing record when the semantic contract supports one; otherwise
    /// the ordinary best history marker. Comparable loaded holds therefore
    /// use the canonical load-first record instead of the globally longest
    /// duration, while duration-only work keeps its time-based best.
    func bestDisplayPoint(in prog: ExerciseProgress) -> ExerciseProgressPoint? {
        if supportsPerformanceRecord {
            return prog.recordPoint
        }
        if item.trackingMode == .duration {
            return prog.points.max { $0.topDuration < $1.topDuration }
        }
        return prog.bestWeightPoint
    }

    /// The Best card's secondary line preserves the record tie-breaker.
    /// Load-ranked reps use reps; load-ranked isometrics use duration;
    /// duration-only and unranked history need only the record date.
    func bestDetail(reps: Int, duration: TimeInterval, date: Date) -> String {
        let relativeDate = RelativeDate.short(date)
        switch item.performanceSemanticKind {
        case .dynamicLoadAndReps, .powerLoadAndReps:
            return "× \(reps) · \(relativeDate)"
        case .isometricLoadAndDuration:
            return "× \(DurationFormatter.string(duration)) · \(relativeDate)"
        case .isometricDuration, .unrankedReps, .unrankedDuration:
            return relativeDate
        }
    }

    /// All-time best estimated 1RM (canonical lb), or nil when there
    /// are no reps to estimate from. Falls back to a single session's
    /// Epley estimate before a 2-session trend exists. Drives the
    /// estimated fallback in the dedicated 1RM row.
    var estimatedOneRepMax: Double? {
        guard item.modality == .dynamicStrength,
              item.loadMode.supportsLoadComparison,
              item.trackingMode == .reps else { return nil }
        if let prog = progress {
            return prog.bestE1RM > 0 ? prog.bestE1RM : nil
        }
        if let last = lastInstance, last.topReps > 0 {
            guard let effectiveLoad = last.effectiveTopLoad,
                  effectiveLoad > 0 else { return nil }
            return effectiveLoad * (1.0 + Double(last.topReps) / 30.0)
        }
        return nil
    }

    /// When the estimated 1RM peaked — surfaced as the row's "Estimated
    /// · 7d ago" sub-label.
    var estimatedOneRepMaxDate: Date? {
        guard item.modality == .dynamicStrength,
              item.loadMode.supportsLoadComparison,
              item.trackingMode == .reps else { return nil }
        if let prog = progress, let point = prog.bestE1RMPoint {
            return point.date
        }
        if let last = lastInstance, last.topReps > 0 {
            return last.sessionDate
        }
        return nil
    }

    /// Value the editor opens on: the measured max if set, else the
    /// estimate, else the greatest logged effective load or catalog
    /// default. Unknown bodyweight deliberately remains a neutral zero.
    var oneRepMaxSeed: Double {
        if let measured = item.oneRepMax { return measured }
        if let estimate = estimatedOneRepMax { return estimate }
        if let prog = progress, prog.bestWeight > 0 { return prog.bestWeight }
        let loggedSeed = item.defaultWeight(forUnit: unit)
        if let seed = item.loadProfile.effectiveLoad(
            loggedWeight: loggedSeed,
            bodyweight: currentBodyweight
        ), seed > 0 {
            return seed
        }
        // A raw assistance or added-load value is not an absolute 1RM.
        // Keep bodyweight-dependent exercises neutral until a measured
        // bodyweight makes their effective load knowable.
        // A zero-default custom lift has supplied no measured-load
        // evidence either. Keep the editor unsaveable until the user
        // enters the value they actually tested.
        return 0
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
        var points = prog.points
        if let cutoff = range.cutoff {
            points = points.filter { $0.date >= cutoff }
        }
        if effectiveChartMetric == .weight,
           item.performanceSemanticKind.comparesLoad {
            // Never relabel raw added load or machine assistance as an
            // absolute resistance when the historical bodyweight is absent.
            points = points.filter { $0.effectiveTopLoad != nil }
        } else if effectiveChartMetric == .e1rm {
            points = points.filter { $0.estimated1RM > 0 }
        } else if effectiveChartMetric == .volume {
            // An unavailable effective load is a missing tonnage point,
            // not a zero-volume performance. Partial values are also
            // withheld so the line never implies a complete subtotal.
            points = points.filter {
                $0.comparableTonnageAvailability == .complete
            }
        }
        return points
    }

    /// IDs of the points that set a new high on the *currently
    /// selected* metric, computed with a running max over the full
    /// chronological series (not just the visible window) so a PR dot
    /// only appears where the value beat everything before it.
    func prPointIDs(from prog: ExerciseProgress?) -> Set<UUID> {
        guard let prog,
              supportsPerformanceRecord else { return [] }
        if item.trackingMode == .reps, effectiveChartMetric == .volume {
            return []
        }
        if item.trackingMode == .duration || effectiveChartMetric == .weight {
            return Set(prog.points.filter(\.isStrengthPR).map(\.id))
        }
        var ids = Set<UUID>()
        var runningMax = -Double.infinity
        for point in prog.points {
            let value = point.estimated1RM
            guard value > 0 else { continue }
            if value > runningMax {
                runningMax = value
                ids.insert(point.id)
            }
        }
        return ids
    }

    /// The y-value for a chart point in the user's display unit. Loaded
    /// isometrics plot absolute effective resistance; duration-only work
    /// plots time. Nil keeps unavailable absolute load or incomplete
    /// comparable tonnage off the chart.
    func chartValue(for point: ExerciseProgressPoint) -> Double? {
        if item.trackingMode == .duration {
            if item.performanceSemanticKind.comparesLoad {
                guard let effectiveLoad = point.effectiveTopLoad else { return nil }
                return WeightFormatter.toDisplay(effectiveLoad, unit: unit)
            }
            return point.topDuration
        }
        switch effectiveChartMetric {
        case .weight:
            guard let historyLoad = point.historyTopLoad else { return nil }
            return WeightFormatter.toDisplay(historyLoad, unit: unit)
        case .e1rm:   return WeightFormatter.toDisplay(point.estimated1RM, unit: unit)
        case .volume:
            guard point.comparableTonnageAvailability == .complete else { return nil }
            return WeightFormatter.toDisplay(point.totalVolume, unit: unit)
        }
    }

    /// Unsupported metrics fall back to the ordinary load-history
    /// line. Only comparable dynamic strength exposes e1RM/tonnage.
    var effectiveChartMetric: ChartMetric {
        availableChartMetrics.contains(chartMetric) ? chartMetric : .weight
    }

    var availableChartMetrics: [ChartMetric] {
        supportsEstimatedOneRepMax ? ChartMetric.allCases : [.weight]
    }

    var supportsPerformanceRecord: Bool {
        item.performanceSemanticKind.supportsRecord
    }

    var supportsEstimatedOneRepMax: Bool {
        item.modality.supportsEstimatedOneRepMax(
            for: item.trackingMode,
            loadMode: item.loadMode
        )
    }
}
