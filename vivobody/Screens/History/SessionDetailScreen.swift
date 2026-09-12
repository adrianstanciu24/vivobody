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

    var body: some View {
        let presentation = SessionDetailPresentation(session: session, unit: unit)
        let prExerciseIDs = sessionAnalytics?.prExerciseIDs(for: session.id) ?? []
        let sessionHasPR = !prExerciseIDs.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: Space.section) {
                heroCard(presentation: presentation, sessionHasPR: sessionHasPR)
                    .settleIn(0)
                exercisesSection(
                    presentation: presentation,
                    prExerciseIDs: prExerciseIDs
                )
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
    private func heroCard(
        presentation: SessionDetailPresentation,
        sessionHasPR: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            header(presentation: presentation, sessionHasPR: sessionHasPR)
            heroMetric(
                presentation: presentation,
                sessionHasPR: sessionHasPR
            )
            StatStrip(
                stats: [
                    Stat(value: "\(presentation.durationMinutes)", unit: "min", label: "Duration"),
                    Stat(value: "\(presentation.totalSets)", label: "Sets"),
                    Stat(value: "\(presentation.totalReps)", label: "Reps"),
                ],
                valueFont: Typography.statValue,
                edgeAligned: true
            )
            .padding(.top, Space.xs)

            topSetDetail(
                value: presentation.topSetValue,
                sessionHasPR: sessionHasPR
            )

            if let loadComparison = loadComparison(for: presentation) {
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

    private func header(
        presentation: SessionDetailPresentation,
        sessionHasPR: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(presentation.dateLine)
                .panelLegendType()
                .foregroundStyle(Ink.primary.opacity(Opacity.soft))
            HStack(spacing: Space.sm) {
                Text(presentation.workoutTitle)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if sessionHasPR { PRTag() }
            }
        }
    }

    private func heroMetric(
        presentation: SessionDetailPresentation,
        sessionHasPR: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(presentation.receiptMetric.value + (presentation.receiptMetric.qualifier ?? ""))
                    .font(Typography.metricHero)
                    .foregroundStyle(sessionHasPR ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let metricUnit = presentation.receiptMetric.unit {
                    Text(metricUnit)
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            Text(receiptMetricLabel(
                presentation.receiptMetric,
                sessionHasPR: sessionHasPR
            ))
            .panelLegendType()
            .foregroundStyle(sessionHasPR ? Tint.complete : Ink.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.receiptMetric.accessibilityLabel)
    }

    private func loadComparison(
        for presentation: SessionDetailPresentation
    ) -> WorkoutLoadComparison? {
        guard let sessionAnalytics else { return nil }
        return WorkoutLoadComparison.make(
            current: presentation.currentLoadTrace,
            baseline: sessionAnalytics.workoutLoadBaseline
        )
    }

    private func receiptMetricLabel(
        _ metric: WorkoutReceiptMetric,
        sessionHasPR: Bool
    ) -> String {
        if sessionHasPR, case .volume(.complete) = metric.kind {
            return "\(metric.label) · personal record"
        }
        return metric.label
    }

    private func topSetDetail(
        value: String,
        sessionHasPR: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.md) {
            Text("Top set")
                .panelLegend()
            Spacer(minLength: Space.lg)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(sessionHasPR ? Tint.complete : Ink.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) top set")
    }

    // MARK: - Exercises

    private func exercisesSection(
        presentation: SessionDetailPresentation,
        prExerciseIDs: Set<UUID>
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(
                title: "Exercises",
                trailing: presentation.exercisesSubtitle
            )

            VStack(alignment: .leading, spacing: Space.xxl) {
                ForEach(presentation.exerciseRows, id: \.exercise.id) { row in
                    ExerciseDetailRow(
                        presentation: row,
                        unit: unit,
                        isPR: prExerciseIDs.contains(row.exercise.id),
                        showsContributionBar: presentation.exerciseRows.count > 1
                    )
                }
            }
        }
    }
}

// MARK: - Per-exercise row

private struct ExerciseDetailRow: View {
    let presentation: SessionDetailPresentation.ExerciseRow
    let unit: WeightUnit
    let isPR: Bool
    var showsContributionBar: Bool = false

    private var exercise: Exercise {
        presentation.exercise
    }

    private var mode: TrackingMode {
        exercise.trackingMode
    }

    private var orderedSets: [WorkoutSet] {
        presentation.orderedSets
    }

    /// The exercise's standout completed set, singled out with the
    /// gold completion accent. The domain selector preserves load-mode
    /// polarity and avoids inventing an absolute load when bodyweight
    /// is unknown.
    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            if showsContributionBar,
               let contribution = presentation.contribution,
               contribution.metric > 0
            {
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
                    if let supersetTag = presentation.supersetTag {
                        SupersetTag(tag: supersetTag)
                    }
                }

                Spacer(minLength: Space.sm)

                VStack(alignment: .trailing, spacing: 3) {
                    volumeCluster
                    if let adherence = presentation.adherence,
                       !adherence.isOnPlan
                    {
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
                let reps = presentation.completedReps
                if reps > 0 {
                    Text("\(reps) reps")
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                }
            } else if presentation.receiptTonnage > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.volumeValue(presentation.receiptTonnage, unit: unit))
                        .font(Typography.metricInline)
                        .foregroundStyle(Ink.secondary)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        case .duration:
            if presentation.completedDuration > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(DurationFormatter.compact(presentation.completedDuration))
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
        let isTopSet = set.id == presentation.topSetID
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

#Preview {
    NavigationStack {
        SessionDetailScreen(session: WorkoutSession.sampleCompleted)
    }
    .preferredColorScheme(.dark)
}
