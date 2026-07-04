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
            Text("\(WeightFormatter.string(setToDelete.weight, unit: unit)) · \(setToDelete.reps) reps. This can't be undone.")
        }
        .saveErrorAlert($saveError)
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
        Haptics.tick()
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
        let descriptor: FetchDescriptor<Exercise>
        if let catalogItemID {
            descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate {
                    $0.session?.completedAt != nil && (
                        $0.catalogItemID == catalogItemID
                            || ($0.catalogItemID == nil && $0.name == exerciseName)
                    )
                }
            )
        } else {
            descriptor = FetchDescriptor<Exercise>(
                predicate: #Predicate {
                    $0.session?.completedAt != nil && $0.name == exerciseName
                }
            )
        }
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

    func saveActiveSessionChanges() {
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
