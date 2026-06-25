//
//  WorkoutSummaryCard.swift
//  vivobody
//
//  The (N+1)th page in the ActiveWorkout SwipePager — the session
//  "receipt," reached by swiping past the last exercise. Built in the
//  same instrument language as the exercise pages: full-bleed on
//  black, no card, type and whitespace doing the work.
//
//  Architecture:
//    • A tiny status kicker — "In progress" (Volt) / "Complete" (gold).
//    • The HERO: total volume as a huge monospaced numeral — the
//      session's score — counting up on arrival via DigitTicker.
//    • A small mono support line for the rest (duration, sets, reps).
//    • The exercise list as type rows divided by hairlines, each with
//      its top set and the same gold/dim set pips used on the pages.
//    • Words for verbs: "Notes", "Add exercise", and a gold "Done"
//      verb button (finishing the session is a completion).
//
//  Two modes share the layout: in-progress (swiped here mid-workout)
//  and complete (every set logged → Done appears, success haptic).
//

import SwiftUI

struct WorkoutSummaryCard: View {
    @Bindable var session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Optional dismiss callback from the parent shell. When provided
    /// and the workout is complete, the gold Done verb appears.
    var onDone: (() -> Void)? = nil

    /// Optional add-exercise callback. When provided (and not
    /// historical), an "Add exercise" word-button renders above Done.
    var onAddExercise: (() -> Void)? = nil

    /// When true, renders the real final totals without the count-up
    /// or success haptic. Reserved for non-celebratory review.
    var isHistorical: Bool = false

    // Count-up state lives on `session` (not @State) so it survives
    // view remounts — e.g. minimizing to the MiniBar and re-expanding.
    private var animatedMinutes: Double {
        get { session.summaryAnimatedMinutes }
        nonmutating set { session.summaryAnimatedMinutes = newValue }
    }
    private var animatedVolume: Double {
        get { session.summaryAnimatedVolume }
        nonmutating set { session.summaryAnimatedVolume = newValue }
    }
    private var didCelebrate: Bool {
        get { session.summaryDidCelebrate }
        nonmutating set { session.summaryDidCelebrate = newValue }
    }

    private var displayMinutes: Double {
        isHistorical ? session.duration / 60 : animatedMinutes
    }

    private var displayVolume: Double {
        isHistorical ? session.totalVolume : animatedVolume
    }

    private var isComplete: Bool { session.isAllComplete }

    @State private var isEditingWorkoutNotes: Bool = false

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    statusKicker
                        .padding(.top, Space.xs)

                    heroVolume
                        .padding(.top, Space.xl)

                    supportLine
                        .padding(.top, Space.sm)

                    if SessionIntensityLine.hasContent(session) {
                        SessionIntensityLine(session: session, unit: unit)
                            .padding(.top, Space.xs)
                    }

                    exerciseList
                        .padding(.top, Space.xl + Space.sm)

                    notesBlock
                        .padding(.top, Space.lg)

                    Spacer(minLength: Space.xl)

