//
//  SessionDetailScreen.swift
//  vivobody
//
//  The view a history row pushes into — the permanent record of a
//  past workout, built in the same instrument language as the live
//  summary "receipt": full-bleed on black, no cards or carved glass,
//  type and hairlines doing the work.
//
//  Layout, top to bottom:
//
//    • Kicker — the date, then the derived workout title (e.g.
//      "Full body") as the entry's identity.
//    • The HERO — the session's total volume as a large monospaced
//      numeral, rendered in the gold completion accent when any
//      exercise set an all-time top weight at the moment it was
//      logged (matching the gold numeral on the History row).
//    • A card-free stat strip — Duration / Sets / Reps / Top set,
//      hairline-divided.
//    • Exercise breakdown — one hairline-divided block per exercise:
//      group label + name + the per-exercise volume on the right,
//      then a set grid of `1   135 × 8` rows in tabular monospace.
//      The top set's numerals render gold; incomplete sets dim with
//      a hollow status pip.
//

import SwiftUI
import SwiftData

struct SessionDetailScreen: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

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
            VStack(alignment: .leading, spacing: 0) {
                kicker
                heroVolume
                    .padding(.top, Space.lg)
                StatStrip(
                    stats: [
                        Stat(value: "\(durationMinutes)", unit: "min", label: "Duration"),
                        Stat(value: "\(session.totalSets)", label: "Sets"),
                        Stat(value: "\(session.totalReps)", label: "Reps"),
                        Stat(value: topSetValue, label: "Top set"),
                    ],
                    valueFont: Typography.statValue
                )
                .padding(.top, Space.xl)

                if SessionIntensityLine.hasContent(session) {
                    SessionIntensityLine(session: session, unit: unit)
                        .padding(.top, Space.md)
                }

                SectionDivider()
                    .padding(.top, Space.xl)

                exercisesSection
                    .padding(.top, Space.lg)
            }
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .detailForgeBackground()
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kicker + hero

    private var kicker: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(dateLine)
                .panelLegendType()
                .foregroundStyle(Ink.primary.opacity(Opacity.soft))
            Text(workoutTitle)
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var heroVolume: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(WeightFormatter.volumeValue(session.totalVolume, unit: unit))
                    .font(Typography.metricHero)
                    .foregroundStyle(sessionHasPR ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit.symbol)
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.tertiary)
            }
            Text(sessionHasPR ? "Volume · personal record" : "Volume")
                .panelLegendType()
                .foregroundStyle(sessionHasPR ? Tint.complete : Ink.tertiary)
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        let breakdown = session.contributions()
        return VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Exercises", trailing: exercisesSubtitle)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(session.orderedExercises.enumerated()), id: \.element.id) { idx, exercise in
                    if idx > 0 { SectionDivider() }
                    ExerciseDetailRow(
                        exercise: exercise,
                        unit: unit,
                        isPR: prExerciseIDs.contains(exercise.id),
                        contribution: breakdown[exercise.id],
                        adherence: session.adherence(for: exercise)
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

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    /// Same derivation HistoryScreen uses for its row title — keeps
    /// the voice consistent between the list and the detail.
    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return "\(muscleTags[0].displayName) day"
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    private var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return SessionDetailFormatters.date.string(from: date)
    }

    private var durationMinutes: Int {
        max(0, Int(session.duration / 60))
    }

    /// Heaviest weight × reps logged across the entire session,
    /// rendered as "135×8". Falls back to "—" when no sets completed.
    private var topSetValue: String {
        let heaviest = session.exercises
            .flatMap(\.sets)
            .filter(\.isCompleted)
            .max(by: { (a, b) in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            })

        guard let set = heaviest else { return "—" }
        let weight = WeightFormatter.string(set.weight, unit: unit, includeUnit: false)
        return "\(weight)×\(set.reps)"
    }

    /// Walks all completed sessions in chronological order up to and
    /// including this one, tracking the running record per stable
    /// exercise identity. Reps exercises track top weight; duration
    /// exercises track longest hold. Same semantics as the PR
    /// detection on the History list, scoped to one session.
    private var prExerciseIDs: Set<UUID> {
        var bestByExercise: [String: Double] = [:]
        var result: Set<UUID> = []

        let cutoff = session.completedAt ?? session.startedAt
        for s in allCompletedSessions {
            let sTime = s.completedAt ?? s.startedAt
            if sTime > cutoff { break }
            for exercise in s.orderedExercises {
                let metric = prMetric(for: exercise)
                guard metric > 0 else { continue }
                let key = exercise.historyKey
                let prev = bestByExercise[key, default: 0]
                if metric > prev {
                    bestByExercise[key] = metric
                    if s.id == session.id {
                        result.insert(exercise.id)
                    }
                }
            }
        }
        return result
    }

    private var sessionHasPR: Bool { !prExerciseIDs.isEmpty }

    private func prMetric(for exercise: Exercise) -> Double {
        let completed = exercise.sets.filter(\.isCompleted)
        switch exercise.trackingMode {
        case .reps:
            return completed.map(\.weight).max() ?? 0
        case .duration:
            return completed.map(\.duration).max() ?? 0
        }
    }
}

