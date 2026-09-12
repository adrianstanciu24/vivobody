//
//  ActiveExerciseCardOptions.swift
//  vivobody
//
//  Shared exercise-options menu content and the active-card long-press
//  shortcut. The active-workout top bar owns the visible menu pill so the
//  exercise identity remains free of small trailing controls.
//

import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    var exerciseMenu: some View {
        ExerciseOptionsMenuContent(
            exercise: exercise,
            session: session,
            onReplace: onReplaceRequested,
            onLinkWithNext: linkWithNextExercise,
            onAddSupersetPartner: onAddSupersetPartnerRequested,
            onUnlink: unlinkFromSuperset,
            onRemove: onRemoveRequested
        )
    }

    func linkWithNextExercise() {
        let exercises = session.orderedExercises
        guard exerciseIndex + 1 < exercises.count else { return }
        SupersetGrouping.linkSeam(at: exerciseIndex, in: exercises)
        saveActiveSessionChanges()
        Haptics.soft()
    }

    func unlinkFromSuperset() {
        SupersetGrouping.unlink(exercise, in: session.orderedExercises)
        saveActiveSessionChanges()
        Haptics.soft()
    }
}

struct ExerciseOptionsMenuContent: View {
    let exercise: Exercise
    let session: WorkoutSession
    let onReplace: (() -> Void)?
    let onLinkWithNext: () -> Void
    /// Opens the catalog to insert a new partner right after this
    /// exercise and link the pair. Nil when the host cannot present
    /// the picker.
    let onAddSupersetPartner: (() -> Void)?
    let onUnlink: () -> Void
    /// Removes the exercise from the live workout. Nil when the host
    /// has no session controller to commit the deletion.
    let onRemove: (() -> Void)?

    var body: some View {
        let exercises = session.orderedExercises
        if let onReplace {
            Button {
                onReplace()
            } label: {
                Label(
                    "Replace exercise",
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
        }
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }),
           index + 1 < exercises.count,
           !SupersetGrouping.isSeamLinked(at: index, in: exercises)
        {
            Button {
                onLinkWithNext()
            } label: {
                Label("Superset with \(exercises[index + 1].name)", systemImage: "link")
            }
        }
        if let onAddSupersetPartner {
            Button {
                onAddSupersetPartner()
            } label: {
                Label("Add superset partner…", systemImage: "link.badge.plus")
            }
        }
        if session.isInSuperset(exercise) {
            Button {
                onUnlink()
            } label: {
                Label("Remove from superset", systemImage: "minus.circle")
            }
        }
        if let onRemove {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove exercise", systemImage: "trash")
            }
        }
    }
}
