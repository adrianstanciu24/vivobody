//
//  WorkoutSummaryCard.swift
//  vivobody
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
    /// Card corner radius. Hoisted to a constant so the clip,
    /// bevel, and sheen stay in lockstep.
    private static let cardCornerRadius: CGFloat = 28

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

    private let completedGreen = Tint.success
    private let inProgressTint = Tint.primary

    private var isComplete: Bool { session.isAllComplete }
    private var accent: Color { isComplete ? completedGreen : inProgressTint }

    /// True when the notes editor sheet is up. State only — the
    /// edited text writes directly to `session.notes` on Save.
    @State private var isEditingWorkoutNotes: Bool = false

    var body: some View {
        // Layout contract:
        //   • Content (title, stats, exercises, notes) anchors to
        //     the top of the card.
        //   • Action bar (Add Exercise / Done) anchors to the
        //     bottom of the card.
        //   • A flexible Spacer between them claims any remaining
        //     space when the workout is short — no dead band of
        //     empty card surface above the buttons.
        //   • When the workout is long enough that content +
        //     action bar exceed the card height, the Spacer
        //     collapses to 0 and the whole stack scrolls.
        //
        // `minHeight: geo.size.height` on the inner VStack is what
        // makes the Spacer behave: it sets the natural height to
        // exactly the visible card height, so the Spacer fills the
        // gap; when content forces the stack taller, the minHeight
        // becomes irrelevant and the ScrollView takes over.
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    titleAndDate
                    statStrip
                    exerciseList
                    quietNotesBlock
                    Spacer(minLength: 12)
                    actionBar
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
        .topSpecularSheen(cornerRadius: Self.cardCornerRadius, intensity: 0.10, height: 0.42)
        .glassRimBevel(cornerRadius: Self.cardCornerRadius, outerWidth: 0.7, innerInset: 1.2)
        .shadow(color: accent.opacity(0.38), radius: 28, y: 12)
        .shadow(color: .black.opacity(0.55), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
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

    // MARK: - Quiet notes

    /// One-line "Add notes" link when empty; soft glass card with
    /// the notes text when populated. Demoted from the previous
    /// dashed-border full-width box — that read as a primary CTA
    /// in a card whose primary CTAs (Add Exercise / Done) already
    /// live in the pinned action bar.
    @ViewBuilder
    private var quietNotesBlock: some View {
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
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.soft()
                isEditingWorkoutNotes = true
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Notes")
                            .font(Typography.sectionLabel)
                    }
                    .foregroundStyle(.white.opacity(0.55))

                    Text(session.notes)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .glassChip(cornerRadius: 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Header pieces

    /// Title block. Date is suppressed for in-flight sessions
    /// (the user knows it's today) and kept only when the card is
    /// viewed historically, where the date is the primary identity.
    private var titleAndDate: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleString)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            if isHistorical {
                Text(dateString)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Stat grid

    /// 2x2 stat grid — Duration / Volume on the top row, Sets /
    /// Reps on the bottom. Two columns per row instead of four
    /// gives the Volume cell enough horizontal room for big
    /// comma-grouped numbers (e.g. "14,145 lb") without crushing
    /// neighbours. Each cell takes half the row so the layout is
    /// stable regardless of digit count.
    private var statStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                statCell(label: "Duration") {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        DigitTicker(
                            value: displayMinutes,
                            font: Self.statValueFont,
                            color: .white,
                            fractionalDigits: 0
                        )
                        Text("min")
                            .font(Typography.metricUnit)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
                statCell(label: "Volume") {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        DigitTicker(
                            value: WeightFormatter.toDisplay(displayVolume, unit: unit),
                            font: Self.statValueFont,
                            color: .white,
                            formatter: { value in
                                Self.volumeFormatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
                            }
                        )
                        Text(unit.symbol)
                            .font(Typography.metricUnit)
                            .foregroundStyle(.white.opacity(0.50))
                    }
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                statCell(label: "Sets") {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(session.totalSets)")
                            .font(Self.statValueFont)
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        if session.totalPlannedSets != session.totalSets {
                            Text("/ \(session.totalPlannedSets)")
                                .font(Typography.metricUnit)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                statCell(label: "Reps") {
                    Text("\(session.totalReps)")
                        .font(Self.statValueFont)
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
        }
    }

    private static let statValueFont = Font.system(size: 28, weight: .bold, design: .rounded)

    @ViewBuilder
    private func statCell<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            value()
            Text(label)
                .sectionLabelStyle(0.45)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    HStack(spacing: 5) {
                        Circle()
                            .fill(exercise.group.accent)
                            .frame(width: 6, height: 6)
                        Text(exercise.group.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(exercise.group.accent)
                    }
                    Text(exercise.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                if let top {
                    Text("\(WeightFormatter.string(top.weight, unit: unit, includeUnit: false)) × \(top.reps)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text("—")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.top, 3)
                    Text(exercise.notes)
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, 2)
            }
        }
    }

    // MARK: - Action bar

    /// Pinned bottom action region. Add Exercise (when supported)
    /// sits above Done (when shown). Both stay reachable regardless
    /// of how far the user has scrolled the content above.
    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 10) {
            if !isHistorical, let onAddExercise {
                addExerciseButton(onAddExercise: onAddExercise)
            }
            if isComplete, let onDone {
                doneButton(onDone: onDone)
            }
        }
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
            .glassChip(cornerRadius: 14)
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
            Text("Done")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(completedGreen)
                )
                .primaryGlow(completedGreen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Finish workout and return to home")
    }

    // MARK: - Misc bits

    private var cardBackground: some View {
        ZStack {
            // Slightly cooler black at the bottom, warmer near the
            // top — gives the card body a vertical gradient that
            // reads as a curved glass surface instead of a flat fill.
            LinearGradient(
                colors: [
                    Color(red: 0.085, green: 0.080, blue: 0.090),
                    Color(red: 0.045, green: 0.045, blue: 0.055)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Hot quadrant — ambient light source.
            RadialGradient(
                colors: [
                    accent.opacity(isComplete ? 0.28 : 0.22),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )

            // Diagonal counter-glow.
            RadialGradient(
                colors: [
                    accent.opacity(0.12),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: 320
            )

            // Bottom inner darkening — the rim recedes into shadow,
            // pairing with the bright top sheen overlay.
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
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