// MARK: - Per-exercise row

private struct ExerciseDetailRow: View {
    let exercise: Exercise
    let unit: WeightUnit
    let isPR: Bool
    var contribution: SessionContribution? = nil
    var adherence: ExerciseAdherence? = nil

    private var mode: TrackingMode { exercise.trackingMode }

    private var orderedSets: [WorkoutSet] { exercise.orderedSets }

    /// The exercise's standout completed set, singled out with the
    /// gold completion accent. Mode-aware: heaviest lift for reps
    /// (tiebreak on reps so 135×10 beats 135×8), longest hold for
    /// duration.
    private var topSet: WorkoutSet? {
        let completed = exercise.sets.filter(\.isCompleted)
        switch mode {
        case .reps:
            return completed.max { a, b in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            }
        case .duration:
            return completed.max { a, b in a.duration < b.duration }
        }
    }

    private var exerciseVolume: Double {
        exercise.sets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Total time held across completed sets — the `.duration`
    /// counterpart to `exerciseVolume`, shown in the row header.
    private var totalHold: TimeInterval {
        exercise.sets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            if let contribution, contribution.metric > 0 {
                WaterfallRow(share: contribution.share, isDuration: contribution.isDuration)
            }
            setsGrid
        }
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.group.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                Text(exercise.name)
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: Space.sm)

            VStack(alignment: .trailing, spacing: 4) {
                volumeCluster
                if let adherence, !adherence.isOnPlan {
                    AdherenceBadge(adherence: adherence, unit: unit)
                }
            }
        }
    }

    @ViewBuilder
    private var volumeCluster: some View {
        switch mode {
        case .reps:
            if exerciseVolume > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.volumeValue(exerciseVolume, unit: unit))
                        .font(Typography.metricInline)
                        .foregroundStyle(isPR ? Tint.complete : Ink.secondary)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        case .duration:
            if totalHold > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(DurationFormatter.compact(totalHold))
                        .font(Typography.metricInline)
                        .foregroundStyle(isPR ? Tint.complete : Ink.secondary)
                        .monospacedDigit()
                    Text("hold")
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
        VStack(spacing: Space.sm) {
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
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    /// The trailing metric cluster of a set row. Reps render as
    /// "135 lb × 8"; holds render as "0:45" — prefixed with the
    /// load ("25 lb · 0:45") only when the hold was weighted.
    @ViewBuilder
    private func setValue(set: WorkoutSet, textColor: Color) -> some View {
        switch mode {
        case .reps:
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(WeightFormatter.string(set.weight, unit: unit, includeUnit: false))
                    .font(Typography.metricInline)
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Ink.quaternary)
            }

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

        case .duration:
            if set.weight > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.string(set.weight, unit: unit, includeUnit: false))
                        .font(Typography.metricInline)
                        .foregroundStyle(textColor)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.quaternary)
                }
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
                .fill(isCompleted ? Tint.complete.opacity(isTopSet ? 1.0 : 0.85) : Color.clear)
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
