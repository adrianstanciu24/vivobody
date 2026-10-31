//
//  ActiveExerciseCardSections.swift
//  vivobody
//
//  Composition-only bridge from ActiveExerciseCard's model adapter to its
//  focused identity, reps, duration, effort, and primary-action leaves, in
//  the phone column or the wide window's two lanes.
//

import SwiftUI
import VivoKit

extension ActiveExerciseCard {
    var nameRow: some View {
        ActiveExerciseNameSection(
            input: cardInput.identity,
            dynamicTypeSize: dynamicTypeSize,
            density: density
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

    var configurationSection: some View {
        ActiveExerciseConfigurationSection(
            input: cardInput.configuration,
            actions: ActiveExerciseConfigurationActions(
                addSet: addSet,
                removeSet: { id in
                    guard let set = workoutSet(id: id) else { return }
                    removeSet(set)
                },
                selectStep: { step in
                    Haptics.selection()
                    switch exercise.trackingMode {
                    case .reps: setWeightStep(step)
                    case .duration: setDurationStep(step)
                    }
                }
            )
        )
    }

    var heroBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            configurationSection

            SectionDivider()
                .padding(.vertical, Space.sm)

            metricBlock
        }
    }

    private var metricBlock: some View {
        metricInstrument
            .background {
                Ellipse()
                    .fill(Tint.primary.opacity(0.10))
                    .padding(.horizontal, Space.xl)
                    .blur(radius: Space.xxl)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var metricInstrument: some View {
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

    func instrumentArea(
        expandsVertically: Bool,
        includesConfiguration: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if includesConfiguration {
                    heroBlock
                } else {
                    metricBlock
                }
            }
            .powerOn(2, animated: isActive)

            if showsRIRControl {
                SectionDivider()
                    .padding(.vertical, density.effortDividerPadding)
                ActiveExerciseEffortSection(
                    input: cardInput.effortAction,
                    rir: rirBinding
                )
                .powerOn(3, animated: isActive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, density.instrumentPadding)
        .frame(
            maxWidth: .infinity,
            maxHeight: expandsVertically ? .infinity : nil,
            alignment: .center
        )
    }

    /// Identity and setup in the leading lane, aligned to the top; the set
    /// in the trailing lane, with the action at the bottom in thumb reach
    /// and the working values centered above it. At accessibility sizes
    /// each lane scrolls alone, as the column does.
    func splitContent(_ lanes: DashboardLanes) -> some View {
        let scrolls = dynamicTypeSize.isAccessibilitySize
        return WorkoutLaneSplit(lanes: lanes, scrolls: scrolls) {
            VStack(alignment: .leading, spacing: 0) {
                nameRow
                    .powerOn(0, animated: isActive)
                setPips
                    .padding(.top, Space.sm)
                    .powerOn(1, animated: isActive)
                configurationSection
                    .padding(.top, Space.xl)
                    .powerOn(2, animated: isActive)
            }
            .padding(.vertical, scrolls ? Space.sm : 0)
            .frame(maxHeight: scrolls ? nil : .infinity, alignment: .top)
        } trailing: {
            VStack(alignment: .leading, spacing: 0) {
                instrumentArea(expandsVertically: !scrolls, includesConfiguration: false)
                actionArea
                    .padding(.top, Space.md)
                    .powerOn(showsRIRControl ? 4 : 3, animated: isActive)
            }
            .padding(.vertical, scrolls ? Space.sm : 0)
            .frame(maxHeight: scrolls ? nil : .infinity, alignment: .top)
        }
        // Keep enlarged controls above the page dots, as the column does.
        .padding(.bottom, scrolls ? Space.tapMin : 0)
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
