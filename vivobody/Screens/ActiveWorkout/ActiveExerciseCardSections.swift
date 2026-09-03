//
//  ActiveExerciseCardSections.swift
//  vivobody
//
//  Composition-only bridge from ActiveExerciseCard's model adapter to its
//  focused identity, reps, duration, effort, and primary-action leaves.
//

import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    var nameRow: some View {
        ActiveExerciseNameSection(
            input: cardInput.identity,
            dynamicTypeSize: dynamicTypeSize
        ) {
            exerciseMenu
        }
    }

    var setPips: some View {
        ActiveSetStatusSection(
            input: cardInput.identity,
            actions: ActiveSetIndicatorActions(
                tapCompleted: { id in
                    guard let set = workoutSet(id: id) else { return }
                    Haptics.selection()
                    editingSet = set
                },
                edit: { id in
                    editingSet = workoutSet(id: id)
                },
                delete: { id in
                    deletingSet = workoutSet(id: id)
                },
                remove: { id in
                    guard let set = workoutSet(id: id) else { return }
                    removeSet(set)
                }
            )
        )
    }

    var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActiveExerciseConfigurationSection(
                input: cardInput.configuration,
                actions: ActiveExerciseConfigurationActions(
                    addSet: addSet,
                    removeSet: { id in
                        guard let set = workoutSet(id: id) else { return }
                        removeSet(set)
                    },
                    selectWeightStep: { step in
                        Haptics.selection()
                        setWeightStep(step)
                    }
                )
            )

            SectionDivider()
                .padding(.vertical, Space.lg)

            switch cardInput.metric {
            case .empty:
                ActiveExerciseEmptyInstrument()
            case let .reps(input):
                ActiveRepsInstrument(
                    input: input,
                    weight: weightDisplayBinding,
                    reps: repsBinding,
                    onScrubEnded: activeScrubDidEnd,
                    adjustResistance: adjustResistance
                )
            case let .duration(input):
                ActiveDurationInstrument(
                    input: input,
                    weight: weightDisplayBinding,
                    duration: durationBinding,
                    onScrubEnded: activeScrubDidEnd,
                    adjustResistance: adjustResistance
                )
            }
        }
    }

    func instrumentArea(expandsVertically: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBlock
                .powerOn(2, animated: isActive)

            if showsRIRControl {
                SectionDivider()
                    .padding(.vertical, Space.xl)
                ActiveExerciseEffortSection(
                    input: cardInput.effortAction,
                    rir: rirBinding
                )
                .powerOn(3, animated: isActive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Space.lg)
        .frame(
            maxWidth: .infinity,
            maxHeight: expandsVertically ? .infinity : nil,
            alignment: .center
        )
    }

    var actionArea: some View {
        ActiveExerciseActionArea(
            input: cardInput.effortAction,
            dynamicTypeSize: dynamicTypeSize,
            addSet: addSet,
            completeSet: { id in
                guard let set = workoutSet(id: id) else { return }
                handleSetToggle(set)
            }
        )
    }
}
