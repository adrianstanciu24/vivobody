//
//  ActiveExerciseCard.swift
//  vivobody
//
//  One page in the SwipePager — an exercise instrument built to be
//  read from arm's length in half a second. Identity, progress, and
//  adjustable working-set controls stay full-bleed on black.
//
//  First-principles layout (top → bottom):
//    • Exercise name (the page's identity).
//    • Set segments — done / active / pending lamps, glanceable at a
//      flick and never mistakable for the pager's page dots. The
//      newest completed lamp stretches into a readout capsule
//      carrying its "60 × 8" (tap any lit lamp to edit, long-press
//      for delete) — the set timeline and the old "Last …" caption
//      merged into one strip.
//    • Configuration, the working weight/reps hero, and effort share
//      one aligned field, separated by quiet hairlines rather than a
//      container. The numbers remain the interface, with no chip.
//    • The single biggest target on screen: a full-width verb
//      button — "Complete set" / "Finish exercise" — wearing a dim
//      volt tint so the live action is the panel's loudest surface.
//      A flexible middle stage centers the available controls between
//      the fixed identity and thumb-reachable primary action, so an
//      omitted capability rebalances space instead of leaving a hole.
//
//  Two accents, per the product principles: Volt for in-progress
//  (the live action), gold for complete (a finished set, exercise,
//  or PR). They never read alike.
//
//  The card owns instrument presentation and tap-time scrub flushing. Set
//  completion crosses a typed coordinator boundary; analytics, persistence,
//  and pager routing remain with the parent screen and session controller.
//

import SwiftUI
import VivoKit

struct ActiveExerciseCard: View {
    let exercise: Exercise
    @Bindable var session: WorkoutSession

    /// Production persistence routes through the session-lifetime controller.
    var onImmediateUpdate: (() -> Void)? = nil
    var onScrubEnded: (() -> Void)? = nil
    var completionActions: ActiveSetCompletionActions? = nil
    var onReplaceRequested: (() -> Void)? = nil
    /// Parent-owned cancellation generation for archive/discard/minimize.
    var scrubCancellationID: Int = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    @AppStorage(SettingsKey.weightUnit)
    private var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    /// Owns only the cancelable acknowledgement and route timeline. Domain
    /// mutation and persistence remain outside the card.
    @State private var completionCoordinator = ActiveSetCompletionCoordinator()

    /// Semantic card actions invalidate coasting immediately rather than
    /// letting a flywheel mutate the set behind a completion or edit.
    @State private var localScrubCancellationID: Int = 0
    @State var hasPendingScrubChanges: Bool = false
    /// When non-nil, presents the EditSetSheet for that completed
    /// set. Driven by tapping a completed set pip (its long-press
    /// menu adds delete).
    @State var editingSet: WorkoutSet? = nil

    /// When non-nil, the destructive-confirmation alert is shown for
    /// that completed set.
    @State var deletingSet: WorkoutSet? = nil

