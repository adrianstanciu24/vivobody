//
//  CustomExerciseClassificationSection.swift
//  vivobody
//
//  Classification section for custom-exercise modality, mechanic, training
//  role, compound pattern, direction, movement planes, and laterality.
//

import SwiftUI
import VivoKit

struct CustomExerciseClassificationSection: View {
    @Binding var draft: CatalogDraft
    let validation: CatalogDraftValidation
    let showsValidationErrors: Bool
    let onPresentPicker: (CatalogPicker) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Classification")
            modalityField
            mechanicField
            trainingRoleField

            if draft.mechanic == .compound {
                patternField
                    .id(CatalogDraftValidation.Anchor.movementPattern)
                    .transition(.move(edge: .top).combined(with: .opacity))

                if draft.requiresDirection {
                    directionField
                        .id(CatalogDraftValidation.Anchor.direction)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }

            CatalogPlaneField(
                title: "Plane of movement",
                selection: $draft.planes
            )
            lateralityField
        }
    }

    private var modalityField: some View {
        CustomExercisePickerRow(title: "Exercise type", value: draft.modality.displayName) {
            onPresentPicker(.modality)
        }
    }

    private var mechanicField: some View {
        CatalogSegmentedField(
            title: "Mechanic",
            selection: Binding(
                get: { draft.mechanic },
                set: { mechanic in
                    applyAnimatedSelection {
                        draft.selectMechanic(mechanic)
                    }
                }
            ),
            options: Mechanic.allCases,
            label: { $0.displayName }
        )
    }

    private var trainingRoleField: some View {
        CustomExercisePickerRow(
            title: "Training role",
            value: draft.trainingRole.displayName
        ) {
            onPresentPicker(.trainingRole)
        }
    }

    private var patternField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            CustomExercisePickerRow(
                title: "Movement pattern",
                value: draft.pattern?.displayName ?? "Choose"
            ) {
                onPresentPicker(.movementPattern)
            }

            if showsValidationErrors, !validation.hasValidMovementPattern {
                CustomExerciseValidationMessage(
                    message: "Choose a compound movement pattern."
                )
            }
        }
    }

    private var directionField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            CatalogSegmentedField(
                title: "Direction",
                selection: Binding(
                    get: { draft.direction ?? .horizontal },
                    set: { direction in
                        Haptics.selection()
                        draft.direction = direction
                    }
                ),
                options: PushPullDirection.allCases,
                label: { $0.displayName }
            )

            if showsValidationErrors, !validation.hasValidDirection {
                CustomExerciseValidationMessage(
                    message: "Choose a push or pull direction."
                )
            }
        }
    }

    private var lateralityField: some View {
        CatalogSegmentedField(
            title: "Sides",
            selection: Binding(
                get: { draft.laterality },
                set: { laterality in
                    Haptics.selection()
                    draft.laterality = laterality
                }
            ),
            options: Laterality.allCases,
            label: { $0.displayName }
        )
    }

    private func applyAnimatedSelection(_ changes: () -> Void) {
        Haptics.selection()
        if reduceMotion {
            changes()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                changes()
            }
        }
    }
}
