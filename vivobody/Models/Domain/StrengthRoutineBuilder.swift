//
//  StrengthRoutineBuilder.swift
//  vivobody
//
//  Deterministic strength-routine planning over immutable catalog snapshots.
//  The engine applies transparent product policy, preserves user constraints,
//  and reports unsupported coverage instead of inventing programming facts.
//

import Foundation

// MARK: - Builder

nonisolated enum StrengthRoutineBuilder {
    struct DayBlueprint {
        let weekday: StrengthRoutineWeekday
        let title: String
        let slotKinds: [StrengthRoutineSlotKind]
    }

    private struct BuildState {
        var assignments: [StrengthRoutineSlotID: StrengthRoutineCandidate] = [:]
        var blockedSlots: Set<StrengthRoutineSlotID> = []
        var gaps: [StrengthRoutineGap] = []
    }

    static func build(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate]
    ) -> StrengthRoutinePlan {
        build(
            input: input,
            candidates: candidates,
            excludedBySlot: [:],
            userLockedSlots: Set(input.lockedSelections.keys)
        )
    }

    /// Replaces one unlocked slot while holding the rest of the visible plan
    /// stable. If no truthful alternative exists, the original plan is kept
    /// and receives a typed advisory instead of silently changing other rows.
    static func replacing(
        slotID: StrengthRoutineSlotID,
        in plan: StrengthRoutinePlan,
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate]
    ) -> StrengthRoutinePlan {
        guard input.lockedSelections[slotID] == nil,
              !input.includedCatalogIDs.contains(exerciseID(for: slotID, in: plan) ?? ""),
              let currentID = exerciseID(for: slotID, in: plan)
        else {
            return addingReplacementGap(to: plan, slotID: slotID)
        }

        var locks = input.lockedSelections
        for day in plan.days {
            for slot in day.slots where slot.id != slotID {
                if let catalogID = slot.exercise?.catalogID {
                    locks[slot.id] = catalogID
                }
            }
        }
        let replacementInput = input.replacingLocks(with: locks)
        let replacement = build(
            input: replacementInput,
            candidates: candidates,
            excludedBySlot: [slotID: [currentID]],
            userLockedSlots: Set(input.lockedSelections.keys)
        )
        guard let replacementID = exerciseID(for: slotID, in: replacement),
              replacementID != currentID
        else {
            return addingReplacementGap(to: plan, slotID: slotID)
        }
        return replacement
    }

    private static func build(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate],
        excludedBySlot: [StrengthRoutineSlotID: Set<String>],
        userLockedSlots: Set<StrengthRoutineSlotID>
    ) -> StrengthRoutinePlan {
        let weekdays = uniqueWeekdays(input.weekdays)
        var state = BuildState()
        guard validDayCount(weekdays.count) else {
            state.gaps.append(.init(severity: .blocking, kind: .invalidDayCount(weekdays.count)))
            return StrengthRoutinePlan(days: [], gaps: state.gaps)
        }

        let blueprints = makeBlueprints(
            weekdays: weekdays,
            duration: input.sessionDuration,
            emphasis: input.emphasis
        )
        let slotIDs = blueprints.flatMap(makeSlotIDs)
        let eligible = eligibleCandidates(input: input, candidates: candidates)

        applyLocks(
            input: input,
            candidates: eligible,
            slotIDs: slotIDs,
            state: &state
        )
        applyIncludedExercises(
            input: input,
            candidates: eligible,
            slotIDs: slotIDs,
            state: &state
        )
        fillOpenSlots(
            input: input,
            candidates: eligible,
            slotIDs: slotIDs,
            excludedBySlot: excludedBySlot,
            state: &state
        )

        let days = materializeDays(
            blueprints: blueprints,
            input: input,
            userLockedSlots: userLockedSlots,
            assignments: state.assignments
        )
        appendCoverageGaps(input: input, assignments: state.assignments, state: &state)
        return StrengthRoutinePlan(days: days, gaps: unique(state.gaps))
    }

    // MARK: Constraints and assignment

    private static func eligibleCandidates(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate]
    ) -> [StrengthRoutineCandidate] {
        var byID: [String: StrengthRoutineCandidate] = [:]
        for candidate in candidates.sorted(by: stableCandidateOrder) {
            guard candidate.isStrengthExercise,
                  StrengthRoutinePolicy.allowsEquipment(
                      candidate.equipment,
                      selectedEquipment: input.availableEquipment
                  ),
                  !input.excludedCatalogIDs.contains(candidate.catalogID)
            else { continue }
            byID[candidate.catalogID] = byID[candidate.catalogID] ?? candidate
        }
        return byID.values.sorted(by: stableCandidateOrder)
    }

    private static func applyLocks(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate],
        slotIDs: [StrengthRoutineSlotID],
        state: inout BuildState
    ) {
        let candidateByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.catalogID, $0) })
        let slotSet = Set(slotIDs)
        for slotID in slotIDs {
            guard let catalogID = input.lockedSelections[slotID] else { continue }
            guard let candidate = candidateByID[catalogID] else {
                state.blockedSlots.insert(slotID)
                state.gaps.append(.init(
                    severity: .blocking,
                    kind: .unavailableLockedExercise(slotID, catalogID)
                ))
                continue
            }
            guard isCompatible(candidate: candidate, with: slotID.kind, goal: input.goal) else {
                state.blockedSlots.insert(slotID)
                state.gaps.append(.init(
                    severity: .blocking,
                    kind: .incompatibleLockedExercise(slotID, catalogID)
                ))
                continue
            }
            let duplicatesInDay = state.assignments.contains { assignment in
                assignment.key.weekday == slotID.weekday
                    && assignment.value.catalogID == catalogID
            }
            guard !duplicatesInDay else {
                state.blockedSlots.insert(slotID)
                state.gaps.append(.init(
                    severity: .blocking,
                    kind: .duplicateLockedExercise(slotID, catalogID)
                ))
                continue
            }
            state.assignments[slotID] = candidate
        }
        for slotID in input.lockedSelections.keys where !slotSet.contains(slotID) {
            state.gaps.append(.init(severity: .blocking, kind: .unavailableLockedSlot(slotID)))
        }
    }

    private static func applyIncludedExercises(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate],
        slotIDs: [StrengthRoutineSlotID],
        state: inout BuildState
    ) {
        let candidateByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.catalogID, $0) })
        for catalogID in input.includedCatalogIDs.sorted() {
            if state.assignments.values.contains(where: { $0.catalogID == catalogID }) {
                continue
            }
            guard let candidate = candidateByID[catalogID] else {
                state.gaps.append(.init(
                    severity: .blocking,
                    kind: .unavailableIncludedExercise(catalogID)
                ))
                continue
            }
            guard let slotID = bestOpenSlot(
                for: candidate,
                slotIDs: slotIDs,
                goal: input.goal,
                assignments: state.assignments,
                blockedSlots: state.blockedSlots
            ) else {
                state.gaps.append(.init(
                    severity: .blocking,
                    kind: .includedExerciseDoesNotFit(catalogID)
                ))
                continue
            }
            state.assignments[slotID] = candidate
        }
    }

    private static func fillOpenSlots(
        input: StrengthRoutineBuilderInput,
        candidates: [StrengthRoutineCandidate],
        slotIDs: [StrengthRoutineSlotID],
        excludedBySlot: [StrengthRoutineSlotID: Set<String>],
        state: inout BuildState
    ) {
        for slotID in slotIDs
            where state.assignments[slotID] == nil && !state.blockedSlots.contains(slotID)
        {
            let excludedIDs = excludedBySlot[slotID] ?? []
            let matching = candidates.filter {
                !excludedIDs.contains($0.catalogID)
                    && isCompatible(candidate: $0, with: slotID.kind, goal: input.goal)
            }
            guard let candidate = chooseCandidate(
                from: matching,
                slotID: slotID,
                input: input,
                assignments: state.assignments
            ) else {
                state.gaps.append(.init(severity: .blocking, kind: .noEligibleExercise(slotID)))
                continue
            }
            appendRedundancyGap(candidate: candidate, slotID: slotID, state: &state)
            state.assignments[slotID] = candidate
        }
    }

    private static func bestOpenSlot(
        for candidate: StrengthRoutineCandidate,
        slotIDs: [StrengthRoutineSlotID],
        goal: StrengthRoutineGoal,
        assignments: [StrengthRoutineSlotID: StrengthRoutineCandidate],
        blockedSlots: Set<StrengthRoutineSlotID>
    ) -> StrengthRoutineSlotID? {
        let openSlots = slotIDs.filter {
            assignments[$0] == nil
                && !blockedSlots.contains($0)
                && fitScore(candidate: candidate, slot: $0.kind, goal: goal) > 0
        }
        return openSlots.max { lhs, rhs in
            let lhsScore = fitScore(candidate: candidate, slot: lhs.kind, goal: goal)
            let rhsScore = fitScore(candidate: candidate, slot: rhs.kind, goal: goal)
            return lhsScore < rhsScore
        }
    }

    private static func chooseCandidate(
        from candidates: [StrengthRoutineCandidate],
        slotID: StrengthRoutineSlotID,
        input: StrengthRoutineBuilderInput,
        assignments: [StrengthRoutineSlotID: StrengthRoutineCandidate]
    ) -> StrengthRoutineCandidate? {
        guard !candidates.isEmpty else { return nil }
        let dayIDs = Set(assignments.compactMap { assignment in
            assignment.key.weekday == slotID.weekday ? assignment.value.catalogID : nil
        })
        let dayDistinct = candidates.filter { !dayIDs.contains($0.catalogID) }
        guard !dayDistinct.isEmpty else { return nil }

        let usedIDs = Set(assignments.values.map(\.catalogID))
        let unused = dayDistinct.filter { !usedIDs.contains($0.catalogID) }
        var pool = unused.isEmpty ? dayDistinct : unused

        let dayFamilies = Set(assignments.compactMap { assignment in
            assignment.key.weekday == slotID.weekday ? assignment.value.familyID : nil
        })
        let freshFamilies = pool.filter { !dayFamilies.contains($0.familyID) }
        if !freshFamilies.isEmpty {
            pool = freshFamilies
        }
        return pool.sorted {
            ranksBefore($0, $1, slot: slotID.kind, input: input)
        }.first
    }

    // MARK: Ranking

    private static func ranksBefore(
        _ lhs: StrengthRoutineCandidate,
        _ rhs: StrengthRoutineCandidate,
        slot: StrengthRoutineSlotKind,
        input: StrengthRoutineBuilderInput
    ) -> Bool {
        let lhsFit = fitScore(candidate: lhs, slot: slot, goal: input.goal)
        let rhsFit = fitScore(candidate: rhs, slot: slot, goal: input.goal)
        if lhsFit != rhsFit { return lhsFit > rhsFit }
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
        if input.preferFamiliar, lhs.familiarity != rhs.familiarity {
            return familiarityRanksBefore(lhs.familiarity, rhs.familiarity)
        }
        if lhs.searchPriority != rhs.searchPriority {
            return lhs.searchPriority > rhs.searchPriority
        }
        return stableCandidateOrder(lhs, rhs)
    }

    private static func familiarityRanksBefore(
        _ lhs: StrengthRoutineFamiliarity,
        _ rhs: StrengthRoutineFamiliarity
    ) -> Bool {
        if lhs.sessionCount != rhs.sessionCount { return lhs.sessionCount > rhs.sessionCount }
        if lhs.lastPerformedAt != rhs.lastPerformedAt {
            return (lhs.lastPerformedAt ?? .distantPast) > (rhs.lastPerformedAt ?? .distantPast)
        }
        return false
    }

    private static func stableCandidateOrder(
        _ lhs: StrengthRoutineCandidate,
        _ rhs: StrengthRoutineCandidate
    ) -> Bool {
        lhs.catalogID < rhs.catalogID
    }

    static func fitScore(
        candidate: StrengthRoutineCandidate,
        slot: StrengthRoutineSlotKind,
        goal: StrengthRoutineGoal
    ) -> Int {
        if let movementScore = movementFitScore(candidate: candidate, slot: slot) {
            return movementScore
        }
        return supplementalFitScore(candidate: candidate, slot: slot, goal: goal)
    }

    private static func movementFitScore(
        candidate: StrengthRoutineCandidate,
        slot: StrengthRoutineSlotKind
    ) -> Int? {
        switch slot {
        case .horizontalPush:
            directionalScore(candidate: candidate, pattern: .push, direction: .horizontal)
        case .horizontalPull:
            directionalScore(candidate: candidate, pattern: .pull, direction: .horizontal)
        case .verticalPush:
            directionalScore(candidate: candidate, pattern: .push, direction: .vertical)
        case .verticalPull:
            directionalScore(candidate: candidate, pattern: .pull, direction: .vertical)
        case .squat:
            candidate.pattern == .squat ? 40 : 0
        case .hinge:
            candidate.pattern == .hinge ? 40 : 0
        case .unilateralLeg:
            unilateralLegScore(candidate)
        default:
            nil
        }
    }

    private static func supplementalFitScore(
        candidate: StrengthRoutineCandidate,
        slot: StrengthRoutineSlotKind,
        goal: StrengthRoutineGoal
    ) -> Int {
        switch slot {
        case .core:
            candidate.trainingRole == .core || candidate.group == .core ? 40 : 0
        case .elbowFlexion:
            armScore(candidate: candidate, familyID: "elbow-flexion", role: .pull)
        case .elbowExtension:
            armScore(candidate: candidate, familyID: "elbow-extension", role: .push)
        case .upperAccessory:
            accessoryScore(candidate: candidate, upperBody: true, goal: goal)
        case .lowerAccessory:
            accessoryScore(candidate: candidate, upperBody: false, goal: goal)
        case let .emphasis(group):
            candidate.group == group ? mechanicPreference(candidate.mechanic, goal: goal) : 0
        default:
            0
        }
    }

    private static func directionalScore(
        candidate: StrengthRoutineCandidate,
        pattern: MovementPattern,
        direction: PushPullDirection
    ) -> Int {
        guard candidate.pattern == pattern else { return 0 }
        if candidate.direction == direction { return 40 }
        return candidate.direction == .diagonal ? 20 : 0
    }

    private static func unilateralLegScore(_ candidate: StrengthRoutineCandidate) -> Int {
        guard candidate.group == .legs else { return 0 }
        if candidate.pattern == .lunge { return 40 }
        return candidate.laterality == .unilateral && candidate.mechanic == .compound ? 25 : 0
    }

    private static func armScore(
        candidate: StrengthRoutineCandidate,
        familyID: String,
        role: TrainingRole
    ) -> Int {
        if candidate.familyID == familyID { return 40 }
        return candidate.group == .arms
            && candidate.mechanic == .isolation
            && candidate.trainingRole == role ? 20 : 0
    }

    private static func accessoryScore(
        candidate: StrengthRoutineCandidate,
        upperBody: Bool,
        goal: StrengthRoutineGoal
    ) -> Int {
        let upperGroups: Set<MuscleGroup> = [.chest, .back, .shoulders, .arms]
        let matchesRegion = upperBody
            ? upperGroups.contains(candidate.group)
            : candidate.group == .legs
        guard matchesRegion else { return 0 }
        return mechanicPreference(candidate.mechanic, goal: goal)
    }

    private static func mechanicPreference(
        _ mechanic: Mechanic,
        goal: StrengthRoutineGoal
    ) -> Int {
        switch (goal, mechanic) {
        case (.strength, .compound): 35
        case (.strength, .isolation): 20
        case (.muscle, .isolation): 35
        case (.muscle, .compound): 25
        case (.balanced, .compound): 30
        case (.balanced, .isolation): 28
        }
    }

    // MARK: Output and gaps

    private static func materializeDays(
        blueprints: [DayBlueprint],
        input: StrengthRoutineBuilderInput,
        userLockedSlots: Set<StrengthRoutineSlotID>,
        assignments: [StrengthRoutineSlotID: StrengthRoutineCandidate]
    ) -> [StrengthRoutineDay] {
        blueprints.map { blueprint in
            let slots = makeSlotIDs(blueprint).map { slotID in
                let exercise = assignments[slotID].map {
                    makeExercise(
                        candidate: $0,
                        slotID: slotID,
                        input: input,
                        userLockedSlots: userLockedSlots
                    )
                }
                return StrengthRoutineSlot(id: slotID, kind: slotID.kind, exercise: exercise)
            }
            return StrengthRoutineDay(
                weekday: blueprint.weekday,
                title: blueprint.title,
                slots: slots
            )
        }
    }

    private static func makeExercise(
        candidate: StrengthRoutineCandidate,
        slotID: StrengthRoutineSlotID,
        input: StrengthRoutineBuilderInput,
        userLockedSlots: Set<StrengthRoutineSlotID>
    ) -> StrengthRoutineExercise {
        var reasons: [StrengthRoutineSelectionReason] = []
        if userLockedSlots.contains(slotID) {
            reasons.append(.lockedByUser)
        }
        if input.includedCatalogIDs.contains(candidate.catalogID) {
            reasons.append(.includedByUser)
        }
        reasons.append(structuralReason(candidate: candidate, slot: slotID.kind))
        if input.preferFamiliar, candidate.familiarity.sessionCount > 0 {
            reasons.append(.familiarExercise)
        }
        return StrengthRoutineExercise(
            candidate: candidate,
            prescription: StrengthRoutinePolicy.prescription(for: candidate, goal: input.goal),
            selectionReasons: reasons
        )
    }

    private static func structuralReason(
        candidate: StrengthRoutineCandidate,
        slot: StrengthRoutineSlotKind
    ) -> StrengthRoutineSelectionReason {
        switch slot {
        case let .emphasis(group):
            candidate.group == group ? .emphasis(group) : .muscleCoverage(candidate.group)
        default:
            if let pattern = candidate.pattern {
                .movementCoverage(pattern, candidate.direction)
            } else {
                .muscleCoverage(candidate.group)
            }
        }
    }

    private static func appendRedundancyGap(
        candidate: StrengthRoutineCandidate,
        slotID: StrengthRoutineSlotID,
        state: inout BuildState
    ) {
        if state.assignments.values.contains(where: { $0.catalogID == candidate.catalogID }) {
            state.gaps.append(.init(
                severity: .advisory,
                kind: .repeatedExercise(candidate.catalogID)
            ))
        }
        let repeatsFamilyInDay = state.assignments.contains { assignment in
            assignment.key.weekday == slotID.weekday
                && assignment.value.familyID == candidate.familyID
        }
        if repeatsFamilyInDay {
            state.gaps.append(.init(
                severity: .advisory,
                kind: .repeatedFamily(candidate.familyID, slotID.weekday)
            ))
        }
    }

    private static func appendCoverageGaps(
        input: StrengthRoutineBuilderInput,
        assignments: [StrengthRoutineSlotID: StrengthRoutineCandidate],
        state: inout BuildState
    ) {
        let selected = Array(assignments.values)
        let required: [(MovementPattern, PushPullDirection?)] = [
            (.push, .horizontal),
            (.pull, .horizontal),
            (.push, .vertical),
            (.pull, .vertical),
            (.squat, nil),
            (.hinge, nil),
        ]
        for requirement in required where !covers(requirement, candidates: selected) {
            state.gaps.append(.init(
                severity: .advisory,
                kind: .missingMovement(requirement.0, requirement.1)
            ))
        }
        for region in StrengthRoutineBodyRegion.allCases
            where !selected.contains(where: { region.contains($0.group) })
        {
            state.gaps.append(.init(severity: .advisory, kind: .missingBodyRegion(region)))
        }
        if let emphasis = input.emphasis,
           !selected.contains(where: { $0.group == emphasis })
        {
            state.gaps.append(.init(severity: .advisory, kind: .missingEmphasis(emphasis)))
        }
    }

    private static func covers(
        _ requirement: (MovementPattern, PushPullDirection?),
        candidates: [StrengthRoutineCandidate]
    ) -> Bool {
        candidates.contains { candidate in
            candidate.pattern == requirement.0
                && (requirement.1 == nil || candidate.direction == requirement.1)
        }
    }
}
