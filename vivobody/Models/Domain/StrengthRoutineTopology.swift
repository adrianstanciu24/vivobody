//
//  StrengthRoutineTopology.swift
//  vivobody
//
//  Stable 2–4 day routine shapes and 30/45/60-minute slot topology for the
//  strength routine builder. It preserves the caller's locale-aware day order.
//

import Foundation

nonisolated enum StrengthRoutineRegion: Hashable {
    case upper
    case lower
}

nonisolated extension MuscleGroup {
    /// Upper/lower split ownership for direct emphasis slots. Core follows the
    /// lower/trunk days, which already own direct core work in this topology.
    var strengthRoutineRegion: StrengthRoutineRegion {
        switch self {
        case .chest, .back, .shoulders, .arms: .upper
        case .legs, .core: .lower
        }
    }
}

nonisolated extension StrengthRoutineBuilder {
    static func isCompatible(
        candidate: StrengthRoutineCandidate,
        with slotKind: StrengthRoutineSlotKind,
        goal: StrengthRoutineGoal
    ) -> Bool {
        guard candidate.isStrengthExercise else { return false }
        if fitScore(candidate: candidate, slot: slotKind, goal: goal) > 0 {
            return true
        }
        guard let fallback = emphasisFallbackKind(for: slotKind) else { return false }
        return fitScore(candidate: candidate, slot: fallback, goal: goal) > 0
    }

    static func validDayCount(_ count: Int) -> Bool {
        (StrengthRoutinePolicy.minimumDayCount ... StrengthRoutinePolicy.maximumDayCount)
            .contains(count)
    }

    static func uniqueWeekdays(
        _ weekdays: [StrengthRoutineWeekday]
    ) -> [StrengthRoutineWeekday] {
        var seen: Set<StrengthRoutineWeekday> = []
        return weekdays.filter { seen.insert($0).inserted }
    }

    static func makeBlueprints(
        weekdays: [StrengthRoutineWeekday],
        duration: StrengthRoutineSessionDuration,
        emphasis: MuscleGroup?
    ) -> [DayBlueprint] {
        let count = StrengthRoutinePolicy.exerciseCount(for: duration)
        let shapes = dayShapes(dayCount: weekdays.count)
        let placement = emphasis.map {
            emphasisPlacement(
                dayCount: weekdays.count,
                visibleSlotCount: count,
                emphasis: $0
            )
        }
        return zip(weekdays, shapes).enumerated().map { index, pair in
            let (weekday, shape) = pair
            var kinds = Array(shape.kinds.prefix(count))
            if let emphasis,
               let placement,
               placement.dayIndex == index,
               kinds.indices.contains(placement.slotIndex)
            {
                kinds[placement.slotIndex] = .emphasis(emphasis)
            }
            return DayBlueprint(
                weekday: weekday,
                title: shape.title,
                slotKinds: kinds
            )
        }
    }

    static func dayShapes(dayCount: Int) -> [(title: String, kinds: [StrengthRoutineSlotKind])] {
        switch dayCount {
        case 2:
            [
                ("Full Body A", [.squat, .horizontalPush, .horizontalPull, .core, .hinge, .upperAccessory]),
                ("Full Body B", [.hinge, .verticalPush, .verticalPull, .unilateralLeg, .lowerAccessory, .core]),
            ]
        case 3:
            [
                ("Full Body A", [.squat, .horizontalPush, .horizontalPull, .core, .upperAccessory, .elbowExtension]),
                ("Full Body B", [.hinge, .verticalPush, .verticalPull, .unilateralLeg, .elbowFlexion, .lowerAccessory]),
                ("Full Body C", [.hinge, .horizontalPush, .verticalPull, .core, .upperAccessory, .lowerAccessory]),
            ]
        case 4:
            [
                ("Upper A", [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .upperAccessory, .elbowExtension]),
                ("Lower A", [.squat, .hinge, .unilateralLeg, .core, .lowerAccessory, .lowerAccessory]),
                ("Upper B", [.verticalPush, .verticalPull, .horizontalPush, .horizontalPull, .elbowFlexion, .upperAccessory]),
                ("Lower B", [.hinge, .squat, .unilateralLeg, .core, .lowerAccessory, .lowerAccessory]),
            ]
        default:
            []
        }
    }

    /// Places one explicit emphasis inside every duration bucket by replacing
    /// only a redundant or accessory position after weekly coverage remains.
    private static func emphasisPlacement(
        dayCount: Int,
        visibleSlotCount: Int,
        emphasis: MuscleGroup
    ) -> (dayIndex: Int, slotIndex: Int) {
        switch dayCount {
        case 2:
            visibleSlotCount == 4 ? (1, 3) : (0, 4)
        case 3:
            visibleSlotCount == 4 ? (2, 3) : (0, 4)
        case 4 where emphasis.strengthRoutineRegion == .upper:
            visibleSlotCount == 4 ? (0, 3) : (0, 4)
        case 4:
            visibleSlotCount == 4 ? (3, 3) : (1, 4)
        default:
            (0, max(0, visibleSlotCount - 1))
        }
    }

    private static func emphasisFallbackKind(
        for slotKind: StrengthRoutineSlotKind
    ) -> StrengthRoutineSlotKind? {
        guard case let .emphasis(group) = slotKind else { return nil }
        return group.strengthRoutineRegion == .upper ? .upperAccessory : .lowerAccessory
    }

    static func makeSlotIDs(_ blueprint: DayBlueprint) -> [StrengthRoutineSlotID] {
        var occurrenceByKind: [StrengthRoutineSlotKind: Int] = [:]
        return blueprint.slotKinds.map { kind in
            let occurrence = occurrenceByKind[kind, default: 0]
            occurrenceByKind[kind] = occurrence + 1
            return StrengthRoutineSlotID(
                weekday: blueprint.weekday,
                kind: kind,
                occurrence: occurrence
            )
        }
    }
}
