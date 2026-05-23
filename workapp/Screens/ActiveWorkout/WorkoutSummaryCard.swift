//
//  WorkoutSummaryCard.swift
//  workapp
//
//  The (N+1)th card in the ActiveWorkout SwipePager — a session
//  "receipt" you can swipe to any time, naturally arrived at after
//  the last exercise. Renders in two modes that share one layout:
//
//    • WORKOUT IN PROGRESS — shown if the user swipes here mid-
//      workout. Tallies reflect what's been done so far.
//    • WORKOUT COMPLETE    — shown once every set is logged.
//      Switches to green accent, fires success haptic on appear.
//
//  Hero stats (duration, total volume) count up from zero each time
//  the user lands on this card, using DigitTicker as the rolling
//  digit display. Per-exercise rows show muscle-group tag, name,
//  top set, and three completion dots.
//

import SwiftUI

struct WorkoutSummaryCard: View {
    @Bindable var session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Optional dismiss callback from the parent shell. When provided
    /// and the workout is complete, a DONE button appears at the
    /// bottom of the card — the natural finish action.
    var onDone: (() -> Void)? = nil

    /// Optional add-exercise callback. When provided (and the card
    /// isn't historical), an "Add Exercise" button renders above the
    /// Done button. Lets the user extend their workout off-plan
    /// without leaving the active screen.
    var onAddExercise: (() -> Void)? = nil

    /// When true, the card renders the session's real, final totals
    /// without the count-up animation or success haptic. Used by the
    /// History detail screen — reviewing a past workout shouldn't
    /// replay the celebration moment.
    var isHistorical: Bool = false

    // The count-up animation state lives on `session` (not @State here)
    // so it survives view remounts — e.g., when the user minimizes the
    // workout to the MiniBar and re-expands. Without that lift, the
    // summary card would replay the count from 0 on every re-entry.
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

    /// Minutes value shown in the hero stat. Historical sessions get
    /// the real value directly; in-flight sessions use the animated
    /// state that's driven by `playEntrance`.
    private var displayMinutes: Double {
        isHistorical ? session.duration / 60 : animatedMinutes
    }

    private var displayVolume: Double {
        isHistorical ? session.totalVolume : animatedVolume
    }

