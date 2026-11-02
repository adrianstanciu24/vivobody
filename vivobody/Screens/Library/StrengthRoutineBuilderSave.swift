//
//  StrengthRoutineBuilderSave.swift
//  vivobody
//
//  Atomic persistence bridge from an immutable generated routine to editable
//  workout templates. Every catalog reference and the free template limit are
//  resolved before insertion; external projections publish only after Save.
//

import SwiftData
import SwiftUI

extension StrengthRoutineBuilderScreen {
    func savePlan() {
        guard let plan, !plan.days.isEmpty, !plan.hasBlockingGaps else { return }
        let existingCount: Int
        do {
            existingCount = try modelContext.fetchCount(FetchDescriptor<WorkoutTemplate>())
        } catch {
            saveError = SaveErrorBox(StrengthRoutineSaveFailure.storeUnavailable)
            return
        }

        let templates: [WorkoutTemplate]
        do {
            templates = try StrengthRoutineTemplateBatch.materialize(
                plan: plan,
                catalogItems: catalogItems,
                availableEquipment: availableEquipment,
                startingSortOrder: existingCount
            )
        } catch {
            saveError = SaveErrorBox(error)
            return
        }

        // A free user saves the whole week or none of it.
        guard ProGate.canCreateTemplates(
            existingCount: existingCount,
            adding: templates.count,
            status: appState.pro.status
        ) else {
            appState.pro.requestUnlock(context: .templateLimit)
            return
        }

        do {
            try StrengthRoutineTemplateBatch.insertAndSave(
                templates,
                in: modelContext
            )
        } catch {
            saveError = SaveErrorBox(error)
            return
        }

        WidgetSnapshotWriter.writeAll(in: modelContext)
        templates.forEach(SpotlightIndexer.index)
        Haptics.soft()
        dismiss()
    }
}
