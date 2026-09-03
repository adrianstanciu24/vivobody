//
//  SessionDetailScreen.swift
//  vivobody
//
//  The view a history row pushes into — the permanent record of a
//  past workout, rendered in the same carded-ledger language as the
//  History list it opens from: one focal hero card, then the
//  exercises as a stack of cards beneath it.
//
//  Layout, top to bottom:
//
//    • SESSION HERO — the screen's one focal card. The date and the
//      derived workout title (e.g. "Full body") carry the entry's
//      identity, with the outlined PR capsule beside the title when
//      the session set an all-time record; comparable volume or the
//      honest unloaded work metric follows as a huge monospaced numeral in the completion
//      accent; Duration / Sets / Reps close as a stat strip, with
//      the Top set detail above the load comparison.
//    • EXERCISES — one card per exercise: group label + per-exercise
//      volume or unloaded work (+ the PR capsule when earned), the contribution
//      waterfall, then the set grid of `1   135 × 8` rows in tabular
//      monospace. The top set's numerals render in the completion
//      accent; incomplete sets dim with a hollow status pip.
//    • LOAD COMPARISON — inside the hero below a separator, the selected
//      workout's cumulative comparable volume against the archive average.
//

import SwiftData
import SwiftUI
import VivoKit

struct SessionDetailScreen: View {
    let session: WorkoutSession

