//
//  StrengthRoutinePolicy.swift
//  vivobody
//
//  Conservative eligibility, set, target, and session-size policy for the
//  deterministic strength routine builder. It deliberately avoids unsupported
//  load, fatigue, recovery, progression, and deload prescriptions.
//

import Foundation

/// V1 product policy, intentionally narrower than adaptive programming. These
/// constants choose conservative 2–3 set prescriptions and exact editable
/// targets; they are product decisions rather than individualized coaching.
nonisolated enum StrengthRoutinePolicy {
    static let minimumDayCount = 2
    static let maximumDayCount = 4

    /// Bodyweight is a baseline capability rather than equipment the user
    /// must opt into. Every other equipment value remains a hard constraint.
    static func allowsEquipment(
        _ equipment: Equipment,
        selectedEquipment: Set<Equipment>
    ) -> Bool {
        equipment == .bodyweight || selectedEquipment.contains(equipment)
    }

    static func exerciseCount(
        for duration: StrengthRoutineSessionDuration
    ) -> Int {
        switch duration {
        case .minutes30: 4
        case .minutes45: 5
        case .minutes60: 6
        }
    }

    static func prescription(
        for candidate: StrengthRoutineCandidate,
        goal: StrengthRoutineGoal
    ) -> StrengthRoutinePrescription {
        let sets = setCount(mechanic: candidate.mechanic, goal: goal)
        if candidate.trackingMode == .duration {
            return StrengthRoutinePrescription(
                sets: sets,
                targetDurationSeconds: 30
            )
        }

        return StrengthRoutinePrescription(
            sets: sets,
            targetReps: targetReps(mechanic: candidate.mechanic, goal: goal)
        )
    }

    private static func setCount(
        mechanic: Mechanic,
        goal: StrengthRoutineGoal
    ) -> Int {
        switch (goal, mechanic) {
        case (.strength, .compound), (.muscle, _), (.balanced, .compound): 3
        case (.strength, .isolation), (.balanced, .isolation): 2
        }
    }

    private static func targetReps(
        mechanic: Mechanic,
        goal: StrengthRoutineGoal
    ) -> Int {
        switch (goal, mechanic) {
        case (.strength, .compound): 5
        case (.strength, .isolation): 10
        case (.muscle, .compound): 8
        case (.muscle, .isolation): 12
        case (.balanced, .compound): 6
        case (.balanced, .isolation): 10
        }
    }
}

nonisolated extension StrengthRoutineBuilderInput {
    func replacingLocks(
        with locks: [StrengthRoutineSlotID: String]
    ) -> StrengthRoutineBuilderInput {
        StrengthRoutineBuilderInput(
            weekdays: weekdays,
            sessionDuration: sessionDuration,
            goal: goal,
            availableEquipment: availableEquipment,
            emphasis: emphasis,
            includedCatalogIDs: includedCatalogIDs,
            excludedCatalogIDs: excludedCatalogIDs,
            preferFamiliar: preferFamiliar,
            lockedSelections: locks
        )
    }
}

nonisolated extension StrengthRoutineBuilder {
    static func exerciseID(
        for slotID: StrengthRoutineSlotID,
        in plan: StrengthRoutinePlan
    ) -> String? {
        plan.days.flatMap(\.slots).first(where: { $0.id == slotID })?.exercise?.catalogID
    }

    static func addingReplacementGap(
        to plan: StrengthRoutinePlan,
        slotID: StrengthRoutineSlotID
    ) -> StrengthRoutinePlan {
        let gap = StrengthRoutineGap(
            severity: .advisory,
            kind: .noReplacementAvailable(slotID)
        )
        return StrengthRoutinePlan(days: plan.days, gaps: unique(plan.gaps + [gap]))
    }

    static func unique(_ gaps: [StrengthRoutineGap]) -> [StrengthRoutineGap] {
        var seen: Set<StrengthRoutineGap> = []
        return gaps.filter { seen.insert($0).inserted }
    }
}
