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

    // MARK: - Hero figure

    /// The staged anatomy model, promoted from the old mid-screen
    /// "Exercise anatomy" section into the hero so the screen opens
    /// with a visual instead of a wall of type. Same temporary
    /// role-based map as before (primary 1 / secondary 0.5 /
    /// stabilizer 0.2), framed as a card with its legend printed
    /// underneath. Hidden for custom exercises the map doesn't know.
    @ViewBuilder
    var heroFigureSection: some View {
        let involvement = item.muscleInvolvement
        if !involvement.isEmpty && involvement.contributions.contains(where: { $0.muscle.isVisualized }) {
            VStack(spacing: Space.lg) {
                StagedBodyModel(
                    renderHeight: 240,
                    channels: involvement.anatomyNodeChannels,
                    warmth: 0.55
                )
                .frame(height: 240)
                .accessibilityElement()
                .accessibilityLabel("Muscles used by \(item.name). Primary muscles are most vivid, secondary muscles are medium, and stabilizers are faint.")

                VStack(alignment: .leading, spacing: Space.sm) {
                    anatomyRoleRow(role: .primary, muscles: involvement.primary)
                    anatomyRoleRow(role: .secondary, muscles: involvement.secondary)
                    anatomyRoleRow(role: .stabilizer, muscles: involvement.stabilizers)
                }
            }
            .padding(Space.md)
            .contentCard()
        }
    }

    /// One keyed legend row: the role's color dot (same ramp the model
    /// renders) + role label + the muscle names that carry it. Rows
    /// for roles with no muscles hide themselves. Replaces both the
    /// old dots-only legend and the separate mid-screen Muscles list.
    @ViewBuilder
    func anatomyRoleRow(role: MuscleRole, muscles: [Muscle]) -> some View {
        if !muscles.isEmpty {
            let rgb = MuscleColor.rgb(
                for: MuscleMapChannels(intensity: role.visualIntensity),
                theme: colorScheme == .dark ? .dark : .light
            )
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                        .frame(width: 9, height: 9)
                    Text(role.displayName)
                        .sectionLabelStyle(Opacity.soft)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 100, alignment: .leading)
                Text(muscles.map(\.displayName).joined(separator: " · "))
                    .font(Typography.sectionHeading)
                    .foregroundStyle(role == .primary ? Ink.secondary : Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// True when the hero has a plateau or readiness pill to show.
    /// Comparable dynamic lifts leave direction to the e1RM trend card,
    /// avoiding a raw-record "stalled" pill that could contradict it.
    var hasStatusPill: Bool {
        (!supportsEstimatedOneRepMax && plateauStatus != nil)
            || readinessAction != nil
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
        if !supportsEstimatedOneRepMax, let plateau = plateauStatus {
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

    // MARK: - Stats row

    /// Focal-first arrangement: the standing record gets a hero card
    /// with the huge monospaced numeral (the screen's one editorial
    /// moment), while Last and Times step back into supporting
    /// half-width cards. Replaces the old flat three-up band where
    /// every number competed at the same weight.
    var statsRow: some View {
        VStack(spacing: Space.sm) {
            bestHeroCard
            HStack(spacing: Space.sm) {
                statCard(
                    label: "Last",
                    value: lastValueString,
                    detail: lastDetailString
                )
                statCard(
                    label: "Times",
                    value: countString,
                    detail: countDetailString
                )
            }
        }
    }

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
        .padding(.vertical, Space.lg)
        .frame(maxWidth: .infinity)
        .contentCard()
        .accessibilityElement(children: .combine)
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

            if !isStrengthTrend || strengthTrendStat != nil {
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
            chartPlaceholder
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
                   let lastValue = chartValue(for: lastPoint) {
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
        case .e1rm:   return "Estimated one-rep max"
        case .volume: return "Volume"
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
        if item.trackingMode == .duration && !item.performanceSemanticKind.comparesLoad {
            return DurationFormatter.string(value)
        }
        let formatted = value.formatted(.number.precision(.fractionLength(0...1)))
        return "\(formatted) \(unit.symbol)"
    }

    private var chartPlaceholder: some View {
        ZStack {
            GhostCard(padding: Space.lg) {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { index in
                        GhostBar(height: 1, cornerRadius: 0, opacity: 0.06)
                        if index < 3 { Spacer() }
                    }
                }
                .frame(height: 160)
            }

            VStack(spacing: Space.sm) {
                Text("Not enough data yet")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                Text(chartPlaceholderMessage)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
            }
            .padding(.horizontal, Space.xl)
        }
        .frame(height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress chart unavailable. \(chartPlaceholderMessage)")
    }

    private var chartPlaceholderMessage: String {
        if sessionCount < 2 {
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
        case .ready: return Tint.complete
        case .grind: return Tint.danger
        case .push:  return Ink.tertiary
        case .none:  return Ink.tertiary
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
    /// screen is actually frozen: the progress chart or the rhythm
    /// card. Free users with no history never see an unprompted CTA.
    var showsUnlockControl: Bool {
        guard let pro, !pro.isUnlocked else { return false }
        return hasHistory || progressionCadence != nil
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
        let now = Date()
        var points = prog.points.filter { $0.date <= now }
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

    /// Cached confidence-gated estimated-strength direction for this
    /// exercise. The detail uses the exact board already built for Today
    /// and the widget; no analytics are recomputed during rendering.
    var strengthTrendStat: StrengthOutlookStat? {
        guard supportsEstimatedOneRepMax else { return nil }
        return sessionAnalytics?.strength.stat(forHistoryKey: historyKey)
            ?? sessionAnalytics?.strength.stat(forHistoryKey: legacyHistoryKey)
    }

    /// Confidence-eligible workout dates from the cached history index.
    /// Unlike `ExerciseProgress`, this index retains the first point, so
    /// the build-up card can honestly advance from 0/4 to 1/4.
    var strengthTrendReadinessDates: [Date] {
        guard supportsEstimatedOneRepMax else { return [] }
        return sessionAnalytics?.exerciseHistorySummaries[historyKey]?
            .estimatedOneRepMaxDates
            ?? sessionAnalytics?.exerciseHistorySummaries[legacyHistoryKey]?
                .estimatedOneRepMaxDates
            ?? []
    }
}
