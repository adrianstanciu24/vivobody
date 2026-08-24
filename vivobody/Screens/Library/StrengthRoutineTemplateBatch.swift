//
//  StrengthRoutineTemplateBatch.swift
//  vivobody
//
//  Testable persistence boundary for generated strength routines. It
//  revalidates catalog identities, materializes ordinary workout templates,
//  and commits the complete batch through the shared rollback helper.
//

import Foundation
import SwiftData

@MainActor
enum StrengthRoutineTemplateBatch {
    static func materialize(
        plan: StrengthRoutinePlan,
        catalogItems: [ExerciseCatalogItem],
        availableEquipment: Set<Equipment>,
        startingSortOrder: Int
    ) throws -> [WorkoutTemplate] {
        var itemsByID: [String: ExerciseCatalogItem] = [:]
        var duplicateIDs: Set<String> = []
        for item in catalogItems {
            guard let catalogID = item.catalogID else { continue }
            if itemsByID[catalogID] == nil {
                itemsByID[catalogID] = item
            } else {
                duplicateIDs.insert(catalogID)
            }
        }

        return try plan.days.enumerated().map { dayIndex, day in
            let resolvedExercises = try day.slots.map { slot in
                guard
                    let exercise = slot.exercise,
                    !duplicateIDs.contains(exercise.catalogID),
                    let item = itemsByID[exercise.catalogID],
                    !item.isUserCreated,
                    item.modality.supportsHardSetAnalytics,
                    StrengthRoutinePolicy.allowsEquipment(
                        item.equipment,
                        selectedEquipment: availableEquipment
                    ),
                    CatalogData.record(forCatalogID: exercise.catalogID) != nil
                else {
                    throw StrengthRoutineSaveFailure.catalogChanged
                }
                return ResolvedStrengthRoutineExercise(
                    plan: exercise,
                    catalogItem: item
                )
            }
            return makeTemplate(
                day: day,
                exercises: resolvedExercises,
                sortOrder: startingSortOrder + dayIndex
            )
        }
    }

    static func insertAndSave(
        _ templates: [WorkoutTemplate],
        in context: ModelContext
    ) throws {
        templates.forEach(context.insert)
        try context.saveOrRollback()
    }

    private static func makeTemplate(
        day: StrengthRoutineDay,
        exercises: [ResolvedStrengthRoutineExercise],
        sortOrder: Int
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: day.title, sortOrder: sortOrder)
        template.scheduledWeekdays = [day.weekday.calendarValue]

        for (index, resolvedExercise) in exercises.enumerated() {
            var draft = ExerciseDraft(from: resolvedExercise.catalogItem)
            let prescription = resolvedExercise.plan.prescription
            draft.plannedSets = prescription.sets
            // Catalog defaults seed manual pickers; the builder has no basis
            // for prescribing load, so generated templates start unloaded.
            draft.plannedWeight = 0
            if let targetReps = prescription.targetReps {
                draft.plannedReps = targetReps
            }
            if let targetDuration = prescription.targetDurationSeconds {
                draft.plannedDuration = TimeInterval(targetDuration)
            }
            template.exercises.append(
                draft.makeTemplateExercise(sortOrder: index)
            )
        }
        return template
    }
}

private struct ResolvedStrengthRoutineExercise {
    let plan: StrengthRoutineExercise
    let catalogItem: ExerciseCatalogItem
}

enum StrengthRoutineSaveFailure: LocalizedError {
    case catalogChanged
    case storeUnavailable

    var errorDescription: String? {
        switch self {
        case .catalogChanged:
            "An exercise changed while this routine was open. Rebuild the draft and try again."
        case .storeUnavailable:
            "Vivobody couldn't check your saved templates. Try again."
        }
    }
}