    @Environment(\.sessionAnalytics) private var sessionAnalytics

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    /// Every completed session that landed before (or up to and
    /// including) this one, in chronological order. Used to walk the
    /// PR history forward and decide which exercises in *this*
    /// session were all-time top weights at the moment they were
    /// logged. Limiting by `completedAt <= session.completedAt` keeps
    /// the work small and avoids future sessions invalidating past
    /// PR labels.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil },
        sort: [SortDescriptor(\.completedAt, order: .forward)]
    )
    private var allCompletedSessions: [WorkoutSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                heroCard
                    .settleIn(0)
                exercisesSection
                    .settleIn(1)
            }
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .screenBackground()
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Session hero

    /// The session as one physical object, mirroring History's week
    /// hero: identity on top, the lead numeral next, counts as a
    /// strip, the standout set as the footer note.
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header
            heroMetric
            StatStrip(
                stats: [
                    Stat(value: "\(durationMinutes)", unit: "min", label: "Duration"),
                    Stat(value: "\(session.totalSets)", label: "Sets"),
                    Stat(value: "\(session.totalReps)", label: "Reps"),
                ],
                valueFont: Typography.statValue,
                edgeAligned: true
            )
            .padding(.top, Space.xs)

            topSetDetail

            if let loadComparison {
                Rectangle()
                    .fill(Surface.edge)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                WorkoutLoadComparisonChart(
                    comparison: loadComparison,
                    unit: unit
                )
            }
        }
        .padding(Space.lg)
        .contentCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(dateLine)
                .panelLegendType()
                .foregroundStyle(Ink.primary.opacity(Opacity.soft))
            HStack(spacing: Space.sm) {
                Text(workoutTitle)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if sessionHasPR { PRTag() }
            }
        }
    }

    private var heroMetric: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(receiptMetric.value + (receiptMetric.qualifier ?? ""))
                    .font(Typography.metricHero)
                    .foregroundStyle(sessionHasPR ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let metricUnit = receiptMetric.unit {
                    Text(metricUnit)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(receiptMetricLabel)
                .panelLegendType()
                .foregroundStyle(sessionHasPR ? Tint.complete : Ink.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(receiptMetric.accessibilityLabel)
    }

    private var receiptMetric: WorkoutReceiptMetric {
        session.primaryReceiptMetric(unit: unit)
    }

    private var loadComparison: WorkoutLoadComparison? {
        guard let sessionAnalytics else { return nil }
        return WorkoutLoadComparison.make(
            current: WorkoutLoadTrace(session: session),
            baseline: sessionAnalytics.workoutLoadBaseline
        )
    }

    private var receiptMetricLabel: String {
        if sessionHasPR, case .volume(.complete) = receiptMetric.kind {
            return "\(receiptMetric.label) · personal record"
        }
        return receiptMetric.label
    }

    private var topSetDetail: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text("Top set")
                .panelLegend()
            Spacer(minLength: Space.lg)
            Text(topSetValue)
                .font(Typography.metricInline)
                .foregroundStyle(sessionHasPR ? Tint.complete : Ink.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(topSetValue) top set")
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        let breakdown = session.receiptContributions()
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Exercises", trailing: exercisesSubtitle)

            VStack(alignment: .leading, spacing: Space.xxl) {
                ForEach(session.orderedExercises, id: \.id) { exercise in
                    ExerciseDetailRow(
                        exercise: exercise,
                        unit: unit,
                        isPR: prExerciseIDs.contains(exercise.id),
                        supersetTag: session.supersetTag(for: exercise),
                        contribution: breakdown[exercise.id],
                        adherence: session.adherence(for: exercise),
                        showsContributionBar: session.orderedExercises.count > 1
                    )
                }
            }
        }
    }

    private var exercisesSubtitle: String {
        let n = session.orderedExercises.count
        return n == 1 ? "1 exercise" : "\(n) exercises"
    }

    // MARK: - Derived

    private var muscleTags: [MuscleGroup] {
        session.distinctMuscleGroupsInOrder
    }

    /// Same derivation HistoryScreen uses for its row title — keeps
    /// the voice consistent between the list and the detail.
    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: "Workout"
        case 1: "\(muscleTags[0].displayName) day"
        case 2: "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: "Full body"
        }
    }

    private var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return SessionDetailFormatters.date.string(from: date)
    }

    private var durationMinutes: Int {
        max(0, Int(session.duration / 60))
    }

    /// Strongest load-comparable reps set in the session. Selection uses
    /// effective resistance (including inverse machine assistance), while
    /// the label preserves exactly what the user logged. If the receipt has
    /// only unloaded reps, the highest-rep set becomes its ordinary marker.
    private var topSetValue: String {
        let candidates = session.orderedExercises.flatMap { exercise in
            guard exercise.trackingMode == .reps,
                  exercise.performanceSemanticKind.comparesLoad
            else {
                return [(Exercise, WorkoutSet, Double)]()
            }
            return exercise.sets.compactMap { set -> (Exercise, WorkoutSet, Double)? in
                guard set.isAnalyticsEligible,
                      let load = exercise.effectiveLoad(loggedWeight: set.weight)
                else {
                    return nil
                }
                return (exercise, set, load)
            }
        }
        if let (exercise, set, _) = candidates.max(by: { lhs, rhs in
            if lhs.2 == rhs.2 { return lhs.1.reps < rhs.1.reps }
            return lhs.2 < rhs.2
        }) {
            return exercise.setLabel(set, unit: unit)
        }

        let repsCandidates = session.orderedExercises.flatMap { exercise in
            guard exercise.trackingMode == .reps,
                  !exercise.tracksResistance
            else {
                return [(Exercise, WorkoutSet)]()
            }
            return exercise.sets.compactMap { set -> (Exercise, WorkoutSet)? in
                guard set.isAnalyticsEligible, set.reps > 0 else { return nil }
                return (exercise, set)
            }
        }
        guard let (exercise, set) = repsCandidates.max(by: { $0.1.reps < $1.1.reps }) else {
            return "—"
        }
        return exercise.setLabel(set, unit: unit)
    }

    /// Walks all completed sessions in chronological order up to and
    /// including this one, tracking the running record per stable
    /// exercise identity. Reps exercises compare effective load then
    /// reps at equal load; loaded holds rank load then duration, while
    /// duration-only holds rank time. Same semantics as the PR
    /// detection on the History list, scoped to one session.
    private var prExerciseIDs: Set<UUID> {
        var bestByExercise: [String: StrengthPerformance] = [:]
        var result: Set<UUID> = []

        let cutoff = session.completedAt ?? session.startedAt
        for s in allCompletedSessions {
            let sTime = s.completedAt ?? s.startedAt
            if sTime > cutoff { break }
            for exercise in s.orderedExercises {
                guard let performance = exercise.bestStrengthPerformance else { continue }
                let key = exercise.historyKey
                if bestByExercise[key] == nil || performance.beats(bestByExercise[key]!) {
                    bestByExercise[key] = performance
                    if s.id == session.id {
                        result.insert(exercise.id)
                    }
                }
            }
        }
        return result
    }

    private var sessionHasPR: Bool {
        !prExerciseIDs.isEmpty
    }
}

// MARK: - Per-exercise row

private struct ExerciseDetailRow: View {
    let exercise: Exercise
    let unit: WeightUnit
    let isPR: Bool
    var supersetTag: String? = nil
    var contribution: SessionContribution? = nil
    var adherence: ExerciseAdherence? = nil
    var showsContributionBar: Bool = false

    private var mode: TrackingMode {
        exercise.trackingMode
    }

    private var orderedSets: [WorkoutSet] {
        exercise.orderedSets
    }

    /// The exercise's standout completed set, singled out with the
    /// gold completion accent. The domain selector preserves load-mode
    /// polarity and avoids inventing an absolute load when bodyweight
    /// is unknown.
    private var topSet: WorkoutSet? {
        exercise.representativeTopSet
    }

    private var exerciseVolume: Double {
        exercise.completedReceiptTonnage ?? 0
    }

