//
//  ActiveExerciseCard.swift
//  vivobody
//
//  One page in the SwipePager — but no longer a "card." This is the
//  instrument: a single exercise, full-bleed on black, built to be
//  read from arm's length in half a second.
//
//  First-principles layout (top → bottom):
//    • Exercise name (the page's identity).
//    • Set segments — done / active / pending lamps, glanceable at a
//      flick and never mistakable for the pager's page dots. The
//      newest completed lamp stretches into a readout capsule
//      carrying its "60 × 8" (tap any lit lamp to edit, long-press
//      for delete) — the set timeline and the old "Last …" caption
//      merged into one strip.
//    • The HERO: the working weight as a huge monospaced odometer
//      you scrub with a vertical drag, with reps beneath it. The
//      numbers are the interface; there is no chip around them.
//    • The single biggest target on screen: a full-width verb
//      button — "Complete set" / "Finish exercise" — wearing a dim
//      volt tint so the live action is the panel's loudest surface.
//      Everything from the hero down holds a fixed rhythm; the one
//      flexible gap sits above the hero so the interactive cluster
//      stays low, in the thumb's arc.
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

    /// Production wiring routes all persistence through the session-
    /// lifetime controller. Defaults keep standalone previews usable.
    var onImmediateUpdate: (() -> Void)? = nil
    var onScrubEnded: (() -> Void)? = nil
    /// Parent-owned cancellation generation for archive/discard/minimize.
    var scrubCancellationID: Int = 0

    /// SwiftData write context persists the active draft and provides
    /// the one-time fallback source if the shared history cache has not
    /// finished its background build yet.
    @Environment(\.modelContext) private var modelContext
    @Environment(\.sessionAnalytics) private var sessionAnalytics
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

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
    @State private var completionGeneration: Int = 0

    /// Semantic card actions invalidate coasting immediately rather than
    /// letting a flywheel mutate the set behind a completion or edit.
    @State private var localScrubCancellationID: Int = 0
    @State var hasPendingScrubChanges: Bool = false
    /// Completion snapshots the visible set at tap time. Gate binding writes
    /// synchronously until the cancellation token reaches child scrubbers.
    @State var acceptsScrubInput: Bool = true

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

    /// Surfaces failures from saving the active workout draft.
    @State private var saveError: SaveErrorBox? = nil

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
        .opacity(session.isAllComplete ? 0.45 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: session.isAllComplete)
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
            Button("Cancel", role: .cancel) { }
        } message: { setToDelete in
            Text("\(exercise.setLabel(setToDelete, unit: unit)). This can't be undone.")
        }
        .saveErrorAlert($saveError)
        .onAppear { loadWeightStepPreference() }
        .onDisappear {
            completionGeneration &+= 1
            completionTask?.cancel()
            completionTask = nil
            acceptsScrubInput = true
        }
    }

    /// Accessibility text sizes need a vertically scrollable instrument so
    /// the completion action can never be pushed below the sheet. At standard
    /// sizes this remains the fixed, glanceable panel described by the design
    /// principles.
    private func cardContent(expandsVertically: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            nameRow
                .powerOn(0)
            setPips
                .padding(.top, Space.md)
                .powerOn(1)

            Spacer(minLength: Space.xl)

            heroBlock
                .powerOn(2)
                // One flexible gap above the hero; everything below it
                // (RIR → last set → verb) holds a fixed rhythm so the
                // interactive cluster sits low, in the thumb's arc,
                // instead of floating mid-panel on tall screens.
                .padding(.bottom, Space.xxl)

            rirControl
                .powerOn(3)
            actionArea
                .padding(.top, Space.md)
                .powerOn(4)
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
            weight: seed?.weight ?? exercise.plannedWeight,
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

    /// Run the PR-detect + auto-advance pipeline. Holds the visual
    /// "pending" state for 550ms so the button's ripple + fill +
    /// checkmark draw-on can land before the card moves on.
    func handleSetToggle(_ set: WorkoutSet) {
        // Treat tapping Complete as the end of any flywheel interaction.
        // Flush the value visible at the tap, then stop future coast detents
        // before the completion animation's intentional delay.
        acceptsScrubInput = false
        localScrubCancellationID &+= 1
        activeScrubDidEnd()

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

        completionGeneration &+= 1
        let generation = completionGeneration
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(550))
            } catch {
                if completionGeneration == generation {
                    acceptsScrubInput = true
                }
                return
            }
            guard completionGeneration == generation else { return }

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

            let outcome = withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) {
                session.completeActiveSet(for: exercise)
            }
            acceptsScrubInput = true
            saveActiveSessionChanges()
            pendingCompletionSetID = nil

            if let prKind {
                let payload: (value: String, unit: String?)?
                switch prKind {
                case .weight:
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
                case .reps:
                    // A rep PR advances on the rep count, so the count
                    // is the hero — the load it happened at moves down
                    // to the detail line.
                    payload = ("\(reps)", reps == 1 ? "rep" : "reps")
                case .duration:
                    payload = (DurationFormatter.string(duration), nil)
                }
                if let payload {
                    session.pendingPRValue = payload.value
                    session.pendingPRUnit = payload.unit
                    session.pendingPRDetail = detailLine(
                        exerciseName: exerciseName,
                        weight: weight,
                        kind: prKind,
                        loadMode: loadMode,
                        modality: modality,
                        unit: unit
                    )
                    saveActiveSessionChanges()
                }
            }

            switch outcome {
            case .supersetPartner(let partner):
                // Carry the user to the partner station — the app
                // performs the swipe the superset asks for, with the
                // same spring the pager uses, so the pairing teaches
                // itself the first time it happens.
                guard let partnerIdx = session.orderedExercises
                    .firstIndex(where: { $0.id == partner.id })
                else { break }
                let indexBeforeBeat = session.activeExerciseIndex
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch { return }
                // If the user swiped somewhere themselves during the
                // acknowledgement beat, their move wins — yanking the
                // pager after a manual swipe reads as a glitch.
                guard session.activeExerciseIndex == indexBeforeBeat,
                      session.activeExerciseIndex != partnerIdx
                else { break }
                withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)) {
                    session.activeExerciseIndex = partnerIdx
                }
                Haptics.soft(playsSound: false)

            case .supersetRoundRest(let resume):
                // Reposition behind the rest overlay so its label and
                // the card underneath already show the next round's
                // station when the overlay lifts.
                if let resumeIdx = session.orderedExercises
                    .firstIndex(where: { $0.id == resume.id }),
                   resumeIdx != session.activeExerciseIndex {
                    session.activeExerciseIndex = resumeIdx
                }

            case .exerciseComplete:
                let exercises = session.orderedExercises
                let currentIdx = exercises.firstIndex { $0.id == exercise.id } ?? 0
                // A superset can finish mid-group (unequal set counts);
                // land past the group's already-finished partners.
                var nextIdx = currentIdx + 1
                while nextIdx < exercises.count,
                      exercise.supersetID != nil,
                      exercises[nextIdx].supersetID == exercise.supersetID,
                      exercises[nextIdx].orderedSets.allSatisfy(\.isCompleted) {
                    nextIdx += 1
                }
                let cardCount = exercises.count + 1
                if nextIdx < cardCount {
                    let indexBeforeBeat = session.activeExerciseIndex
                    // Keep the short acknowledgement between exercise
                    // cards, but show the final summary immediately.
                    if !session.isAllComplete {
                        do {
                            try await Task.sleep(for: .milliseconds(300))
                        } catch { return }
                    }
                    // A manual swipe during the beat outranks the
                    // scripted advance.
                    guard session.activeExerciseIndex == indexBeforeBeat,
                          session.activeExerciseIndex != nextIdx
                    else { break }
                    withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85)) {
                        session.activeExerciseIndex = nextIdx
                    }
                }

            case .rest, .none:
                break
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
    /// doesn't beat the user's previous best on this exercise. The
    /// shared summary respects every archived exercise's snapshotted
    /// modality, tracking, load profile, and bodyweight. The first valid
    /// performance counts, matching the chronological history policy.
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

        // An unavailable cache is not an empty history. Treating it as
        // one would celebrate any valid set as a first record.
        guard let history = sessionAnalytics?.resolvedExerciseHistory(
            in: modelContext
        ) else {
            return nil
        }
        let archivedPrior = history[candidateHistoryKey]?
            .allTimeBest(for: semanticKind)
        let inSessionPrior = exercise.sets.compactMap {
            exercise.strengthPerformance(for: $0)
        }
        let priorBest = ([archivedPrior].compactMap { $0 } + inSessionPrior).reduce(
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

    /// Context line under the celebration hero. Weight PRs name the
    /// achievement ("New max"); rep PRs anchor the load the reps were
    /// performed at, in the same logged-load vocabulary the exercise
    /// picker uses, since the hero already claims the rep count.
    private func detailLine(
        exerciseName: String,
        weight: Double,
        kind: PRKind,
        loadMode: ExerciseLoadMode,
        modality: ExerciseModality,
        unit: WeightUnit
    ) -> String {
        switch kind {
        case .weight:
            return loadMode == .external
                ? "\(exerciseName) · New max"
                : "\(exerciseName) · New effective load"
        case .reps:
            guard let load = loadMode.loggedLoadLabel(
                weight,
                unit: unit,
                includeUnit: true
            ) else { return exerciseName }
            return "\(exerciseName) · at \(load)"
        case .duration:
            return "\(exerciseName) · \(loadMode.durationRecordDetail(modality: modality))"
        }
    }

    func saveActiveSessionChanges(cancelScrubbing: Bool = true) {
        if cancelScrubbing {
            localScrubCancellationID &+= 1
        }
        hasPendingScrubChanges = false
        if let onImmediateUpdate {
            onImmediateUpdate()
            return
        }

        do {
            try modelContext.saveOrRollback()
            SessionSideEffects.handle(.updated, session: session, in: modelContext)
        } catch {
            saveError = SaveErrorBox(error)
        }
    }

    /// BareScrubber invokes this only after the drag and any coast settle.
    func activeScrubDidEnd() {
        guard hasPendingScrubChanges else { return }
        hasPendingScrubChanges = false
        if let onScrubEnded {
            onScrubEnded()
        } else {
            saveActiveSessionChanges(cancelScrubbing: false)
        }
    }

    /// One Equatable value covers parent lifecycle cancellation and local
    /// semantic actions without exposing BareScrubber task ownership.
    var effectiveScrubCancellationID: Int {
        scrubCancellationID &+ localScrubCancellationID
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
