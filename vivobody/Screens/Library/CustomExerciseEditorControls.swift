//
//  CustomExerciseEditorControls.swift
//  vivobody
//
//  Feature-local row and validation primitives shared by the focused custom
//  exercise editor sections so their interaction and accessibility semantics
//  stay identical.
//

import SwiftUI
import VivoKit

struct CustomExercisePickerRow: View {
    let title: String
    let subtitle: String?
    let value: String?
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            KitRow(title: title, subtitle: subtitle) {
                HStack(spacing: Space.sm) {
                    if let value {
                        Text(value)
                            .font(Typography.body)
                            .foregroundStyle(Ink.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Image(systemName: "chevron.right")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? subtitle ?? "Not set")
        .accessibilityHint("Opens choices")
    }
}

struct CustomExerciseValidationMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(Typography.caption)
            .foregroundStyle(Tint.danger)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#if DEBUG
    private struct CustomExerciseEditorControlsGallery: View {
        var body: some View {
            VStack(alignment: .leading, spacing: Space.lg) {
                CustomExercisePickerRow(
                    title: "Exercise type",
                    value: "Strength · Reps"
                ) {}
                CustomExercisePickerRow(
                    title: "Muscles worked",
                    subtitle: "Chest · Primary"
                ) {}
                CustomExerciseValidationMessage(
                    message: "Choose a Primary muscle in the selected muscle group."
                )
            }
            .padding(Space.gutter)
            .screenBackground()
        }
    }

    #Preview("Custom exercise editor controls") {
        CustomExerciseEditorControlsGallery()
    }
#endif
