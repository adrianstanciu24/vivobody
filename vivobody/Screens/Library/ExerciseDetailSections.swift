//
//  ExerciseDetailSections.swift
//  vivobody
//
//  Section view builders and derived properties for
//  ExerciseDetailScreen, extracted to keep the main file
//  focused on composition and state.
//

import Charts
import SwiftData
import SwiftUI
import VivoKit

extension ExerciseDetailScreen {
    // MARK: - Hero figure

    /// The staged anatomy model, promoted from the old mid-screen
    /// "Exercise anatomy" section into the hero so the screen opens
    /// with a visual instead of a wall of type. All authored anatomy
    /// roles are visible (primary 1 / secondary 0.5 / stabilizer 0.2),
    /// while hard-set development remains a separate calculation.
    /// Hidden for custom exercises with no authored anatomy. Regions without
    /// a scene surface retain their role text and are called out explicitly;
    /// they never borrow another region's mesh.
    @ViewBuilder
    var heroFigureSection: some View {
        let involvement = item.muscleInvolvement
        if !involvement.isEmpty {
            let hasVisualizedMuscle = involvement.contributions.contains {
                $0.muscle.isVisualized
            }
            let unvisualizedMuscles = involvement.contributions
                .map(\.muscle)
                .filter { !$0.isVisualized }

            VStack(spacing: Space.lg) {
                if hasVisualizedMuscle {
                    StagedBodyModel(
                        renderHeight: 240,
                        channels: involvement.anatomyNodeChannels,
                        warmth: 0.55
                    )
                    .frame(height: 240)
                    .accessibilityElement()
                    .accessibilityLabel("Muscles used by \(item.name). Primary muscles are most vivid, secondary muscles are medium, and stabilizers are faint. Stabilizer color shows involvement, not development credit.")
                }

                VStack(alignment: .leading, spacing: Space.sm) {
                    anatomyRoleRow(role: .primary, muscles: involvement.primary)
                    anatomyRoleRow(role: .secondary, muscles: involvement.secondary)
                    anatomyRoleRow(role: .stabilizer, muscles: involvement.stabilizers)

                    if !unvisualizedMuscles.isEmpty {
                        Text(
                            "3D view unavailable for "
                                + unvisualizedMuscles.map(\.displayName).joined(separator: " · ")
                                + ". Authored roles and eligible training credit remain included."
                        )
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Space.md)
            .contentCard()
        }
    }

    // MARK: - Performance rows

    /// Effective resistance and 1RM belong together: the first explains
    /// the historical load input, the second shows the estimate derived
    /// from it and reps. External-load exercises retain their existing
    /// single 1RM row; only bodyweight-dependent history gains a row.
    var showsPerformanceRows: Bool {
        effectiveLoadDetail != nil || supportsEstimatedOneRepMax
    }

    var performanceRows: some View {
        VStack(spacing: Space.sm) {
            if let detail = effectiveLoadDetail {
                effectiveLoadRow(detail)
            }
            if supportsEstimatedOneRepMax {
                oneRepMaxRow
            }
        }
    }

    /// The standing record's absolute resistance, presented beside the
    /// exact bodyweight snapshot, movement coefficient, and added load or
    /// assistance that produced it. `KitRow` keeps this new explanation in
    /// the same list-row vocabulary as the rest of the app.
    func effectiveLoadRow(_ detail: EffectiveLoadDetail) -> some View {
        let value = detail.effectiveLoad.map {
            WeightFormatter.string($0, unit: unit)
        } ?? "—"
        let subtitle = detail.formula(unit: unit)
            ?? "Body weight unavailable for this session"

        return KitRow(
            title: "Effective load",
            subtitle: subtitle
        ) {
            Text(value)
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Effective load, \(value). \(subtitle)")
    }

    // MARK: - One-rep max

    /// Dedicated, tappable tested-1RM row. Estimated strength is owned
    /// by the trend card below, so this remains an unambiguous manual
    /// measurement instead of repeating the chart's all-time high.
    var oneRepMaxRow: some View {
        let measured = item.oneRepMax
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

                if let measured {
                    Text(WeightFormatter.string(measured, unit: unit))
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
            .contentCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("One-rep max")
    }

    /// Sub-label under the "1RM" caption: this row is deliberately a
    /// tested value, while logged-set estimates remain in Strength trend.
    func oneRepMaxSubLabel(measured: Double?) -> String {
        measured == nil ? "Tap to enter your tested max" : "Tested"
    }

    // MARK: - Chart section

    var chartSection: some View {
        let prog = progress
        let isStrengthTrend = effectiveChartMetric == .e1rm

        return VStack(alignment: .leading, spacing: Space.lg) {
            Text(isStrengthTrend ? "Strength trend" : "Progress")
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

            if isStrengthTrend {
                ExerciseStrengthTrendCard(
                    exerciseName: item.name,
                    progress: prog,
                    stat: strengthTrendStat,
                    readinessDates: strengthTrendReadinessDates,
                    visiblePoints: visiblePoints(from: prog),
                    rangeLabel: range == .all ? "All-time" : range.label,
                    unit: unit
                )
            } else {
                chart
            }

            // Range chips exist only when there is a chart to range.
            // They stay for a range-narrowed placeholder (widening the
            // range is the fix) but hide while no data exists at all.
            let showsRangeChips = isStrengthTrend
                ? strengthTrendStat != nil
                : sessionCount >= 2
            if showsRangeChips {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(TimeRange.allCases) { r in
                            rangeChip(r)
                        }
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

    @ViewBuilder
    var chart: some View {
        // Resolve the series ONCE: `progress` rebuilds its points
        // (and their UUIDs) on every access, so the visible slice and
        // the PR-id set must derive from the same instance to line up.
        let prog = progress
        let visible = visiblePoints(from: prog)
        let plottable = visible.filter { chartValue(for: $0) != nil }
        let prIDs = prPointIDs(from: prog)

        if plottable.count < 2 {
            chartPlaceholder(plottable: plottable)
        } else {
            Chart {
                ForEach(plottable) { point in
                    if let value = chartValue(for: point) {
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(chartMetricAccessibilityName, value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Ink.primary.opacity(Opacity.strong))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(chartMetricAccessibilityName, value)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Tint.primary.opacity(0.22), Tint.primary.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        if prIDs.contains(point.id) {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(chartMetricAccessibilityName, value)
                            )
                            .symbol(.circle)
                            .symbolSize(60)
                            .foregroundStyle(prColor)
                        }
                    }
                }

                // Endpoint marker + value readout: anchors the trend to
                // a number so the latest state reads at a glance. Sits
                // on top of a PR dot without conflict when they coincide.
                if let lastPoint = plottable.last,
                   let lastValue = chartValue(for: lastPoint)
                {
                    PointMark(
                        x: .value("Date", lastPoint.date),
                        y: .value(chartMetricAccessibilityName, lastValue)
                    )
                    .symbol(.circle)
                    .symbolSize(60)
                    .foregroundStyle(prColor)
                    .annotation(position: .top, alignment: .trailing, spacing: 6) {
                        Text(chartAccessibilityValue(lastValue))
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel()
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel()
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .frame(height: 200)
            .padding(Space.md)
            .contentCard()
            .accessibilityLabel("\(item.name) \(chartMetricAccessibilityName.lowercased()) progress")
            .accessibilityValue(chartAccessibilitySummary(points: plottable))
        }
    }

    private var chartMetricAccessibilityName: String {
        if item.trackingMode == .duration {
            return item.performanceSemanticKind.comparesLoad ? "Effective load" : "Duration"
        }
        switch effectiveChartMetric {
        case .weight: return "Load"
        case .e1rm: return "Estimated one-rep max"
        case .volume: return "Volume"
        case .reps: return "Reps"
        }
    }

    private func chartAccessibilitySummary(points: [ExerciseProgressPoint]) -> String {
        guard let first = points.first,
              let last = points.last,
              let firstValue = chartValue(for: first),
              let lastValue = chartValue(for: last)
        else { return "No progress data" }

        let firstDate = first.date.formatted(date: .abbreviated, time: .omitted)
        let lastDate = last.date.formatted(date: .abbreviated, time: .omitted)
        return "\(points.count) sessions. From \(chartAccessibilityValue(firstValue)) on \(firstDate) to \(chartAccessibilityValue(lastValue)) on \(lastDate)."
    }

    private func chartAccessibilityValue(_ value: Double) -> String {
        if effectiveChartMetric == .reps {
            return "\(Int(value.rounded())) reps"
        }
        if item.trackingMode == .duration, !item.performanceSemanticKind.comparesLoad {
            return DurationFormatter.string(value)
        }
        let formatted = value.formatted(.number.precision(.fractionLength(0 ... 1)))
        return "\(formatted) \(unit.symbol)"
    }

    /// The dormant stand-in for `chart`: the live chart's card, grid,
    /// and axis chrome with the point slots still waiting. One logged
    /// session plots its real point with the baseline running out to
    /// the slot the next session fills; zero sessions shows the first
    /// slot breathing on an empty baseline. Text stays at legend level;
    /// VoiceOver still gets the full guidance sentence.
    private func chartPlaceholder(plottable: [ExerciseProgressPoint]) -> some View {
        let inRangePoint = plottable.count == 1 ? plottable[0] : nil
        let plottedValue = inRangePoint.flatMap { point in
            chartValue(for: point).map(chartAccessibilityValue)
        } ?? chartPlaceholderSinglePointValue.map(chartAccessibilityValue)
        return DormantChartCard(
            legend: chartPlaceholderLegend(plottableCount: plottable.count),
            unitLabel: chartPlaceholderUnitLabel,
            plottedValue: plottedValue,
            showsNextSlot: sessionCount < 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress chart unavailable. \(chartPlaceholderMessage)")
    }

    /// The one real value the dormant chart can plot before a trend
    /// exists. `progressByExercise` deliberately waits for two sessions,
    /// so a single session's representative top set comes from the
    /// `lastInstance` fallback, the same source the estimated-1RM row
    /// uses. Mirrored from `ExerciseProgressPoint.historyTopLoad`. A
    /// session the selected range excludes stays unplotted, and Volume
    /// has no honest single-set value (tonnage needs the full session),
    /// so both keep the plain dormant baseline.
    private var chartPlaceholderSinglePointValue: Double? {
        guard singleSessionInRange, let last = lastInstance else { return nil }
        if item.trackingMode == .duration {
            if item.performanceSemanticKind.comparesLoad {
                guard let effectiveLoad = last.effectiveTopLoad else { return nil }
                return WeightFormatter.toDisplay(effectiveLoad, unit: unit)
            }
            return last.topDuration > 0 ? last.topDuration : nil
        }
        if effectiveChartMetric == .reps {
            return last.topReps > 0 ? Double(last.topReps) : nil
        }
        guard effectiveChartMetric == .weight else { return nil }
        guard let load = last.effectiveTopLoad
            ?? (last.loadMode == .nonComparable ? max(0, last.topWeight) : nil)
        else { return nil }
        return WeightFormatter.toDisplay(load, unit: unit)
    }

    /// True when the exercise's one logged session falls inside the
    /// selected chart range.
    private var singleSessionInRange: Bool {
        guard sessionCount == 1, let last = lastInstance else { return false }
        return range.cutoff.map { last.sessionDate >= $0 } ?? true
    }

    private func chartPlaceholderLegend(plottableCount: Int) -> String {
        switch sessionCount {
        case 0:
            "Trend unlocks at 2 sessions"
        case 1:
            singleSessionInRange
                ? "One more session draws the line"
                : "No sessions in this range"
        default:
            plottableCount == 0
                ? "No sessions in this range"
                : "Only one session in this range"
        }
    }

    /// Ghost unit glyph for the dormant y-axis. Pure duration work is
    /// left blank: its live axis prints raw seconds, so any unit glyph
    /// there would invent a scale the real chart does not have.
    private var chartPlaceholderUnitLabel: String? {
        if effectiveChartMetric == .reps { return "reps" }
        if item.trackingMode == .duration,
           !item.performanceSemanticKind.comparesLoad
        {
            return nil
        }
        return unit.symbol
    }

    private var chartPlaceholderMessage: String {
        if sessionCount == 0 || (sessionCount == 1 && singleSessionInRange) {
            return "Complete this exercise in another workout to draw its trend."
        }
        return "Choose a longer range or log another session."
    }

    /// Free-tier stand-in for `chartSection`: the user's real chart,
    /// frozen behind a blur. Numeric stats above and below stay free —
    /// only the trend visualisation is part of Pro. The whole area
    /// opens the paywall; the explicit CTA is the screen's floating
    /// unlock control.
    var lockedChartSection: some View {
        Button {
            Haptics.soft()
            isPaywallPresented = true
        } label: {
            chartSection
                .blur(radius: 12)
                .allowsHitTesting(false)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Progress chart, locked")
        .accessibilityHint("Unlocks with Vivobody Pro")
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
                .contentCard()
            }
        }
    }

    func verdictColor(_ verdict: ProgressionVerdict) -> Color {
        switch verdict {
        case .ready: Tint.complete
        case .grind: Tint.danger
        case .push: Ink.tertiary
        case .none: Ink.tertiary
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
                    if idx > 0 { recentRowDivider }
                    recentRow(row)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.xs)
            .contentCard()
        }
    }

    /// In-card hairline between ledger rows — the same plain, edge
    /// inset line History's date-group cards use (SectionDivider's
    /// gradient fade is the card-free counterpart and stays outside).
    private var recentRowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .accessibilityHidden(true)
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

    /// The floating unlock pill shows only while something on this
    /// screen is actually frozen: the progress chart, the rhythm card,
    /// or the this-week card. Free users with no history never see an
    /// unprompted CTA.
    var showsUnlockControl: Bool {
        guard let pro, !pro.isUnlocked else { return false }
        return hasHistory || progressionCadence != nil || volumeContribution != nil
    }

    /// Same persistent pill as the Insights tab's unlock control, but
    /// wired to this screen's local paywall sheet (the app-root sheet
    /// can't present on top of the picker/Spotlight sheets this
    /// screen can live inside).
    var unlockProControl: some View {
        Button {
            Haptics.soft()
            isPaywallPresented = true
        } label: {
            HStack(spacing: Space.md) {
                Text("Unlock Vivobody Pro")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let price = pro?.displayPrice {
                    Text("· \(price)")
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(Typography.headline)
            .foregroundStyle(Tint.onAccent)
            .frame(minHeight: Space.tapMin)
            .padding(.horizontal, Space.xl)
            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.primary)
            .softElevation(radius: 14, y: 7, opacity: 0.42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlockProControlLabel)
        .accessibilityHint("Opens the Vivobody Pro purchase sheet")
    }

    var unlockProControlLabel: String {
        if let price = pro?.displayPrice {
            return "Unlock Vivobody Pro, \(price)"
        }
        return "Unlock Vivobody Pro"
    }

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

    /// The historical ingredients behind the standing effective-load
    /// record. Values stay canonical pounds until the row formats them.
    struct EffectiveLoadDetail {
        let effectiveLoad: Double?
        let loggedWeight: Double
        let loadMode: ExerciseLoadMode
        let bodyweightFraction: Double
        let bodyweightAtSession: Double

        func formula(unit: WeightUnit) -> String? {
            guard bodyweightAtSession.isFinite, bodyweightAtSession > 0 else {
                return nil
            }

            let bodyweight = WeightFormatter.string(
                bodyweightAtSession,
                unit: unit,
                fractionDigits: 1
            )
            let logged = WeightFormatter.string(
                max(0, loggedWeight),
                unit: unit
            )
            let percent = Int((bodyweightFraction * 100).rounded())

            switch loadMode {
            case .bodyweightAdded:
                return "\(bodyweight) BW × \(percent)% + \(logged)"
            case .assistanceSubtracted:
                return "\(bodyweight) BW × \(percent)% − \(logged)"
            case .external, .nonComparable:
                return nil
            }
        }
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

    /// Stable lookup key matching `lastInstanceByExercise()` and
    /// `progressByExercise()`.
    var historyKey: String {
        item.historyKey
    }

    /// All progress points for this exercise across history. Nil
    /// when the user has fewer than 2 sessions (matches the
    /// >=2 filter inside `progressByExercise`). The chart needs
    /// at least 2 points to be more than a dot.
    var progress: ExerciseProgress? {
        let allProgress = sessionAnalytics?.progress ?? completedSessions.progressByExercise
        return allProgress.first { $0.id == historyKey }
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
        return lookup[historyKey]
    }

    /// Standing effective-load record for bodyweight-added and assisted
    /// movements. With two or more sessions, use the same record point as
    /// the Best stat and PR wall; with one session, use its cached top set.
    /// Unknown bodyweight still produces a detail so the row can explain
    /// why the absolute value is unavailable instead of silently vanishing.
    var effectiveLoadDetail: EffectiveLoadDetail? {
        guard hasHistory else { return nil }
        guard item.loadMode == .bodyweightAdded
            || item.loadMode == .assistanceSubtracted else { return nil }

        if let point = progress?.recordPoint ?? progress?.latest {
            return EffectiveLoadDetail(
                effectiveLoad: point.effectiveTopLoad,
                loggedWeight: point.topWeight,
                loadMode: point.loadMode,
                bodyweightFraction: point.bodyweightFraction,
                bodyweightAtSession: point.bodyweightAtSession
            )
        }

        guard let last = lastInstance else { return nil }
        return EffectiveLoadDetail(
            effectiveLoad: last.effectiveTopLoad,
            loggedWeight: last.topWeight,
            loadMode: last.loadMode,
            bodyweightFraction: last.bodyweightFraction,
            bodyweightAtSession: last.bodyweightAtSession
        )
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
    var hasHistory: Bool {
        lastInstance != nil
    }

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
                topWeight: item.tracksResistance ? max(0, top.weight) : 0,
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

    var bestValueString: String {
        guard let prog = progress else {
            // Progress requires >=2 sessions. If we have 1, surface
            // that single top set as the "best" so the column isn't
            // empty when the user is just getting started.
            guard let last = lastInstance else { return "—" }
            if !item.tracksResistance, item.trackingMode == .reps {
                return "\(last.topReps)"
            }
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
        if !item.tracksResistance, best.trackingMode == .reps {
            return "\(best.topReps)"
        }
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
        if !item.tracksResistance {
            return prog.points.max { $0.topReps < $1.topReps }
        }
        return prog.bestWeightPoint
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
}