    private let completedGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)
    private let inProgressTint = Color(.sRGB, red: 0.42, green: 0.55, blue: 0.78, opacity: 1.0)

    private var isComplete: Bool { session.isAllComplete }
    private var accent: Color { isComplete ? completedGreen : inProgressTint }

    /// True when the notes editor sheet is up. State only — the
    /// edited text writes directly to `session.notes` on Save.
    @State private var isEditingWorkoutNotes: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBadges

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 14) {
                titleAndDate
                divider
                heroStats
                divider
            }

            Spacer(minLength: 16)

            exerciseList

            Spacer(minLength: 16)

            notesBlock

            VStack(alignment: .leading, spacing: 14) {
                divider
                footerStats
            }

            if !isHistorical, let onAddExercise {
                addExerciseButton(onAddExercise: onAddExercise)
                    .padding(.top, 18)
            }

            if isComplete, let onDone {
                doneButton(onDone: onDone)
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .onChange(of: session.activeExerciseIndex, initial: true) { _, newIndex in
            // Skip the count-up animation entirely for historical
            // sessions — `displayMinutes`/`displayVolume` already
            // return the real totals, no animation needed.
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

    // MARK: - Notes

    /// Per-workout notes block. Empty state shows a subtle inline
    /// "Add notes" affordance; populated state renders the text in a
    /// soft card the user can tap to edit. Same surface in both
    /// in-flight and historical modes.
    @ViewBuilder
    private var notesBlock: some View {
        if session.notes.isEmpty {
            Button {
                Haptics.soft()
                isEditingWorkoutNotes = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add notes")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                )
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        } else {
            Button {
                Haptics.soft()
                isEditingWorkoutNotes = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 10, weight: .semibold))
                        Text("NOTES")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.8)
                    }
                    .foregroundStyle(.white.opacity(0.45))

                    Text(session.notes)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Header pieces

    /// Tiny identifying badges at the very top of the card. Index on
    /// the left, completion-state label on the right. Stays anchored
    /// to the top so the card edge always identifies itself.
    private var topBadges: some View {
        HStack {
            Text(String(format: "%02d / %02d",
                        session.orderedExercises.count + 1,
                        session.orderedExercises.count + 1))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))

            Spacer()

            Text(isComplete ? "WORKOUT COMPLETE" : "WORKOUT IN PROGRESS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(accent)
        }
    }

    /// Title and date — pulled down to sit with the hero stats block
    /// so they read as a sub-header for the big numbers rather than
    /// floating alone at the top of the card.
    private var titleAndDate: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleString)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text(dateString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    // MARK: - Hero stats

    private var heroStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                DigitTicker(
                    value: displayMinutes,
                    font: .system(size: 24, weight: .bold, design: .rounded),
                    color: .white,
                    fractionalDigits: 0
                )
                Text("min")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Text("DURATION")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.40))
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                DigitTicker(
                    value: WeightFormatter.toDisplay(displayVolume, unit: unit),
                    font: .system(size: 56, weight: .bold, design: .rounded),
                    color: .white,
                    formatter: { value in
                        Self.volumeFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
                    }
                )
                Text(unit.symbol)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 4)

                Spacer()
            }

            Text("TOTAL VOLUME")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.40))
        }
    }

    // MARK: - Exercise list

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(session.orderedExercises) { exercise in
                exerciseRow(for: exercise)
            }
        }
    }

    private func exerciseRow(for exercise: Exercise) -> some View {
        let exerciseSets = exercise.orderedSets
        let completedCount = exerciseSets.filter(\.isCompleted).count
        let totalCount = exerciseSets.count
        let top = session.topSet(for: exercise)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.group.displayName.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(exercise.group.accent)
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                if let top {
                    Text("\(WeightFormatter.string(top.weight, unit: unit, includeUnit: false)) × \(top.reps)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                } else {
                    Text("—")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.30))
                }

                HStack(spacing: 4) {
                    ForEach(0..<totalCount, id: \.self) { i in
                        Circle()
                            .fill(i < completedCount ? completedGreen : Color.white.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.leading, 4)
            }

            if !exercise.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 2)
                    Text(exercise.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 2)
            }
        }
    }

    // MARK: - Footer

    private var footerStats: some View {
        HStack {
            Spacer()

            HStack(spacing: 22) {
                stat(value: session.totalSets, of: session.totalPlannedSets, label: "SETS")
                statDivider
                stat(value: session.totalReps, label: "REPS")
            }

            Spacer()
        }
    }

    private func stat(value: Int, of total: Int? = nil, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if let total, total != value {
                    Text("/ \(total)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.40))
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 0.5, height: 28)
    }

    // MARK: - Done

    /// Lets the user extend the session off-plan. Dark capsule so it
    /// reads as a secondary affordance — Done (when shown) keeps the
    /// dominant visual weight.
    private func addExerciseButton(onAddExercise: @escaping () -> Void) -> some View {
        Button {
            Haptics.soft()
            onAddExercise()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add another exercise")
    }

    /// The "you're finished, return to home" action. Only renders
    /// when the workout is complete AND the parent supplied a dismiss
    /// callback. Styled flatter than PrimaryActionButton so it reads
    /// as a quiet finish, not a competing celebration.
    private func doneButton(onDone: @escaping () -> Void) -> some View {
        Button {
            Haptics.thunk()
            onDone()
        } label: {
            Text("DONE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(completedGreen)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish workout and return to home")
    }

    // MARK: - Misc bits

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }

    private var cardBackground: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10)
            LinearGradient(
                colors: [
                    accent.opacity(isComplete ? 0.26 : 0.20),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }

    // MARK: - Derived strings

    private var titleString: String {
        isComplete ? "Today's Session" : "In Progress"
    }

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

        // Threshold below which we treat the value as "unchanged" and
        // skip animating that field. Half a minute / half a pound is
        // imperceptible to the user and would only register as a blip.
        let minChanged = abs(targetMin - fromMin) >= 0.5
        let volChanged = abs(targetVol - fromVol) >= 0.5

        // Nothing meaningful changed since the last visit. Bail before
        // spawning a Task or sleeping — the displayed values are already
        // correct.
        if !minChanged && !volChanged { return }

        // First visit gets the dramatic reveal beat; later visits get a
        // quicker delta-update so they read as "refresh," not "replay."
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

            // Fire success haptic only the first time we land on a
            // completed workout — celebrating the result, not the
            // navigation.
            if isComplete && !didCelebrate {
                Haptics.success()
                didCelebrate = true
            }
        }
    }

    /// Manual count-up using a frame loop. Avoids SwiftUI's lack of
    /// native interpolation for plain `Double` state, while letting
    /// DigitTicker render each intermediate value with proper
    /// per-digit transitions.
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
    return WorkoutSummaryCard(session: session)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}

#Preview("Summary · in progress") {
    let session = WorkoutSession.sample
    // Mark a couple of sets done so totals are non-zero.
    if let first = session.orderedExercises.first {
        let setsInOrder = first.orderedSets
        if setsInOrder.count >= 2 {
            setsInOrder[0].isCompleted = true
            setsInOrder[1].isCompleted = true
        }
    }
    session.activeExerciseIndex = session.orderedExercises.count
    return WorkoutSummaryCard(session: session)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