                    actionArea
                        .padding(.top, Space.xl)
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: session.activeExerciseIndex, initial: true) { _, newIndex in
            if !isHistorical && newIndex == session.orderedExercises.count {
                playEntrance()
            }
        }
        .sheet(isPresented: $isEditingWorkoutNotes) {
            NotesEditorSheet(
                title: "Workout Notes",
                placeholder: "How did today feel? Anything to remember next time?",
                initialValue: session.notes,
                onSave: { newNotes in session.notes = newNotes }
            )
        }
    }

    // MARK: - Status + hero

    private var statusKicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isComplete ? "Complete" : "In progress")
                .font(Typography.sectionLabel)
                .foregroundStyle(isComplete ? Tint.complete : Tint.inProgress)
            if isHistorical {
                Text(dateString)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private var heroVolume: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                DigitTicker(
                    value: WeightFormatter.toDisplay(displayVolume, unit: unit),
                    font: Typography.metricHero,
                    color: Ink.primary,
                    formatter: { value in
                        Self.volumeFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
                    }
                )
                Text(unit.symbol)
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.tertiary)
            }
            Text("Volume")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
        }
    }

    private var supportLine: some View {
        Text(supportText)
            .font(Typography.metricUnit)
            .foregroundStyle(Ink.tertiary)
    }

    private var supportText: String {
        let mins = Int(displayMinutes.rounded())
        let setsPart = session.totalPlannedSets != session.totalSets
            ? "\(session.totalSets) of \(session.totalPlannedSets) sets"
            : "\(session.totalSets) sets"
        var parts = ["\(mins) min", setsPart]
        if session.totalReps > 0 {
            parts.append("\(session.totalReps) reps")
        }
        if session.totalHoldTime > 0 {
            parts.append("\(DurationFormatter.compact(session.totalHoldTime)) held")
        }
        return parts.joined(separator: "   ·   ")
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        let breakdown = session.contributions()
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(session.orderedExercises.enumerated()), id: \.element.id) { idx, exercise in
                if idx > 0 {
                    Rectangle()
                        .fill(Surface.edge)
                        .frame(height: 1)
                }
                exerciseRow(for: exercise, contribution: breakdown[exercise.id])
            }
        }
    }

    private func exerciseRow(for exercise: Exercise, contribution: SessionContribution?) -> some View {
        let exerciseSets = exercise.orderedSets
        let topLabel = session.topSetLabel(for: exercise, unit: unit)
        let adherence = session.adherence(for: exercise)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: Space.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.group.displayName)
                        .font(Typography.caption)
                        .foregroundStyle(Ink.tertiary)
                    Text(exercise.name)
                        .font(Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: Space.sm)

                VStack(alignment: .trailing, spacing: 3) {
                    if let topLabel {
                        Text(topLabel)
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                    } else {
                        Text("—")
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.quaternary)
                    }
                    if let adherence, !adherence.isOnPlan {
                        AdherenceBadge(adherence: adherence, unit: unit)
                    }
                }

                summaryPips(for: exerciseSets)
            }

            if let contribution, contribution.metric > 0 {
                WaterfallRow(share: contribution.share, isDuration: contribution.isDuration)
            }

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, Space.md)
    }

    private func summaryPips(for sets: [WorkoutSet]) -> some View {
        HStack(spacing: 6) {
            ForEach(sets) { set in
                if set.isCompleted {
                    Circle()
                        .fill(Tint.complete)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .strokeBorder(Ink.quaternary, lineWidth: 1.5)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Notes (word, not icon)

    @ViewBuilder
    private var notesBlock: some View {
        if session.notes.isEmpty {
            Button {
                Haptics.soft()
                isEditingWorkoutNotes = true
            } label: {
                Text("Notes")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                    .frame(minHeight: 44, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.soft()
                isEditingWorkoutNotes = true
            } label: {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: Space.md) {
            if !isHistorical, let onAddExercise {
                addExerciseButton(onAddExercise: onAddExercise)
            }
            if isComplete, let onDone {
                doneButton(onDone: onDone)
            }
        }
    }

    private func addExerciseButton(onAddExercise: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            onAddExercise()
        } label: {
            Text("Add exercise")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Surface.edgeBright, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add another exercise")
    }

    /// The finish action — completing the whole session, so it wears
    /// the completion accent (gold) and the same verb shape as the
    /// per-set button.
    private func doneButton(onDone: @escaping () -> Void) -> some View {
        Button {
            Haptics.thunk()
            onDone()
        } label: {
            HStack(alignment: .center, spacing: 0) {
                Text("Done")
                    .font(Typography.title)
                    .tracking(0.4)
                    .foregroundStyle(Tint.onAccent)
                Spacer(minLength: 8)
                Image(systemName: "checkmark")
                    .font(Typography.headline)
                    .foregroundStyle(Tint.onAccent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .coloredGlassControl(cornerRadius: Radius.card, fill: Tint.complete, interactive: true)
            .shadow(color: Tint.complete.opacity(0.40), radius: 22, y: 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish workout and return to home")
    }

    // MARK: - Derived strings

    private var dateString: String {
        let date = session.completedAt ?? session.startedAt
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE  ·  MMM d  ·  h:mm a"
        return f
    }()

    private static let volumeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()

    // MARK: - Entrance animation

    private func playEntrance() {
        let fromMin = animatedMinutes
        let fromVol = animatedVolume
        let targetMin = session.duration / 60
        let targetVol = session.totalVolume

        let minChanged = abs(targetMin - fromMin) >= 0.5
        let volChanged = abs(targetVol - fromVol) >= 0.5

        if !minChanged && !volChanged { return }

        let isFirstVisit = fromMin == 0 && fromVol == 0
        let minDuration = isFirstVisit ? 0.9 : 0.5
        let volDuration = isFirstVisit ? 1.6 : 0.7

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))

            if minChanged {
                await countUp(
                    from: fromMin,
                    to: targetMin,
                    duration: minDuration,
                    set: { animatedMinutes = $0 }
                )
            }

            if volChanged {
                await countUp(
                    from: fromVol,
                    to: targetVol,
                    duration: volDuration,
                    set: { animatedVolume = $0 }
                )
            }

            if isComplete && !didCelebrate {
                Haptics.success()
                didCelebrate = true
            }
        }
    }

    private func countUp(
        from start: Double,
        to target: Double,
        duration: Double,
        set: @escaping (Double) -> Void
    ) async {
        let frameRate: Double = 60
        let steps = max(1, Int(duration * frameRate))
        let stepNs = UInt64(1_000_000_000.0 / frameRate)
        let delta = target - start

        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let eased = 1 - pow(1 - t, 3) // ease-out cubic
            set(start + delta * eased)
            try? await Task.sleep(nanoseconds: stepNs)
        }
        set(target)
    }
}

#Preview("Summary · complete") {
    let session = WorkoutSession.sampleCompleted
    session.activeExerciseIndex = session.orderedExercises.count
    return WorkoutSummaryCard(session: session, onDone: {}, onAddExercise: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}

#Preview("Summary · in progress") {
    let session = WorkoutSession.sample
    if let first = session.orderedExercises.first {
        let setsInOrder = first.orderedSets
        if setsInOrder.count >= 2 {
            setsInOrder[0].isCompleted = true
            setsInOrder[1].isCompleted = true
        }
    }
    session.activeExerciseIndex = session.orderedExercises.count
    return WorkoutSummaryCard(session: session, onAddExercise: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
