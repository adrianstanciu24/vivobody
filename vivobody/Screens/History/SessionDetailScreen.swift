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
//    • Notes — session-level notes surface as plain type at the end.
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

    private static let volumeHero = Font.system(size: 72, weight: .bold, design: .monospaced)
    private static let monoStat = Font.system(size: 22, weight: .bold, design: .monospaced)

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
                    valueFont: Self.monoStat
                )
                .padding(.top, Space.xl)

                SectionDivider()
                    .padding(.top, Space.xl)

                exercisesSection
                    .padding(.top, Space.lg)

                if !session.notes.isEmpty {
                    notesSection
                        .padding(.top, Space.xl)
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kicker + hero

    private var kicker: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(dateLine)
                .sectionLabelStyle(0.45)
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
                    .font(Self.volumeHero)
                    .foregroundStyle(sessionHasPR ? Tint.complete : Ink.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit.symbol)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Ink.tertiary)
            }
            Text(sessionHasPR ? "Volume · personal record" : "Volume")
                .font(Typography.sectionLabel)
                .foregroundStyle(sessionHasPR ? Tint.complete : Ink.tertiary)
        }
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: "Exercises", trailing: exercisesSubtitle)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(session.orderedExercises.enumerated()), id: \.element.id) { idx, exercise in
                    if idx > 0 { SectionDivider() }
                    ExerciseDetailRow(
                        exercise: exercise,
                        unit: unit,
                        isPR: prExerciseIDs.contains(exercise.id)
                    )
                }
            }
        }
    }

    private var exercisesSubtitle: String {
        let n = session.orderedExercises.count
        return n == 1 ? "1 exercise" : "\(n) exercises"
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            Text(session.notes)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    /// including this one, tracking the running max weight per
    /// exercise name. Any exercise in *this* session that crossed
    /// its running max at the moment it was logged is flagged as a
    /// PR. Same semantics as the PR detection on the History list,
    /// scoped to one session.
    private var prExerciseIDs: Set<UUID> {
        var bestByName: [String: Double] = [:]
        var result: Set<UUID> = []

        let cutoff = session.completedAt ?? session.startedAt
        for s in allCompletedSessions {
            let sTime = s.completedAt ?? s.startedAt
            if sTime > cutoff { break }
            for exercise in s.orderedExercises {
                let topWeight = exercise.sets.filter(\.isCompleted).map(\.weight).max() ?? 0
                guard topWeight > 0 else { continue }
                let key = exercise.name.lowercased()
                let prev = bestByName[key, default: 0]
                if topWeight > prev {
                    bestByName[key] = topWeight
                    if s.id == session.id {
                        result.insert(exercise.id)
                    }
                }
            }
        }
        return result
    }

    private var sessionHasPR: Bool { !prExerciseIDs.isEmpty }
}

// MARK: - Per-exercise row

private struct ExerciseDetailRow: View {
    let exercise: Exercise
    let unit: WeightUnit
    let isPR: Bool

    private var orderedSets: [WorkoutSet] { exercise.orderedSets }

    /// Heaviest completed set in this exercise, singled out with the
    /// gold completion accent. Tiebreak on reps so 135×10 beats 135×8.
    private var topSet: WorkoutSet? {
        exercise.sets
            .filter(\.isCompleted)
            .max(by: { (a, b) in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            })
    }

    private var exerciseVolume: Double {
        exercise.sets
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            header
            setsGrid
            if !exercise.notes.isEmpty {
                exerciseNotes
            }
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

            if exerciseVolume > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(WeightFormatter.volumeValue(exerciseVolume, unit: unit))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(isPR ? Tint.complete : Ink.secondary)
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
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
            HStack(spacing: 10) {
                statusPip(isCompleted: set.isCompleted, isTopSet: isTopSet)
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(set.isCompleted ? Ink.tertiary : Ink.quaternary)
                    .frame(width: 16, alignment: .leading)
            }

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(WeightFormatter.string(set.weight, unit: unit, includeUnit: false))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.quaternary)
            }

            Text("×")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Ink.quaternary)
                .padding(.horizontal, 10)

            Text("\(set.reps)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(textColor)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
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

    private var exerciseNotes: some View {
        Text(exercise.notes)
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
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
