//
//  CustomExerciseBasicsSection.swift
//  vivobody
//
//  Basics section for custom-exercise authorship: name, browse group,
//  explicit muscle roles, and equipment, with validation-ready anchors.
//

import SwiftUI
import VivoKit

struct CustomExerciseBasicsSection: View {
    @Binding var draft: CatalogDraft
    let validation: CatalogDraftValidation
    let showsValidationErrors: Bool
    let nameFieldFocus: FocusState<Bool>.Binding
    let onPresentPicker: (CatalogPicker) -> Void
    let onPresentMuscleEditor: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Basics")
            nameField
                .id(CatalogDraftValidation.Anchor.name)
            muscleGroupField
            muscleInvolvementField
                .id(CatalogDraftValidation.Anchor.muscles)
            equipmentField
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Name")
                .sectionLabelStyle(Opacity.medium)

            TextField("", text: $draft.name, prompt: Text("e.g. Bulgarian Split Squat")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
                .focused(nameFieldFocus)
                .submitLabel(.done)
                .padding(.vertical, Space.sm)
                .accessibilityLabel("Name")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)

            if showsValidationErrors, validation.isNameEmpty {
                CustomExerciseValidationMessage(message: "Enter an exercise name.")
            }
        }
    }

    private var muscleGroupField: some View {
        CustomExercisePickerRow(title: "Muscle group", value: draft.group.displayName) {
            onPresentPicker(.muscleGroup)
        }
    }

    private var muscleInvolvementField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            CustomExercisePickerRow(
                title: "Muscles worked",
                subtitle: draft.muscleSummary
            ) {
                onPresentMuscleEditor()
            }

            if showsValidationErrors, !validation.hasValidMuscleRoles {
                CustomExerciseValidationMessage(
                    message: "Choose a Primary muscle in the selected muscle group."
                )
            }
        }
    }

    private var equipmentField: some View {
        CustomExercisePickerRow(title: "Equipment", value: draft.equipment.displayName) {
            onPresentPicker(.equipment)
        }
    }
}
