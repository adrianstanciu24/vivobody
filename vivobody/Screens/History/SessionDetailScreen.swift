//
//  SessionDetailScreen.swift
//  vivobody
//
//  The view a history row pushes into. Speaks the same Liquid Glass
//  / journal vocabulary as the History list — restraint, monospaced
//  caps for metadata, carved-glass numerals as the heroes, no orbs
//  or celebration chrome. Reading a past workout shouldn't feel like
//  reopening the active session; it should feel like flipping back
//  to a journal entry.
//
//  Layout, top to bottom:
//
//    • Hero card — date caps line + derived workout title (e.g.
//      "Push day") + the session's total volume rendered as
//      CarvedVolumeText at hero size. Muscle strip below as small
//      monospaced labels with accent dashes. PR gold underline
//      beneath the volume if any exercise in this session set an
//      all-time top weight at the moment it was logged.
//
//    • Stat strip — four columns inside a quiet glass card:
//      Duration / Sets / Reps / Top set. Same hairline divider
//      treatment as WeeklyHeroCard.
//
//    • Exercise breakdown — one card per exercise. Header carries
//      the muscle group dot + name and the per-exercise carved
//      volume on the right. A hairline divider, then a set grid:
//      `1   135 × 8` rows in tabular monospaced figures, with the
//      top set rendered in success green and any incomplete sets
//      dimmed. Per-exercise notes appended as a quiet caption.
//
//    • Notes block — if the session has workout-level notes, they
//      surface in a glass chip at the bottom labelled "Notes".
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
            VStack(alignment: .leading, spacing: 24) {
                heroCard
                statStrip
                exercisesSection
                if !session.notes.isEmpty {
                    notesSection
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(dateCapsLine)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.2)
                .textCase(.uppercase)

            Text(workoutTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(2)

            HStack(alignment: .lastTextBaseline) {
                Spacer(minLength: 0)
                CarvedVolumeText(
                    value: WeightFormatter.volumeValue(session.totalVolume, unit: unit),
                    unit: unit.symbol,
                    size: 56,
                    isPR: sessionHasPR
                )
            }
            .padding(.top, 2)

            if !muscleTags.isEmpty {
                Divider().background(Color.white.opacity(0.06))
                muscleStrip
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .topSpecularSheen(cornerRadius: 24, intensity: 0.10, height: 0.40)
        .glassRimBevel(cornerRadius: 24, outerWidth: 0.7, innerInset: 1.2)
        .shadow(color: .black.opacity(0.40), radius: 14, y: 8)
    }

    private var muscleStrip: some View {
        HStack(spacing: 14) {
            ForEach(muscleTags, id: \.self) { group in
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(group.accent.opacity(0.85))
                        .frame(width: 8, height: 2)
                    Text(group.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.70))
                        .tracking(0.8)
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Stat strip

    /// Four-column metric row inside a quiet glass card. Layout
    /// borrows the WeeklyHeroCard's column + hairline divider
    /// rhythm so the page reads as one continuous Liquid Glass
    /// vocabulary rather than a new pattern per screen.
    private var statStrip: some View {
        HStack(spacing: 0) {
            statCell(value: "\(durationMinutes)", unit: "min", label: "Duration")
            statDivider
            statCell(value: "\(session.totalSets)", unit: nil, label: "Sets")
            statDivider
            statCell(value: "\(session.totalReps)", unit: nil, label: "Reps")
            statDivider
            statCell(value: topSetValue.value, unit: topSetValue.unit, label: "Top set")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 20)
        .glassRimBevel(cornerRadius: 20, outerWidth: 0.5, innerInset: 1.0)
    }

    private func statCell(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.50))
                .tracking(0.9)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 30)
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercises".uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(0.6)
                Spacer()
                Text(exercisesSubtitle)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(session.orderedExercises) { exercise in
                    ExerciseDetailCard(
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes".uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(0.6)
                .padding(.horizontal, 4)

            Text(session.notes)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassChip(cornerRadius: 16)
        }
    }

    // MARK: - Derived

    private var muscleTags: [MuscleGroup] { session.distinctMuscleGroupsInOrder }

    /// Same derivation HistoryScreen uses for its row title — keeps
    /// the journal's voice consistent between the list and the
    /// detail.
    private var workoutTitle: String {
        switch muscleTags.count {
        case 0: return "Workout"
        case 1: return "\(muscleTags[0].displayName) day"
        case 2: return "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: return "Full body"
        }
    }

    private var dateCapsLine: String {
        let date = session.completedAt ?? session.startedAt
        return SessionDetailFormatters.dateCaps.string(from: date)
    }

    private var durationMinutes: Int {
        max(0, Int(session.duration / 60))
    }

    /// Heaviest weight × reps logged across the entire session,
    /// rendered as "135×8" with the user's unit. Falls back to "—"
    /// when no sets are completed.
    private var topSetValue: (value: String, unit: String?) {
        let heaviest = session.exercises
            .flatMap(\.sets)
            .filter(\.isCompleted)
            .max(by: { (a, b) in
                if a.weight == b.weight { return a.reps < b.reps }
                return a.weight < b.weight
            })

        guard let set = heaviest else { return ("—", nil) }
        let weight = WeightFormatter.string(set.weight, unit: unit, includeUnit: false)
        return ("\(weight)×\(set.reps)", unit.symbol)
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

// MARK: - Per-exercise card

private struct ExerciseDetailCard: View {
    let exercise: Exercise
    let unit: WeightUnit
    let isPR: Bool

    private static let cornerRadius: CGFloat = 18

    private var orderedSets: [WorkoutSet] { exercise.orderedSets }

    /// Heaviest completed set in this exercise, used to single out
    /// the row as the top set with success-green numerals. Tiebreak
    /// on reps so 135×10 beats 135×8.
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
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider().background(Color.white.opacity(0.06))

            setsGrid

            if !exercise.notes.isEmpty {
                exerciseNotes
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: Self.cornerRadius)
        .glassRimBevel(cornerRadius: Self.cornerRadius, outerWidth: 0.5, innerInset: 1.0)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(exercise.group.accent)
                        .frame(width: 6, height: 6)
                    Text(exercise.group.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(exercise.group.accent.opacity(0.95))
                        .tracking(0.9)
                }
                Text(exercise.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if exerciseVolume > 0 {
                CarvedVolumeText(
                    value: WeightFormatter.volumeValue(exerciseVolume, unit: unit),
                    unit: unit.symbol,
                    size: 22,
                    isPR: isPR
                )
            }
        }
    }

    /// Sets table. Each row is a thin 3-column line: index, weight,
    /// reps. The top set's numerals render in `Tint.success` —
    /// typographic accent, no badge. Incomplete sets dim to ~30%
    /// opacity, with a hollow status pip in place of the filled
    /// dot so the difference between "lifted" and "planned but
    /// skipped" stays visible at a glance.
    private var setsGrid: some View {
        VStack(spacing: 6) {
            ForEach(Array(orderedSets.enumerated()), id: \.element.id) { idx, set in
                setRow(index: idx + 1, set: set)
            }
        }
    }

    private func setRow(index: Int, set: WorkoutSet) -> some View {
        let isTopSet = set === topSet
        let textColor: Color = {
            if isTopSet { return Tint.success }
            return .white.opacity(set.isCompleted ? 0.85 : 0.30)
        }()
        let unitColor: Color = .white.opacity(set.isCompleted ? 0.45 : 0.20)

        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                statusPip(isCompleted: set.isCompleted, isTopSet: isTopSet)
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(set.isCompleted ? 0.45 : 0.25))
                    .tracking(0.4)
                    .frame(width: 14, alignment: .leading)
            }

            Spacer(minLength: 12)

            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(WeightFormatter.string(set.weight, unit: unit, includeUnit: false))
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textColor)
                    .monospacedDigit()
                Text(unit.symbol)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(unitColor)
            }

            Text("×")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(set.isCompleted ? 0.25 : 0.15))
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
                .fill(isCompleted ? Tint.success.opacity(isTopSet ? 1.0 : 0.85) : Color.clear)
                .frame(width: 8, height: 8)
            Circle()
                .stroke(
                    isCompleted ? Color.clear : Color.white.opacity(0.18),
                    lineWidth: 1
                )
                .frame(width: 8, height: 8)
        }
    }

    private var exerciseNotes: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.40))
                .padding(.top, 3)
            Text(exercise.notes)
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
    }
}

// MARK: - Formatters

private enum SessionDetailFormatters {
    static let dateCaps: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE · MMM d · h:mm a"
        return f
    }()
}

#Preview {
    NavigationStack {
        SessionDetailScreen(session: WorkoutSession.sampleCompleted)
    }
    .preferredColorScheme(.dark)
}