    /// Per-exercise increment preference loaded from UserDefaults.
    /// Exercises without a catalog identity keep it for this card only.
    @State var sessionOnlyStep: Double? = nil

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.vertical, showsIndicators: false) {
                    cardContent(expandsVertically: false)
                        .padding(.vertical, Space.sm)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Keep enlarged controls above the pager's persistent page
                // indicator instead of letting the viewport sit underneath
                // that bottom safe-area bar.
                .padding(.bottom, Space.tapMin)
            } else {
                cardContent(expandsVertically: true)
            }
        }
        .contentShape(Rectangle())
        .opacity(session.isAllComplete && !sets.isEmpty ? 0.45 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: session.isAllComplete && !sets.isEmpty)
        .sheet(item: $editingSet) { set in
            EditSetSheet(
                set: set,
                onImmediateUpdate: onImmediateUpdate,
                onScrubEnded: onScrubEnded
            )
        }
        .alert(
            "Delete this set?",
            isPresented: deleteAlertBinding,
            presenting: deletingSet
        ) { setToDelete in
            Button("Delete", role: .destructive) {
                deleteSet(setToDelete)
            }
            Button("Cancel", role: .cancel) {}
        } message: { setToDelete in
            Text("\(exercise.setLabel(setToDelete, unit: unit)). This can't be undone.")
        }
        .onAppear { loadWeightStepPreference() }
        .onDisappear { completionCoordinator.cancel() }
        .onChange(of: scrubCancellationID) { _, _ in
            completionCoordinator.cancel()
        }
    }

    /// Accessibility text sizes need a vertically scrollable instrument so
    /// the completion action can never be pushed below the sheet. At standard
    /// sizes this remains the fixed, glanceable panel described by the design
    /// principles.
    private func cardContent(expandsVertically: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            nameRow
                .powerOn(0, animated: isActive)
            setPips
                .padding(.top, Space.md)
                .powerOn(1, animated: isActive)

            instrumentArea(expandsVertically: expandsVertically)

            actionArea
                .padding(.top, Space.md)
                .powerOn(showsRIRControl ? 4 : 3, animated: isActive)
        }
        .padding(.horizontal, Space.gutter)
        .frame(
            maxWidth: .infinity,
            maxHeight: expandsVertically ? .infinity : nil,
            alignment: .leading
        )
    }

    // MARK: - Weight increment

    private func loadWeightStepPreference() {
        guard sessionOnlyStep == nil, let itemID = exercise.catalogItemID else { return }
        let key = SettingsKey.weightStep(catalogID: exercise.catalogID, catalogItemID: itemID)
        sessionOnlyStep = (UserDefaults.standard.object(forKey: key) as? NSNumber)?.doubleValue
    }

    /// Current scrub step for this exercise in display units.
    var weightStep: Double {
        unit.resolvedStrengthStep(preferred: sessionOnlyStep)
    }

    /// Persist a picked increment and snap the working weight onto
    /// the new grid.
    func setWeightStep(_ step: Double) {
        sessionOnlyStep = step
        if let itemID = exercise.catalogItemID {
            UserDefaults.standard.set(
                step,
                forKey: SettingsKey.weightStep(catalogID: exercise.catalogID, catalogItemID: itemID)
            )
        }

        if session.activeSet(for: exercise) != nil {
            let display = WeightFormatter.toDisplay(displayedWeight, unit: unit)
            let snapped = (display / step).rounded() * step
            if snapped != display {
                session.updateActiveWeight(
                    for: exercise,
                    weight: WeightFormatter.toCanonical(snapped, unit: unit)
                )
            }
        }
        saveActiveSessionChanges()
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
    func addSet() {
        let seed = session.activeSet(for: exercise) ?? sets.last
        let newSet = WorkoutSet(
            weight: exercise.trackedWeight(seed?.weight ?? exercise.plannedWeight),
            reps: seed?.reps ?? exercise.plannedReps,
            duration: seed?.duration ?? exercise.plannedDuration,
            sortOrder: exercise.sets.count
        )
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            exercise.sets.append(newSet)
        }
        exercise.plannedSets = exercise.sets.count
        session.completedAt = nil
        saveActiveSessionChanges()
        Haptics.tick()
    }

    /// Remove a still-pending set (the count went too high). Never
    /// drops the last remaining set — an exercise needs at least one.
    func removeSet(_ set: WorkoutSet) {
        guard exercise.sets.count > 1,
              let idx = exercise.sets.firstIndex(where: { $0.id == set.id })
        else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
            _ = exercise.sets.remove(at: idx)
        }
        for (i, remaining) in exercise.orderedSets.enumerated() {
            remaining.sortOrder = i
        }
        exercise.plannedSets = exercise.sets.count
        session.completedAt = nil
        saveActiveSessionChanges()
        Haptics.tick()
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

    // MARK: - Completion pipeline

    /// End any flywheel interaction and delegate a frozen tap-time request.
    /// The coordinator closes its input gate before this preparation closure
    /// invalidates coast and flushes the last visible detent.
    func handleSetToggle(_ set: WorkoutSet) {
        guard let actions = resolvedCompletionActions else { return }
        let cardActions = ActiveSetCompletionActions(
            commit: actions.commit,
            currentSelection: actions.currentSelection,
            applyRoute: actions.applyRoute,
            onCommitted: {
                actions.onCommitted()
                localScrubCancellationID &+= 1
                hasPendingScrubChanges = false
            }
        )
        completionCoordinator.start(
            setID: set.id,
            prepare: {
                localScrubCancellationID &+= 1
                activeScrubDidEnd()
                return completionIntent(for: set)
            },
            actions: cardActions
        )
    }

    private func completionIntent(for set: WorkoutSet) -> ActiveSetCompletionIntent {
        ActiveSetCompletionIntent(
            sessionID: session.id,
            exerciseID: exercise.id,
            setID: set.id,
            personalRecordCandidate: LivePersonalRecordCandidate(
                exerciseName: exercise.name,
                catalogItemID: exercise.catalogItemID,
                catalogID: exercise.catalogID,
                performanceSignature: exercise.performanceSignature,
                loadProfile: exercise.loadProfile,
                bodyweight: exercise.loadBodyweight,
                loggedWeight: exercise.trackedWeight(set.weight),
                repetitions: set.reps,
                duration: set.duration,
                priorInSessionPerformances: exercise.sets.compactMap {
                    exercise.strengthPerformance(for: $0)
                }
            )
        )
    }

    private var resolvedCompletionActions: ActiveSetCompletionActions? {
        if let completionActions { return completionActions }
        #if DEBUG
            return ActiveSetCompletionPreviewAdapter.actions(
                session: session,
                unit: unit,
                reduceMotion: reduceMotion
            )
        #else
            return nil
        #endif
    }

    func saveActiveSessionChanges() {
        localScrubCancellationID &+= 1
        hasPendingScrubChanges = false
        onImmediateUpdate?()
    }

    /// BareScrubber invokes this only after the drag and any coast settle.
    func activeScrubDidEnd() {
        guard hasPendingScrubChanges else { return }
        hasPendingScrubChanges = false
        if let onScrubEnded {
            onScrubEnded()
        } else {
            onImmediateUpdate?()
        }
    }

    var pendingCompletionSetID: UUID? {
        completionCoordinator.pendingSetID
    }

    var acceptsScrubInput: Bool {
        completionCoordinator.acceptsInput
    }

    /// One Equatable value covers parent lifecycle cancellation and local
    /// semantic actions without exposing BareScrubber task ownership.
    var effectiveScrubCancellationID: Int {
        scrubCancellationID &+ localScrubCancellationID
    }
}
