//
//  StrengthRoutineBuilderInteractions.swift
//  vivobody
//
//  Screen-state translation for the strength routine builder. This file joins
//  authored catalog/history signals to the pure planner and keeps selection,
//  lock, swap, and regeneration behavior out of the SwiftUI layout.
//

import SwiftUI

extension StrengthRoutineBuilderScreen {
    func toggleWeekday(_ weekday: StrengthRoutineWeekday) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
    }

    func toggleEquipment(_ equipment: Equipment) {
        if availableEquipment.contains(equipment) {
            availableEquipment.remove(equipment)
        } else {
            availableEquipment.insert(equipment)
        }
    }

    func equipmentIdentifier(_ equipment: Equipment) -> String {
        let suffix = equipment.displayName.replacingOccurrences(of: " ", with: "")
        return "strengthRoutineEquipment\(suffix)"
    }

    func buildRoutine() {
        guard (2 ... 4).contains(weekdays.count) else {
            return
        }
        let nextPlan = StrengthRoutineBuilder.build(
            input: builderInput,
            candidates: candidates
        )
        selectedDayValue = nextPlan.days.first?.weekday.rawValue
            ?? weekdayChoices.first(where: weekdays.contains)?.rawValue
            ?? StrengthRoutineWeekday.monday.rawValue
        plan = nextPlan
        showsGapDetails = nextPlan.hasBlockingGaps
        Haptics.soft()
    }

    func regenerateUnlocked() {
        guard var updatedPlan = plan else { return }
        let unlocked = updatedPlan.days
            .flatMap(\.slots)
            .filter { $0.exercise != nil && lockedSelections[$0.id] == nil }
            .map(\.id)

        for slotID in unlocked {
            updatedPlan = StrengthRoutineBuilder.replacing(
                slotID: slotID,
                in: updatedPlan,
                input: builderInput,
                candidates: candidates
            )
        }
        plan = updatedPlan
        showsGapDetails = updatedPlan.hasBlockingGaps
        Haptics.soft()
    }

    func toggleLock(_ slot: StrengthRoutineSlot) {
        if lockedSelections[slot.id] != nil {
            lockedSelections.removeValue(forKey: slot.id)
        } else if let catalogID = slot.exercise?.catalogID {
            lockedSelections[slot.id] = catalogID
        }
        if plan != nil {
            self.plan = StrengthRoutineBuilder.build(
                input: builderInput,
                candidates: candidates
            )
            showsGapDetails = self.plan?.hasBlockingGaps ?? false
        }
        Haptics.selection()
    }

    func pickerPurpose(
        for target: StrengthRoutinePickerTarget
    ) -> ExercisePickerPurpose {
        let excluded = pickerExcludedItemIDs(for: target)
        switch target {
        case .include:
            return .routineInclude(
                excludedIDs: excluded,
                equipment: availableEquipment
            )
        case .avoid:
            return .routineAvoid(
                excludedIDs: excluded,
                equipment: availableEquipment
            )
        case let .swap(slotID):
            let compatibleCatalogIDs = Set(candidates.compactMap { candidate in
                StrengthRoutineBuilder.isCompatible(
                    candidate: candidate,
                    with: slotID.kind,
                    goal: goal
                ) ? candidate.catalogID : nil
            })
            return .routineSwap(
                excludedIDs: excluded,
                equipment: availableEquipment,
                compatibleCatalogIDs: compatibleCatalogIDs
            )
        }
    }

    func applyPickedExercise(
        _ item: ExerciseCatalogItem,
        to target: StrengthRoutinePickerTarget
    ) {
        guard let catalogID = item.catalogID else { return }
        switch target {
        case .include:
            excludedCatalogIDs.remove(catalogID)
            includedCatalogIDs.insert(catalogID)
        case .avoid:
            includedCatalogIDs.remove(catalogID)
            excludedCatalogIDs.insert(catalogID)
        case let .swap(slotID):
            guard
                let candidate = candidates.first(where: { $0.catalogID == catalogID }),
                StrengthRoutineBuilder.isCompatible(
                    candidate: candidate,
                    with: slotID.kind,
                    goal: goal
                )
            else {
                Haptics.caution()
                return
            }
            lockedSelections[slotID] = catalogID
            plan = StrengthRoutineBuilder.build(
                input: builderInput,
                candidates: candidates
            )
            showsGapDetails = plan?.hasBlockingGaps ?? false
        }
    }

    func preferenceItems(
        matching catalogIDs: Set<String>
    ) -> [ExerciseCatalogItem] {
        catalogItems
            .filter { item in
                guard let catalogID = item.catalogID else { return false }
                return catalogIDs.contains(catalogID)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func dayChoices(for plan: StrengthRoutinePlan) -> [StrengthRoutineDayChoice] {
        plan.days.map { day in
            StrengthRoutineDayChoice(
                id: day.weekday.rawValue,
                shortLabel: day.weekday.shortName,
                fullLabel: day.weekday.fullName,
                detail: "\(day.slots.compactMap(\.exercise).count) ex"
            )
        }
    }

    func selectedDay(in plan: StrengthRoutinePlan) -> StrengthRoutineDay? {
        plan.days.first { $0.weekday.rawValue == selectedDayValue }
            ?? plan.days.first
    }

    func displayedGapMessages(in plan: StrengthRoutinePlan) -> [String] {
        let relevant = plan.hasBlockingGaps
            ? plan.gaps.filter { $0.severity == .blocking }
            : plan.gaps
        var seen: Set<String> = []
        return relevant.map(\.message).filter { seen.insert($0).inserted }
    }

    func exerciseDisplay(
        _ exercise: StrengthRoutineExercise,
        in slot: StrengthRoutineSlot,
        day: StrengthRoutineDay,
        position: Int,
        count: Int
    ) -> StrengthRoutineExerciseDisplay {
        let isIncluded = includedCatalogIDs.contains(exercise.catalogID)
        return StrengthRoutineExerciseDisplay(
            id: slotIdentifier(slot.id),
            day: "\(day.weekday.fullName), \(day.title)",
            position: position,
            count: count,
            name: exercise.name,
            prescription: prescriptionText(exercise.prescription),
            reason: isIncluded
                ? "Included by you"
                : exercise.selectionReasons.first?.summary ?? slot.kind.title,
            isIncluded: isIncluded,
            isLocked: lockedSelections[slot.id] != nil
        )
    }

    func loadFamiliarity() {
        guard let summaries = sessionAnalytics?.resolvedExerciseHistory(
            in: modelContext
        ) else { return }

        familiarityByCatalogID = Dictionary(uniqueKeysWithValues: catalogItems.compactMap { item in
            guard
                let catalogID = item.catalogID,
                let summary = summaries[item.historyKey]
            else { return nil }
            return (
                catalogID,
                StrengthRoutineFamiliarity(
                    sessionCount: summary.sessionCount,
                    lastPerformedAt: summary.latestPerformanceDate
                )
            )
        })
    }

    private func pickerExcludedItemIDs(
        for target: StrengthRoutinePickerTarget
    ) -> Set<UUID> {
        let catalogIDs: Set<String> = switch target {
        case .include, .avoid:
            includedCatalogIDs.union(excludedCatalogIDs)
        case .swap:
            Set(plan?.exercises.map(\.catalogID) ?? [])
        }
        return Set(catalogItems.compactMap { item in
            guard let catalogID = item.catalogID, catalogIDs.contains(catalogID) else {
                return nil
            }
            return item.id
        })
    }

    private func prescriptionText(
        _ prescription: StrengthRoutinePrescription
    ) -> String {
        if let reps = prescription.targetReps {
            return "\(prescription.sets) × \(reps) reps"
        }
        if let seconds = prescription.targetDurationSeconds {
            return "\(prescription.sets) × \(seconds) sec"
        }
        return "\(prescription.sets) sets"
    }

    private func slotIdentifier(_ slotID: StrengthRoutineSlotID) -> String {
        let kind = slotID.kind.title.replacingOccurrences(of: " ", with: "")
        return "\(slotID.weekday.rawValue)-\(kind)-\(slotID.occurrence)"
    }
}
