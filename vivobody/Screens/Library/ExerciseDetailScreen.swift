//
//  ExerciseDetailScreen.swift
//  vivobody
//
//  Drill-down view for an ExerciseCatalogItem. Reached by tapping
//  a row in the ExercisePickerSheet — replaces the previous "tap =
//  immediate pick" behavior with "tap = explore, then commit via
//  CTA at the bottom." Long-press on the picker row preserves the
//  quick Edit / Delete context menu.
//
//  Surfaces (when data exists):
//    • Hero    — muscle group accent + exercise name + metadata line,
//                plus a plateau / "ready to add load" status pill
//    • Stats   — Last (top set + relative date), Best (all-time top
//                weight), Times (sessions that included this lift)
//    • 1RM     — Dedicated, tappable row (reps only): a user-measured
//                max (precise) overrides the estimated e1RM; empty
//                until there's data. Tap opens the scrubber editor.
//    • Chart   — SwiftUI Charts line with PR dots + a Weight | e1RM |
//                Volume metric toggle (reps only) + time-range chips
//    • Effort  — average RIR + progression verdict (reps only, gated
//                on having ≥3 logged RIR readings)
//    • Muscles — primary / secondary involvement from the catalog map
//    • Cues    — Catalog-level form notes (persistent across all
//                sessions), tap to edit via NotesEditorSheet
//    • Recents — Last 5 sessions, top set + date + PR flag
//    • Defaults— The catalog item's starting weight × reps
//    • CTA     — "+ Add to Workout" pinned to the bottom safe area
//
//  Empty-state behavior: when the user has never logged this
//  exercise, the stats row shows em-dashes, the chart and recents
//  sections are hidden, and the rest of the screen still functions
//  (notes, defaults, CTA, edit/delete).
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailScreen: View {
    /// The catalog item this screen is exploring. Held as a let —
    /// SwiftData @Model observation handles updates when the editor
    /// sheet mutates the underlying record.
    let item: ExerciseCatalogItem

    /// Bundles the picker's `onPick(item)` + its own `dismiss()` into
    /// a single closure. Nil hides the bottom CTA entirely — useful
    /// when the detail is reached from a non-picking context (future
    /// surfaces like a standalone "Library" tab).
    let onPickAndDismiss: ((ExerciseCatalogItem) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// All archived sessions — drives progress chart + last-used +
    /// total-count + recent table. Same filter as the picker; live
    /// in-flight sessions never contribute.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: \WorkoutSession.completedAt,
        order: .reverse
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    @State private var editorTarget: CatalogEditorTarget?
    @State private var isConfirmingDelete: Bool = false
    @State private var isEditingNotes: Bool = false
    @State private var isEditingOneRepMax: Bool = false
    @State private var range: TimeRange = .all
    @State private var chartMetric: ChartMetric = .e1rm

    /// Number of consecutive stale sessions before the hero flags a
    /// plateau. Five matches the "a working block didn't move the
    /// needle" intuition — short enough to be actionable, long enough
    /// to ignore normal week-to-week noise.
    private static let plateauThreshold = 5

    /// Which series the progress chart plots. Only offered for
    /// `.reps` exercises — timed holds always plot duration.
    enum ChartMetric: String, CaseIterable, Identifiable {
        case weight, e1rm, volume
        var id: String { rawValue }
        var label: String {
            switch self {
            case .weight: return "Weight"
            case .e1rm:   return "e1RM"
            case .volume: return "Volume"
            }
        }
    }

    /// Chart time-range chips. Same enum-shape as
    /// ExerciseProgressDetail.TimeRange — kept private to this screen
    /// because the two screens have separate lifecycles (and the
    /// shared shape isn't reused in a meaningful enough way yet to
    /// justify hoisting it out).
    enum TimeRange: String, CaseIterable, Identifiable {
        case oneMonth, threeMonths, sixMonths, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .oneMonth:    return "1M"
            case .threeMonths: return "3M"
            case .sixMonths:   return "6M"
            case .all:         return "All"
            }
        }
        var cutoff: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: Date())
            case .all:         return nil
            }
        }
    }

    private let prColor = Tint.complete

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                hero
                statsRow
                if item.trackingMode == .reps {
                    oneRepMaxRow
                }
                if hasHistory {
                    chartSection
                }
                effortSection
                muscleBreakdownSection
                formCuesSection
                if hasHistory {
                    recentSessionsSection
                }
                defaultsSection
            }
            .padding(.top, 8)
            .padding(.bottom, Space.xxl)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .detailForgeBackground()
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        editorTarget = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(Typography.headline)
                }
                .accessibilityLabel("More options")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if onPickAndDismiss != nil {
                addToWorkoutCTA
            }
        }
        .sheet(item: $editorTarget) { target in
            CustomExerciseEditorSheet(target: target)
        }
        .sheet(isPresented: $isEditingNotes) {
            NotesEditorSheet(
                title: "\(item.name) Cues",
                placeholder: "Form cues, plate setup, what to remember…",
                initialValue: item.notes,
                onSave: { newNotes in
                    item.notes = newNotes
                    try? modelContext.save()
                }
            )
        }
        .sheet(isPresented: $isEditingOneRepMax) {
            OneRepMaxEditorSheet(
                initialValue: oneRepMaxSeed,
                hasMeasured: item.oneRepMax != nil,
                hasEstimate: estimatedOneRepMax != nil,
                onSave: { newValue in
                    item.oneRepMax = newValue
                    try? modelContext.save()
                }
            )
        }
        .alert(
            "Delete \"\(item.name)\"?",
            isPresented: $isConfirmingDelete
        ) {
            Button("Delete", role: .destructive) {
                deleteAndDismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removes the exercise from your catalog. Templates and history that already reference it stay intact.")
        }
    }

    // MARK: - Hero

    private var hero: some View {
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
    private var hasStatusPill: Bool {
        plateauStatus != nil || effortSummary?.verdict == .ready
    }

    /// Plateau wins over readiness when both could fire — a stall is
    /// the more urgent signal. Renders nothing when neither applies.
    @ViewBuilder
    private var statusPill: some View {
        if let plateau = plateauStatus {
            pill(text: "Stalled · \(plateau.sessions) sessions", accent: false)
        } else if effortSummary?.verdict == .ready {
            pill(text: "Ready to add load", accent: true)
        }
    }

    private func pill(text: String, accent: Bool) -> some View {
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
    private var metaLine: String {
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

    private var statsRow: some View {
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

    private func statCard(label: String, value: String, detail: String?) -> some View {
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
            } else {
                Text(" ")
                    .font(Typography.caption)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(width: 0.5, height: 54)
    }

    // MARK: - One-rep max

    /// Dedicated, tappable 1RM row. Shows a user-measured max (the
    /// precise, hand-entered value) when set; otherwise the estimated
    /// e1RM from logged sets; otherwise an empty "tap to add" prompt
    /// when there's nothing to show yet. Tapping opens the scrubber
    /// editor. Reps-only — holds have no meaningful 1RM.
    private var oneRepMaxRow: some View {
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
    private func oneRepMaxSubLabel(measured: Double?) -> String {
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

    private var chartSection: some View {
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

    private func metricChip(_ m: ChartMetric) -> some View {
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
    }

    private var chart: some View {
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
    }

    private func rangeChip(_ r: TimeRange) -> some View {
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
    }

    // MARK: - Effort

    /// Average RIR + a one-line "what to do next" verdict. Self-gates
    /// to nothing for timed holds and for lifts without enough logged
    /// RIR readings (see `effortSummary`).
    @ViewBuilder
    private var effortSection: some View {
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

    private func verdictColor(_ verdict: ProgressionVerdict) -> Color {
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
    private var muscleBreakdownSection: some View {
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

    private func muscleRow(label: String, muscles: [Muscle], prominent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
                .frame(width: 76, alignment: .leading)
            Text(muscles.map(\.displayName).joined(separator: " · "))
                .font(Typography.body)
                .foregroundStyle(prominent ? Ink.secondary : Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Form cues

    private var formCuesSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("Form cues")
                    .sectionLabelStyle(Opacity.medium)
                Spacer()
                if !item.notes.isEmpty {
                    Button {
                        Haptics.soft()
                        isEditingNotes = true
                    } label: {
                        Text("Edit")
                            .font(Typography.sectionLabel)
                            .foregroundStyle(Ink.secondary)
                            .padding(.horizontal, Space.md)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit form cues")
                }
            }

            cuesContent
        }
    }

    @ViewBuilder
    private var cuesContent: some View {
        if item.notes.isEmpty {
            Button {
                Haptics.soft()
                isEditingNotes = true
            } label: {
                Text("Add form cues")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(item.notes)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Recent sessions

    private var recentSessionsSection: some View {
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

    private func recentRow(_ row: RecentSessionRow) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayFormatter.string(from: row.date))
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
                Text(RelativeDate.short(row.date))
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }
            .frame(width: 90, alignment: .leading)

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
    }

    // MARK: - Defaults

    private var defaultsSection: some View {
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
                    defaultStat(label: "Reps", value: "\(item.defaultReps)")
                case .duration:
                    defaultStat(label: "Hold", value: DurationFormatter.string(item.defaultDuration))
                    if item.defaultWeight > 0 {
                        Rectangle()
                            .fill(Surface.edge)
                            .frame(width: 0.5, height: 32)
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

    private func defaultStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .sectionLabelStyle(Opacity.soft)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.primary)
        }
    }

    // MARK: - CTA

    private var addToWorkoutCTA: some View {
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
        .background(Surface.background)
    }

    // MARK: - Derived

    /// Captures one row in the Recent Sessions table.
    private struct RecentSessionRow {
        let date: Date
        let topWeight: Double
        let topReps: Int
        let topDuration: TimeInterval
        let setCount: Int
        let isPR: Bool
    }

    /// Mode-aware top-set label for a recent row — "145 lb × 8" for
    /// strength, "0:45" (or "25 lb × 0:45" when loaded) for a hold.
    private func recentMetricLabel(_ row: RecentSessionRow) -> String {
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

    /// Lowercased name lookup key matching the convention used in
    /// `lastInstanceByExercise()` and `progressByExercise`.
    private var nameKey: String { item.name.lowercased() }

    /// All progress points for this exercise across history. Nil
    /// when the user has fewer than 2 sessions (matches the
    /// >=2 filter inside `progressByExercise`). The chart needs
    /// at least 2 points to be more than a dot.
    private var progress: ExerciseProgress? {
        completedSessions.progressByExercise.first { $0.name.lowercased() == nameKey }
    }

    /// Recent RIR read + progression verdict. Nil for timed holds and
    /// for lifts with fewer than three logged RIR readings — the card
    /// hides entirely in those cases.
    private var effortSummary: ExerciseEffortSummary? {
        guard item.trackingMode == .reps else { return nil }
        return completedSessions.effortSummary(forExerciseNamed: item.name)
    }

    /// Stall on the primary metric over the last N sessions, or nil
    /// when the lift is still progressing / lacks enough history.
    private var plateauStatus: PlateauStatus? {
        progress?.plateauStatus(threshold: Self.plateauThreshold)
    }

    /// Most-recent top set + relative date + PR flag. Nil when the
    /// user has never logged this exercise.
    private var lastInstance: LastExerciseInstance? {
        completedSessions.lastInstanceByExercise()[nameKey]
    }

    /// Number of archived sessions that include this exercise.
    private var sessionCount: Int {
        completedSessions.reduce(0) { acc, session in
            acc + (session.orderedExercises.contains(where: {
                $0.name.lowercased() == nameKey
                && $0.sets.contains(where: \.isCompleted)
            }) ? 1 : 0)
        }
    }

    /// True if there's any history at all (>=1 session). Distinct
    /// from `progress != nil` which requires >=2 sessions — the
    /// chart hides on 0 or 1 sessions, but the recent-sessions
    /// table can still surface a single instance.
    private var hasHistory: Bool { lastInstance != nil }

    /// Latest 5 sessions for this exercise (newest first), with
    /// top set + total completed-set count + PR flag computed.
    private var recentRows: [RecentSessionRow] {
        // Walk archive newest-first (already sorted that way via
        // the @Query order: .reverse), pick up to 5 sessions that
        // include this exercise. The "best" axis is mode-aware:
        // heaviest weight for reps, longest hold for duration.
        let isDuration = item.trackingMode == .duration
        let completedSets = completedSessions
            .flatMap(\.orderedExercises)
            .filter { $0.name.lowercased() == nameKey }
            .flatMap { $0.sets.filter(\.isCompleted) }
        let allTimeBest = isDuration
            ? (completedSets.map(\.duration).max() ?? 0)
            : (completedSets.map(\.weight).max() ?? 0)

        var rows: [RecentSessionRow] = []
        for session in completedSessions {
            guard let exercise = session.orderedExercises.first(where: {
                $0.name.lowercased() == nameKey
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
    private var lastValueString: String {
        guard let last = lastInstance else { return "—" }
        return last.metricLabel(unit: unit)
    }

    private var lastDetailString: String? {
        guard let last = lastInstance else { return nil }
        return RelativeDate.short(last.sessionDate)
    }

    private var bestValueString: String {
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

    private var bestDetailString: String? {
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
    private var estimatedOneRepMax: Double? {
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
    private var estimatedOneRepMaxDate: Date? {
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
    private var oneRepMaxSeed: Double {
        if let measured = item.oneRepMax { return measured }
        if let estimate = estimatedOneRepMax { return estimate }
        if let prog = progress, prog.bestWeight > 0 { return prog.bestWeight }
        let seed = item.defaultWeight(forUnit: unit)
        if seed > 0 { return seed }
        return 135
    }

    private var countString: String {
        sessionCount > 0 ? "\(sessionCount)" : "—"
    }

    private var countDetailString: String? {
        guard sessionCount > 0 else { return nil }
        return sessionCount == 1 ? "session" : "sessions"
    }

    // MARK: - Chart helpers

    /// Filter a resolved series by the selected time range. Takes the
    /// series as a parameter (rather than reading `progress` again) so
    /// the chart's visible slice and PR-id set share one instance —
    /// `progress` mints fresh point UUIDs on every access.
    private func visiblePoints(from prog: ExerciseProgress?) -> [ExerciseProgressPoint] {
        guard let prog else { return [] }
        guard let cutoff = range.cutoff else { return prog.points }
        return prog.points.filter { $0.date >= cutoff }
    }

    /// IDs of the points that set a new high on the *currently
    /// selected* metric, computed with a running max over the full
    /// chronological series (not just the visible window) so a PR dot
    /// only appears where the value beat everything before it.
    private func prPointIDs(from prog: ExerciseProgress?) -> Set<UUID> {
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
    private func chartValue(for point: ExerciseProgressPoint) -> Double {
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
    private func metricValue(for point: ExerciseProgressPoint) -> Double {
        guard item.trackingMode == .reps else { return point.topDuration }
        switch chartMetric {
        case .weight: return point.topWeight
        case .e1rm:   return point.estimated1RM
        case .volume: return point.totalVolume
        }
    }

    // MARK: - Mutations

    /// Remove the catalog item, save, then dismiss the screen — the
    /// picker's @Query will refresh and the row disappears. Templates
    /// and history are unaffected (they copy values at pick-time and
    /// never reference catalog items directly).
    private func deleteAndDismiss() {
        modelContext.delete(item)
        try? modelContext.save()
        Haptics.thunk()
        dismiss()
    }

    // MARK: - Formatters

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - One-rep max editor

/// Small sheet for entering a measured one-rep max. Opens seeded on
/// the current value (measured / estimated / heaviest set), scrubs in
/// the user's unit via `WeightScrubber`, and saves a canonical-lb
/// value. The secondary action clears the measured max (passing nil)
/// — it only appears when one is set, and reads "Use estimate
/// instead" when there's an estimate to fall back to, otherwise
/// "Remove measured max" (which returns the row to empty).
private struct OneRepMaxEditorSheet: View {
    let initialValue: Double
    let hasMeasured: Bool
    let hasEstimate: Bool
    let onSave: (Double?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Double

    init(
        initialValue: Double,
        hasMeasured: Bool,
        hasEstimate: Bool,
        onSave: @escaping (Double?) -> Void
    ) {
        self.initialValue = initialValue
        self.hasMeasured = hasMeasured
        self.hasEstimate = hasEstimate
        self.onSave = onSave
        _draft = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.lg) {
                Text("Enter your tested one-rep max. A measured max is more accurate than the estimate from your logged sets.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.xl)
                    .padding(.top, Space.lg)

                WeightScrubber(canonicalWeight: $draft, purpose: .strength, label: nil)

                if hasMeasured {
                    Button {
                        Haptics.soft()
                        onSave(nil)
                        dismiss()
                    } label: {
                        Text(hasEstimate ? "Use estimate instead" : "Remove measured max")
                            .font(Typography.sectionHeading)
                            .foregroundStyle(Ink.secondary)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Surface.background.ignoresSafeArea())
            .navigationTitle("One-Rep Max")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Haptics.soft()
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .presentationDetents([.medium])
        }
    }
}
