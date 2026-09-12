//
//  ActiveWorkoutExerciseEdits.swift
//  vivobody
//
//  Structural edits to the live exercise list, reached from the exercise
//  options menu: inserting a linked superset partner and removing an
//  exercise. The screen file keeps layout and lifecycle; this extension
//  owns the mutations, their confirmation copy, and the pager bookkeeping
//  that keeps the user on the card they were reading.
//

import SwiftUI
import VivoKit

/// Value snapshot of the exercise a superset partner is being added
/// after. Holds only the ID so the sheet item stays stable if the
/// session's exercise list changes while the picker is up.
struct SupersetPartnerAnchor: Identifiable {
    let id: UUID

    init(_ exercise: Exercise) {
        id = exercise.id
    }
}

/// Value snapshot for the removal confirmation. It holds no live model
/// because confirming deletes that model before the alert finishes
/// dismissing.
struct ExerciseRemovalTarget: Identifiable {
    let id: UUID
    let name: String
    let completedSetCount: Int

    init(_ exercise: Exercise) {
        id = exercise.id
        name = exercise.name
        completedSetCount = exercise.sets.count(where: \.isCompleted)
    }
}

extension ActiveWorkoutScreen {
    // MARK: - Superset partner

    func beginAddingSupersetPartner(to exercise: Exercise) {
        finishScrubbing()
        showAddExercisePicker = false
        supersetPartnerAnchor = SupersetPartnerAnchor(exercise)
    }

    /// Insert a fresh Exercise directly after `anchorID` and link the
    /// two as a superset, so a pair can be built from any card without
    /// needing an unlinked neighbour first. The pager stays on the
    /// card the user was reading; only later indices shift.
    func insertSupersetPartner(after anchorID: UUID, from item: ExerciseCatalogItem) {
        let exercises = session.orderedExercises
        guard let anchorIndex = exercises.firstIndex(where: { $0.id == anchorID }) else { return }

        for exercise in exercises[(anchorIndex + 1)...] {
            exercise.sortOrder += 1
        }
        let partner = makeAddedExercise(from: item, sortOrder: anchorIndex + 1)
        session.exercises.append(partner)
        SupersetGrouping.linkSeam(at: anchorIndex, in: session.orderedExercises)

        if session.activeExerciseIndex > anchorIndex {
            session.activeExerciseIndex += 1
        }
        saveActiveSessionChanges()
        Haptics.soft()
    }

    // MARK: - Removal

    /// A pending exercise leaves immediately; one with logged sets asks
    /// first, because those sets go with it.
    func beginRemoving(_ exercise: Exercise) {
        guard onRemoveExercise != nil else { return }
        finishScrubbing()
        let target = ExerciseRemovalTarget(exercise)
        if target.completedSetCount == 0 {
            removeExercise(target)
        } else {
            removalTarget = target
        }
    }

    func removeExercise(_ target: ExerciseRemovalTarget) {
        guard let onRemoveExercise, onRemoveExercise(target.id) else { return }
        removalTarget = nil
        Haptics.soft()
        // Removing the last exercise reopens the picker; cancelling it
        // closes the now-empty draft, matching the empty-start flow.
        if session.orderedExercises.isEmpty {
            showAddExercisePicker = true
        }
    }

    var removalAlertBinding: Binding<Bool> {
        Binding(
            get: { removalTarget != nil },
            set: { if !$0 { removalTarget = nil } }
        )
    }

    @ViewBuilder
    func removalAlertActions(for target: ExerciseRemovalTarget) -> some View {
        Button("Remove", role: .destructive) {
            removeExercise(target)
        }
        Button("Cancel", role: .cancel) {}
    }

    func removalAlertMessage(for target: ExerciseRemovalTarget) -> Text {
        let sets = target.completedSetCount
        return Text(
            "\(target.name) has \(sets) logged set\(sets == 1 ? "" : "s") in this workout. Removing it deletes them. This can't be undone."
        )
    }
}