    /// Total timed work across completed sets — the `.duration`
    /// counterpart to `exerciseVolume`, shown in the row header.
    private var totalDuration: TimeInterval {
        exercise.sets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            if showsContributionBar, let contribution, contribution.metric > 0 {
                WaterfallRow(share: contribution.share, isDuration: contribution.isDuration)
            }
            setsGrid
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.md) {
                HStack(spacing: Space.sm) {
                    Text(exercise.group.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                    if isPR { PRTag() }
                    if let supersetTag { SupersetTag(tag: supersetTag) }
                }

                Spacer(minLength: Space.sm)

                VStack(alignment: .trailing, spacing: 3) {
                    volumeCluster
                    if let adherence, !adherence.isOnPlan {
                        AdherenceBadge(adherence: adherence, unit: unit)
                    }
                }
            }

            Text(exercise.name)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var volumeCluster: some View {
        switch mode {
        case .reps:
            if !exercise.supportsReceiptTonnage {
                let reps = exercise.sets
                    .filter(\.isCompleted)
                    .reduce(0) { $0 + $1.reps }
                if reps > 0 {
                    Text("\(reps) reps")
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
            } else if exerciseVolume > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.volumeValue(exerciseVolume, unit: unit))
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        case .duration:
            if totalDuration > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(DurationFormatter.compact(totalDuration))
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                    Text(exercise.modality.durationLabelLowercased)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        }
    }

    /// Sets table. Each row is a thin 3-column line: index, weight,
    /// reps. The top set's numerals render in the gold completion
    /// accent — typographic, no badge. Incomplete sets dim, with a
    /// hollow status pip in place of the filled dot so "lifted" vs
    /// "planned but skipped" stays legible.
    private var setsGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(orderedSets.enumerated()), id: \.element.id) { idx, set in
                setRow(index: idx + 1, set: set)
            }
        }
    }

    private func setRow(index: Int, set: WorkoutSet) -> some View {
        let isTopSet = set === topSet
        let textColor: Color = isTopSet ? Tint.complete : (set.isCompleted ? Ink.primary : Ink.quaternary)

        return HStack(spacing: 0) {
            HStack(spacing: Space.md) {
                statusPip(isCompleted: set.isCompleted, isTopSet: isTopSet)
                Text("\(index)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(set.isCompleted ? Ink.tertiary : Ink.quaternary)
                    .minimumScaleFactor(0.6)
                    .frame(width: 24, alignment: .leading)
            }

            Spacer(minLength: 12)

            setValue(set: set, textColor: textColor)
        }
        .padding(.vertical, Space.sm)
        .frame(maxWidth: .infinity)
    }

    /// The trailing metric cluster of a set row. Reps render as
    /// "135 lb × 8"; holds render as "0:45" — prefixed with the
    /// load ("25 lb · 0:45") only when the hold was weighted.
    @ViewBuilder
    private func setValue(set: WorkoutSet, textColor: Color) -> some View {
        switch mode {
        case .reps:
            if let load = exercise.loadMode.loggedLoadLabel(
                exercise.trackedWeight(set.weight),
                unit: unit,
                includeUnit: true
            ) {
                Text(load)
                    .font(Typography.metricInline)
                    .foregroundStyle(textColor)
                    .monospacedDigit()

                Text("×")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.quaternary)
                    .padding(.horizontal, Space.md)

                Text("\(set.reps)")
                    .font(Typography.metricInline)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .frame(width: 40, alignment: .trailing)
            } else {
                Text("\(set.reps) reps")
                    .font(Typography.metricInline)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
            }

        case .duration:
            if exercise.trackedWeight(set.weight) > 0 {
                Text(exercise.loadMode.loggedLoadLabel(
                    exercise.trackedWeight(set.weight),
                    unit: unit,
                    includeUnit: true
                ) ?? "")
                    .font(Typography.metricInline)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                Text("·")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.quaternary)
                    .padding(.horizontal, Space.md)
            }

            Text(DurationFormatter.string(set.duration))
                .font(Typography.metricInline)
                .foregroundStyle(textColor)
                .monospacedDigit()
                .frame(minWidth: 48, alignment: .trailing)
        }
    }

    private func statusPip(isCompleted: Bool, isTopSet: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCompleted ? (isTopSet ? Tint.complete : Ink.tertiary) : Color.clear)
                .frame(width: 8, height: 8)
            Circle()
                .strokeBorder(isCompleted ? Color.clear : Ink.quaternary, lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Formatters

private enum SessionDetailFormatters {
    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d  ·  h:mm a"
        return f
    }()
}

#Preview {
    NavigationStack {
        SessionDetailScreen(session: WorkoutSession.sampleCompleted)
    }
    .preferredColorScheme(.dark)
}
