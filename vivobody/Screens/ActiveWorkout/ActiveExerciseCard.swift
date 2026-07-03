//
//  ActiveExerciseCard.swift
//  vivobody
//
//  One page in the SwipePager — but no longer a "card." This is the
//  instrument: a single exercise, full-bleed on black, built to be
//  read from arm's length in half a second.
//
//  First-principles layout (top → bottom):
//    • Set N of M (tiny — context, not chrome).
//    • Exercise name (the page's identity).
//    • Set pips — done / active / pending, glanceable at a flick.
//    • The HERO: the working weight as a huge monospaced odometer
//      you scrub with a vertical drag, with reps beneath it. The
//      numbers are the interface; there is no chip around them.
//    • A tiny "Last 135 × 8" line (long-press to edit/delete).
//    • The single biggest target on screen: a full-width verb
//      button — "Complete set" / "Finish exercise."
//
//  Two accents, per the product principles: Volt for in-progress
//  (the live action), gold for complete (a finished set, exercise,
//  or PR). They never read alike.
//
//  The card never owns workout state — every mutation goes through
//  the WorkoutSession passed in by the parent screen. The completion
//  "moment" (ripple, checkmark draw-on, haptic crescendo, auto-
//  advance) is untouched; only the surface around it changed.
//

import SwiftUI
import SwiftData

struct ActiveExerciseCard: View {
    let exercise: Exercise
    @Bindable var session: WorkoutSession

    /// SwiftData write context — used to query archived sessions
    /// when checking whether a just-completed set beats every prior
    /// recorded set for this exercise (i.e., is a personal record).
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Holds the ID of the set whose completion animation is still
    /// playing. While set, the SetCompleteButton renders as complete
    /// even though the session hasn't advanced yet.
    @State private var pendingCompletionSetID: UUID? = nil

    /// Cancellable owner of the PR-detect + auto-advance pipeline so
    /// a re-toggle or card disappearance can abort an in-flight run.
    @State private var completionTask: Task<Void, Never>? = nil

    /// When non-nil, presents the EditSetSheet for that completed
    /// set. Driven by the last-set caption's long-press menu.
    @State private var editingSet: WorkoutSet? = nil

    /// When non-nil, the destructive-confirmation alert is shown for
    /// that completed set.
    @State private var deletingSet: WorkoutSet? = nil

    /// Surfaces failures from saving the active workout draft.
    @State private var saveError: SaveErrorBox? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topMeta

            Spacer(minLength: Space.lg)

            nameRow
            setPips
                .padding(.top, Space.md)

            Spacer(minLength: Space.xl)

            heroBlock

            Spacer(minLength: Space.xl)

