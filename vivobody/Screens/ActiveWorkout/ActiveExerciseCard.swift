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

import VivoKit
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

    var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .lb }

    /// Holds the ID of the set whose completion animation is still
    /// playing. While set, the SetCompleteButton renders as complete
    /// even though the session hasn't advanced yet.
    @State var pendingCompletionSetID: UUID? = nil

    /// Cancellable owner of the PR-detect + auto-advance pipeline so
    /// a re-toggle or card disappearance can abort an in-flight run.
    @State private var completionTask: Task<Void, Never>? = nil

    /// When non-nil, presents the EditSetSheet for that completed
    /// set. Driven by the last-set caption's long-press menu.
    @State var editingSet: WorkoutSet? = nil

    /// When non-nil, the destructive-confirmation alert is shown for
    /// that completed set.
    @State var deletingSet: WorkoutSet? = nil

    /// Per-exercise increment preference loaded from UserDefaults.
    /// Exercises without a catalog identity keep it for this card only.
    @State var sessionOnlyStep: Double? = nil

    /// Surfaces failures from saving the active workout draft.
    @State private var saveError: SaveErrorBox? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topMeta
                .powerOn(0)

            Spacer(minLength: Space.lg)

            nameRow
                .powerOn(1)
            setPips
                .padding(.top, Space.md)
                .powerOn(2)

            Spacer(minLength: Space.xl)

            heroBlock
                .powerOn(3)

            Spacer(minLength: Space.xl)

            rirControl
                .powerOn(4)
            lastSetCaption
            actionArea
                .padding(.top, Space.md)
                .powerOn(5)
        }
        .padding(.horizontal, Space.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .opacity(session.isAllComplete ? 0.45 : 1.0)
        .animation(.easeOut(duration: 0.6), value: session.isAllComplete)
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
            Text("\(exercise.setLabel(setToDelete, unit: unit)). This can't be undone.")
        }
        .saveErrorAlert($saveError)
        .onAppear { loadWeightStepPreference() }
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
        Haptics.tick(pitch: 0.3, playsSound: true)
    }

    /// Remove a still-pending set (the count went too high). Never
    /// drops the last remaining set — an exercise needs at least one.
    func removeSet(_ set: WorkoutSet) {
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
        Haptics.tick(pitch: -0.3, playsSound: true)
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

    /// Run the PR-detect + auto-advance pipeline. Holds the visual
    /// "pending" state for 550ms so the button's ripple + fill +
    /// checkmark draw-on can land before the card moves on.
    func handleSetToggle(_ set: WorkoutSet) {
        let weight = set.weight
        let reps = set.reps
        let duration = set.duration
        let exerciseName = exercise.name
        let catalogItemID = exercise.catalogItemID
        let catalogID = exercise.catalogID
        let mode = exercise.trackingMode
        let modality = exercise.modality
        let loadMode = exercise.loadMode
        let bodyweightFraction = exercise.bodyweightFraction
        let bodyweight = exercise.loadBodyweight

        pendingCompletionSetID = set.id

        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch { return }

            let prKind = detectPersonalRecord(
                exerciseName: exerciseName,
                catalogItemID: catalogItemID,
                catalogID: catalogID,
                mode: mode,
                modality: modality,
                loadMode: loadMode,
                bodyweightFraction: bodyweightFraction,
                bodyweight: bodyweight,
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
                let payload: (value: String, unit: String?)?
                switch prKind {
                case .weight, .reps:
                    let effectiveLoad = ExerciseLoadProfile(
                        mode: loadMode,
                        bodyweightFraction: bodyweightFraction
                    ).effectiveLoad(loggedWeight: weight, bodyweight: bodyweight)
                    payload = effectiveLoad.map {
                        (
                            WeightFormatter.string(
                                $0,
                                unit: unit,
                                includeUnit: false
                            ),
                            unit.symbol
                        )
                    }
                case .duration:
                    payload = (DurationFormatter.string(duration), nil)
                }
                if let payload {
                    session.pendingPRValue = payload.value
                    session.pendingPRUnit = payload.unit
                    session.pendingPRDetail = detailLine(
                        exerciseName: exerciseName,
                        reps: reps,
                        kind: prKind,
                        loadMode: loadMode,
                        modality: modality
                    )
                    saveActiveSessionChanges()
                }
            }

            let exerciseNowDone = exercise.orderedSets.allSatisfy(\.isCompleted)
            if exerciseNowDone {
                let exercises = session.orderedExercises
                let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                let nextIdx = currentIdx + 1
                let cardCount = exercises.count + 1
                if nextIdx < cardCount {
                    // Keep the short acknowledgement between exercise
                    // cards, but show the final summary immediately.
                    if !session.isAllComplete {
                        do {
                            try await Task.sleep(for: .milliseconds(300))
                        } catch { return }
                    }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        session.activeExerciseIndex = nextIdx
                    }
                }
            }
        }
    }

    // MARK: - PR detection

    /// The transparent ways a set can advance the standing record.
    /// Dynamic strength and eligible external-load power prioritize
    /// effective load, then reps at the same load. Comparable holds use
    /// load then duration; non-comparable holds use duration.
    private enum PRKind {
        case weight
        case reps
        case duration
    }

    /// Returns the *kind* of PR a completed set sets, or nil if it
    /// doesn't beat the user's previous best on this exercise. For
    /// Uses every archived exercise's own snapshotted modality, tracking,
    /// load profile, and bodyweight. The first valid performance counts,
    /// matching the chronological history policy.
    private func detectPersonalRecord(
        exerciseName: String,
        catalogItemID: UUID?,
        catalogID: String?,
        mode: TrackingMode,
        modality: ExerciseModality,
        loadMode: ExerciseLoadMode,
        bodyweightFraction: Double,
        bodyweight: Double,
        weight: Double,
        reps: Int,
        duration: TimeInterval
    ) -> PRKind? {
        let candidateSignature = ExercisePerformanceSignature(
            modality: modality,
            trackingMode: mode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        let semanticKind = candidateSignature.performanceKind
        guard semanticKind.supportsRecord else { return nil }

        let candidateHistoryKey = ExerciseIdentity.key(
            catalogID: catalogID,
            catalogItemID: catalogItemID,
            name: exerciseName,
            performanceSignature: candidateSignature
        )

        let candidateProfile = ExerciseLoadProfile(
            mode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        let candidateEffectiveLoad = semanticKind.comparesLoad
            ? candidateProfile.effectiveLoad(
                loggedWeight: weight,
                bodyweight: bodyweight
            )
            : nil
        guard let candidate = StrengthPerformance.make(
            kind: semanticKind,
            effectiveLoad: candidateEffectiveLoad,
            reps: reps,
            duration: duration
        ) else { return nil }

        let descriptor: FetchDescriptor<Exercise>
        if let catalogID {
            descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate {
                    $0.session?.completedAt != nil && $0.catalogID == catalogID
                }
            )
        } else if let catalogItemID {
            descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate {
                    $0.session?.completedAt != nil && $0.catalogItemID == catalogItemID
                }
            )
        } else {
            descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate {
                    $0.session?.completedAt != nil && $0.name == exerciseName
                }
            )
        }
        // A read failure is not an empty history. Treating it as one
        // would celebrate any valid set as a first record.
        guard let archivedExercises = try? modelContext.fetch(descriptor) else {
            return nil
        }
        let archivedPrior = archivedExercises
            .filter { archived in
                if catalogID == nil, catalogItemID != nil {
                    return archived.historyKey == candidateHistoryKey
                }
                return archived.performanceSemanticKind == semanticKind
            }
            .compactMap(\.bestStrengthPerformance)
        let inSessionPrior = exercise.sets.compactMap {
            exercise.strengthPerformance(for: $0)
        }
        let priorBest = (archivedPrior + inSessionPrior).reduce(
            nil as StrengthPerformance?
        ) { best, performance in
            guard let best else { return performance }
            return performance.beats(best) ? performance : best
        }

        switch candidate.advancement(over: priorBest) {
        case .load: return .weight
        case .repetitions: return .reps
        case .duration: return .duration
        case nil: return nil
        }
    }

    private func detailLine(
        exerciseName: String,
        reps: Int,
        kind: PRKind,
        loadMode: ExerciseLoadMode,
        modality: ExerciseModality
    ) -> String {
        switch kind {
        case .weight:
            return loadMode == .external
                ? "\(exerciseName) · New max"
                : "\(exerciseName) · New effective load"
        case .reps:
            return "\(exerciseName) · \(reps) reps"
        case .duration:
            return "\(exerciseName) · \(loadMode.durationRecordDetail(modality: modality))"
        }
    }

    func saveActiveSessionChanges() {
        do {
            try modelContext.saveOrRollback()
            SessionSideEffects.handle(.updated, session: session, in: modelContext)
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

#Preview("Exercise · bodyweight") {
    let exercise = Exercise(
        name: "Pull-Up",
        group: .back,
        plannedSets: 3,
        plannedReps: 8,
        plannedWeight: 0,
        loadMode: .bodyweightAdded,
        bodyweightFraction: 1
    )
    let session = WorkoutSession(
        exercises: [exercise],
        bodyweightAtStart: 180
    )
    return ActiveExerciseCard(exercise: exercise, session: session)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
}