            rirControl
            lastSetCaption
            actionArea
                .padding(.top, Space.md)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .sheet(item: $editingSet) { set in
            EditSetSheet(set: set)
        }
        .alert(
            "Delete this set?",
            isPresented: deleteAlertBinding,
            presenting: deletingSet
        ) { setToDelete in
            Button("Delete", role: .destructive) {
                deleteSet(setToDelete)
            }
            Button("Cancel", role: .cancel) { }
        } message: { setToDelete in
            Text("\(WeightFormatter.string(setToDelete.weight, unit: unit)) · \(setToDelete.reps) reps. This can't be undone.")
        }
        .saveErrorAlert($saveError)
    }

    // MARK: - Top meta

    private var topMeta: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(setCountLabel)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            Spacer()
        }
        .padding(.top, Space.xs)
    }

    private var setCountLabel: String {
        if let active = activeIndex {
            return "Set \(active + 1) of \(sets.count)"
        }
        return "All sets complete"
    }

    // MARK: - Name + pips

    private var nameRow: some View {
        Text(exercise.name)
            .font(Typography.display)
            .foregroundStyle(Ink.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var setPips: some View {
        HStack(spacing: Space.md) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { idx, set in
                let pipView = pip(isCompleted: set.isCompleted, isActive: idx == activeIndex)
                // Skip the menu on a lone pending set — there'd be
                // nothing to offer (can't remove the last set, nothing
                // logged to edit).
                if set.isCompleted {
                    pipView
                        .contextMenu { pipMenu(for: set) }
                        .accessibilityAction(named: "Edit set") { editingSet = set }
                        .accessibilityAction(named: "Delete set") { deletingSet = set }
                } else if sets.count > 1 {
                    pipView
                        .contextMenu { pipMenu(for: set) }
                        .accessibilityAction(named: "Remove set") { removeSet(set) }
                } else {
                    pipView
                }
            }
            addSetButton
        }
        .frame(height: 44)
    }

    /// Per-set long-press menu, surfaced from the pips. Completed sets
    /// can be edited or deleted; a pending set can be removed outright
    /// (so long as it isn't the only one).
    @ViewBuilder
    private func pipMenu(for set: WorkoutSet) -> some View {
        if set.isCompleted {
            Button {
                editingSet = set
            } label: {
                Label("Edit set", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deletingSet = set
            } label: {
                Label("Delete set", systemImage: "trash")
            }
        } else if sets.count > 1 {
            Button(role: .destructive) {
                removeSet(set)
            } label: {
                Label("Remove set", systemImage: "minus.circle")
            }
        }
    }

    /// One-tap "add a set" — a quiet outlined plus that lives at the
    /// end of the pip row, where the count is already shown. Tapping
    /// it appends a set seeded from the current working set, so "one
    /// more" matches the weight you're already lifting. Adding a set
    /// to a finished exercise re-opens it for the new set.
    private var addSetButton: some View {
        Button {
            addSet()
        } label: {
            Image(systemName: "plus")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Ink.quaternary, lineWidth: 2))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a set")
        .accessibilityInputLabels([Text("Add a set"), Text("Add Set"), Text("Add")])
    }

    @ViewBuilder
    private func pip(isCompleted: Bool, isActive: Bool) -> some View {
        if isCompleted {
            Circle()
                .fill(Tint.complete)
                .frame(width: 18, height: 18)
        } else if isActive {
            Circle()
                .stroke(Tint.inProgress, lineWidth: 3)
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .strokeBorder(Ink.quaternary, lineWidth: 2)
                .frame(width: 16, height: 16)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var heroBlock: some View {
        if session.activeSet(for: exercise) != nil {
            switch exercise.trackingMode {
            case .reps:     repsHero
            case .duration: durationHero
            }
        } else {
            completedHero
        }
    }

    /// Weight × reps instrument — the default lift.
    private var repsHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BareScrubber(
                value: weightDisplayBinding,
                range: unit.strengthRange,
                step: unit.strengthStep,
                pointsPerStep: 8,
                fontSize: 104,
                unit: unit.symbol,
                unitFontSize: 18,
                numberColor: Ink.primary,
                unitColor: Ink.tertiary,
                accessibilityLabel: "Weight",
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                tickTone: .deep,
                hitSlop: 12
            )

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: repsBinding,
                    range: 1...30,
                    step: 1,
                    pointsPerStep: 16,
                    fontSize: 46,
                    unit: "reps",
                    unitFontSize: 14,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Reps",
                    showsScrubHint: isActive,
                    hitSlop: 18
                )
            }
        }
    }

    /// Timed-hold instrument — the big number is the target duration
    /// (mm:ss); the optional load below handles weighted holds and
    /// loaded carries. Left at 0 the load simply reads as bodyweight.
    private var durationHero: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            BareScrubber(
                value: durationBinding,
                range: DurationFormatter.scrubRange,
                step: DurationFormatter.scrubStep,
                pointsPerStep: 10,
                fontSize: 104,
                numberColor: Ink.primary,
                formatter: { DurationFormatter.string($0) },
                accessibilityLabel: "Hold duration",
                showsScrubHint: isActive,
                performsScrubNudge: isActive,
                fitsWidth: true,
                hitSlop: 12
            )

            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("+")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                BareScrubber(
                    value: weightDisplayBinding,
                    range: unit.strengthRange,
                    step: unit.strengthStep,
                    pointsPerStep: 8,
                    fontSize: 46,
                    unit: unit.symbol,
                    unitFontSize: 14,
                    numberColor: Ink.secondary,
                    unitColor: Ink.tertiary,
                    accessibilityLabel: "Weight",
                    showsScrubHint: isActive,
                    tickTone: .deep,
                    hitSlop: 18
                )
            }
        }
    }

    /// Exercise finished — show the top set, locked in gold, static.
    @ViewBuilder
    private var completedHero: some View {
        let top = sets.last(where: { $0.isCompleted }) ?? sets.last
        switch exercise.trackingMode {
        case .reps:
            completedRepsHero(top)
        case .duration:
            completedDurationHero(top)
        }
    }

    private func completedRepsHero(_ top: WorkoutSet?) -> some View {
        let weightText = top.map { WeightFormatter.string($0.weight, unit: unit, includeUnit: false) } ?? "—"
        let repsText = top.map { "\($0.reps)" } ?? "—"
        return VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text(weightText)
                    .font(Typography.bigMetric)
                    .foregroundStyle(Tint.complete)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(unit.symbol)
                    .font(Typography.metricInline)
                    .foregroundStyle(Tint.complete.opacity(Opacity.emphasis))
            }
            HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                Text("×")
                    .font(Typography.statValue)
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                Text(repsText)
                    .font(Typography.metricLg)
                    .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                    .monospacedDigit()
                Text("reps")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func completedDurationHero(_ top: WorkoutSet?) -> some View {
        let timeText = top.map { DurationFormatter.string($0.duration) } ?? "—"
        let loaded = (top?.weight ?? 0) > 0
        return VStack(alignment: .leading, spacing: Space.sm) {
            Text(timeText)
                .font(Typography.bigMetric)
                .foregroundStyle(Tint.complete)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            if loaded, let top {
                HStack(alignment: .lastTextBaseline, spacing: Space.sm) {
                    Text("+")
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.quaternary)
                        .accessibilityHidden(true)
                    Text(WeightFormatter.string(top.weight, unit: unit, includeUnit: false))
                        .font(Typography.metricLg)
                        .foregroundStyle(Tint.complete.opacity(Opacity.strong))
                        .monospacedDigit()
                    Text(unit.symbol)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - RIR

    /// Reps-in-reserve pill for the active set — reps mode only.
    /// Timed holds have no "reps left," so it's omitted there.
    @ViewBuilder
    private var rirControl: some View {
        if session.activeSet(for: exercise) != nil, exercise.trackingMode == .reps {
            RIRSelector(value: rirBinding)
                .padding(.bottom, Space.md)
        }
    }

    private var rirBinding: Binding<Int> {
        Binding(
            get: { session.activeSet(for: exercise)?.repsInReserve ?? 2 },
            set: {
                session.updateActiveRIR(for: exercise, rir: $0)
                saveActiveSessionChanges()
            }
        )
    }

    /// Echoes the previously-logged set's RIR in the "Last …" caption.
    /// Reps mode only — timed holds carry no reps-in-reserve.
    private func lastSetRIRSuffix(_ set: WorkoutSet) -> String {
        guard exercise.trackingMode == .reps else { return "" }
        return "  ·  \(RIRSelector.displayLabel(set.repsInReserve)) RIR"
    }

    // MARK: - Last set + action

    @ViewBuilder
    private var lastSetCaption: some View {
        if activeIndex != nil, let last = sets.last(where: { $0.isCompleted }) {
            Text("Last  \(exercise.setLabel(last, unit: unit))\(lastSetRIRSuffix(last))")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.tertiary)
                .padding(.bottom, Space.sm)
                .contextMenu {
                    Button {
                        editingSet = last
                    } label: {
                        Label("Edit last set", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deletingSet = last
                    } label: {
                        Label("Delete last set", systemImage: "trash")
                    }
                }
                .accessibilityAction(named: "Edit set") { editingSet = last }
                .accessibilityAction(named: "Delete set") { deletingSet = last }
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if let active = session.activeSet(for: exercise) {
            let isLastSet = activeIndex == sets.count - 1
            let isHold = exercise.trackingMode == .duration
            SetCompleteButton(
                reps: active.reps,
                weight: active.weight,
                isComplete: pendingCompletionSetID == active.id,
                intensity: isLastSet ? .peak : .standard,
                title: completeTitle(isLastSet: isLastSet, isHold: isHold),
                accessibilityLabelOverride: isHold
                    ? "Hold \(DurationFormatter.string(active.duration))"
                    : nil,
                onToggle: { handleSetToggle(active) }
            )
            .accessibilityIdentifier("completeSetButton")
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise complete")
                    .font(Typography.title)
                    .foregroundStyle(Tint.complete)
                Spacer()
                Text("Swipe for next  →")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.vertical, Space.section)
        }
    }

    // MARK: - Edit / delete plumbing

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingSet != nil },
            set: { if !$0 { deletingSet = nil } }
        )
    }

    /// Append a fresh pending set, seeded from the current working
    /// set (or the last set, or the plan) so it lands at the weight
    /// and reps you're already using. Keeps `plannedSets` in step so
    /// every "of N" readout agrees.
    private func addSet() {
        let seed = session.activeSet(for: exercise) ?? sets.last
        let newSet = WorkoutSet(
            weight: seed?.weight ?? exercise.plannedWeight,
            reps: seed?.reps ?? exercise.plannedReps,
            duration: seed?.duration ?? exercise.plannedDuration,
            sortOrder: exercise.sets.count
        )
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            exercise.sets.append(newSet)
        }
        exercise.plannedSets = exercise.sets.count
        session.completedAt = nil
        saveActiveSessionChanges()
        Haptics.tick()
    }

    /// Remove a still-pending set (the count went too high). Never
    /// drops the last remaining set — an exercise needs at least one.
    private func removeSet(_ set: WorkoutSet) {
        guard exercise.sets.count > 1,
              let idx = exercise.sets.firstIndex(where: { $0.id == set.id })
        else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            _ = exercise.sets.remove(at: idx)
        }
        for (i, remaining) in exercise.orderedSets.enumerated() {
            remaining.sortOrder = i
        }
        exercise.plannedSets = exercise.sets.count
        session.completedAt = nil
        saveActiveSessionChanges()
        Haptics.soft()
    }

    /// Remove a completed set from this exercise. The remaining sets'
    /// `sortOrder` is re-packed so indices in the UI stay 1..N.
    private func deleteSet(_ set: WorkoutSet) {
        guard let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) else { return }
        exercise.sets.remove(at: idx)
        for (i, remaining) in exercise.orderedSets.enumerated() {
            remaining.sortOrder = i
        }
        exercise.plannedSets = exercise.sets.count
        session.completedAt = nil
        saveActiveSessionChanges()
        Haptics.soft()
        deletingSet = nil
    }

    // MARK: - Derived

    private var exerciseIndex: Int {
        session.orderedExercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
    }

    /// True when this card is the pager's current page. Gates the
    /// first-use scrub hint so only the on-screen hero nudges and
    /// wears chevrons — not the pre-mounted neighbor cards that the
    /// SwipePager keeps in the hierarchy.
    private var isActive: Bool {
        exerciseIndex == session.activeExerciseIndex
    }

    private var sets: [WorkoutSet] {
        exercise.orderedSets
    }

    private var activeIndex: Int? {
        session.activeSetIndex(for: exercise)
    }

    private var displayedWeight: Double {
        session.activeSet(for: exercise)?.weight ?? exercise.plannedWeight
    }

    private var displayedReps: Int {
        session.activeSet(for: exercise)?.reps ?? exercise.plannedReps
    }

    /// Scrubbed in display units; converted to/from canonical lb at
    /// the binding boundary so callers never see kg.
    private var weightDisplayBinding: Binding<Double> {
        Binding(
            get: { WeightFormatter.toDisplay(displayedWeight, unit: unit) },
            set: { newDisplay in
                session.updateActiveWeight(
                    for: exercise,
                    weight: WeightFormatter.toCanonical(newDisplay, unit: unit)
                )
                saveActiveSessionChanges()
            }
        )
    }

    /// Reps live as Int in the model but BareScrubber scrubs Double.
    private var repsBinding: Binding<Double> {
        Binding(
            get: { Double(displayedReps) },
            set: { new in
                session.updateActiveReps(for: exercise, reps: Int(new.rounded()))
                saveActiveSessionChanges()
            }
        )
    }

    private var displayedDuration: TimeInterval {
        session.activeSet(for: exercise)?.duration ?? exercise.plannedDuration
    }

    /// Hold length scrubbed in seconds (Double for BareScrubber),
    /// written back to the active set as a TimeInterval.
    private var durationBinding: Binding<Double> {
        Binding(
            get: { displayedDuration },
            set: { new in
                session.updateActiveDuration(for: exercise, duration: new)
                saveActiveSessionChanges()
            }
        )
    }

    /// Verb for the complete button — mode + position aware. Timed
    /// holds finish as "Finish hold"; reps finish as "Finish exercise."
    private func completeTitle(isLastSet: Bool, isHold: Bool) -> String {
        if isLastSet {
            return isHold ? "Finish hold" : "Finish exercise"
        }
        return isHold ? "Complete hold" : "Complete set"
    }

    // MARK: - Completion pipeline

    /// Run the PR-detect + auto-advance pipeline. Holds the visual
    /// "pending" state for 550ms so the button's ripple + fill +
    /// checkmark draw-on can land before the card moves on.
    private func handleSetToggle(_ set: WorkoutSet) {
        let weight = set.weight
        let reps = set.reps
        let duration = set.duration
        let exerciseName = exercise.name
        let catalogItemID = exercise.catalogItemID
        let mode = exercise.trackingMode

        pendingCompletionSetID = set.id

        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch { return }

            let prKind = detectPersonalRecord(
                exerciseName: exerciseName,
                catalogItemID: catalogItemID,
                mode: mode,
                weight: weight,
                reps: reps,
                duration: duration
            )

            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                session.completeActiveSet(for: exercise)
            }
            saveActiveSessionChanges()
            pendingCompletionSetID = nil

            if let prKind {
                switch prKind {
                case .weight, .volume:
                    session.pendingPRValue = WeightFormatter.string(weight, unit: unit, includeUnit: false)
                    session.pendingPRUnit = unit.symbol
                case .duration:
                    session.pendingPRValue = DurationFormatter.string(duration)
                    session.pendingPRUnit = nil
                }
                session.pendingPRDetail = detailLine(
                    exerciseName: exerciseName,
                    reps: reps,
                    kind: prKind
                )
                saveActiveSessionChanges()
            }

            let exerciseNowDone = exercise.orderedSets.allSatisfy(\.isCompleted)
            if exerciseNowDone {
                let exercises = session.orderedExercises
                let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                let nextIdx = currentIdx + 1
                let cardCount = exercises.count + 1
                if nextIdx < cardCount {
                    // The earned pause: when this set finishes the
                    // whole workout, sit on the final number in
                    // silence before the summary arrives. A fired PR
                    // is its own ceremony and takes the moment instead
                    // — fall back to the normal short hop so the
                    // summary is ready behind the celebration the user
                    // dismisses.
                    let endsWorkout = session.isAllComplete && prKind == nil
                    let hold: Duration = endsWorkout ? .milliseconds(2000) : .milliseconds(300)
                    do {
                        try await Task.sleep(for: hold)
                    } catch { return }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        session.activeExerciseIndex = nextIdx
                    }
                }
            }
        }
    }

    // MARK: - PR detection

    /// The two transparent axes of progress this app celebrates.
    /// Both use numbers the user already sees on the button — no
    /// hidden formulas like Epley 1RM, which made PRs feel arbitrary.
    private enum PRKind {
        case weight
        case volume
        case duration
    }

    /// Returns the *kind* of PR a completed set sets, or nil if it
    /// doesn't beat the user's previous best on this exercise. For
    /// `.reps` exercises the axes are weight (priority) then volume;
    /// for `.duration` exercises it's the longest hold. Compares
    /// against archived + in-session prior sets.
    private func detectPersonalRecord(
        exerciseName: String,
        catalogItemID: UUID?,
        mode: TrackingMode,
        weight: Double,
        reps: Int,
        duration: TimeInterval
    ) -> PRKind? {
        let legacyKey = exerciseName.exerciseIdentityName
        let descriptor = FetchDescriptor<Exercise>()
        let archivedExercises = (try? modelContext.fetch(descriptor)) ?? []
        let archivedPriorSets = archivedExercises
            .filter { archived in
                guard archived.session?.completedAt != nil else { return false }
                if let catalogItemID {
                    return archived.catalogItemID == catalogItemID
                        || (archived.catalogItemID == nil && archived.name.exerciseIdentityName == legacyKey)
                }
                return archived.name.exerciseIdentityName == legacyKey
            }
            .flatMap(\.sets)
            .filter(\.isCompleted)

        let inSessionPriorSets = exercise.sets.filter(\.isCompleted)

        let allPriorSets = archivedPriorSets + inSessionPriorSets

        switch mode {
        case .reps:
            guard !allPriorSets.isEmpty else { return nil }
            let maxWeight = allPriorSets.map(\.weight).max() ?? 0
            let maxVolume = allPriorSets
                .map { $0.weight * Double($0.reps) }
                .max() ?? 0
            let candidateVolume = weight * Double(reps)
            if weight > maxWeight { return .weight }
            if candidateVolume > maxVolume { return .volume }
            return nil
        case .duration:
            // Only compare against prior *timed* holds, so a newly
            // tracked hold doesn't "beat" legacy zero-duration
            // records and fire a hollow PR.
            let priorHolds = allPriorSets.map(\.duration).filter { $0 > 0 }
            guard let maxDuration = priorHolds.max() else { return nil }
            if duration > maxDuration { return .duration }
            return nil
        }
    }

    private func detailLine(
        exerciseName: String,
        reps: Int,
        kind: PRKind
    ) -> String {
        switch kind {
        case .weight:
            return "\(exerciseName) · New max"
        case .volume:
            return "\(exerciseName) · \(reps) reps"
        case .duration:
            return "\(exerciseName) · Longest hold"
        }
    }

    private func saveActiveSessionChanges() {
        do {
            try modelContext.save()
            WorkoutLiveActivityController.update(for: session)
            WidgetSnapshotWriter.writeActiveWorkout(in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
        }
    }
}

#Preview("Exercise · active") {
    let session = WorkoutSession.sample
    return ActiveExerciseCard(
        exercise: session.orderedExercises[0],
        session: session
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
