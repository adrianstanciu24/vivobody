//
//  CustomExerciseEditorControls.swift
//  vivobody
//
//  Feature-local row and validation primitives shared by the focused custom
//  exercise editor sections so their interaction and accessibility semantics
//  stay identical. Choice rows open a native menu picker; picker rows open
//  a dedicated editor sheet.
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

/// A card row whose tap opens a native menu of single choices. The system
/// draws the options and the checkmark; the row keeps the card look and
/// speaks its title and current value.
struct CustomExerciseChoiceRow<Option: Hashable>: View {
    let title: String
    let value: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        Menu {
            Picker(title, selection: pickedSelection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            KitRow(title: title) {
                HStack(spacing: Space.sm) {
                    Text(value)
                        .font(Typography.body)
                        .foregroundStyle(Ink.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(Typography.caption)
                        .foregroundStyle(Ink.quaternary)
                }
            }
        }
        .menuOrder(.fixed)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
        .accessibilityHint("Shows choices")
    }

    private var pickedSelection: Binding<Option> {
        Binding(
            get: { selection },
            set: { option in
                Haptics.selection()
                selection = option
            }
        )
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
        @State private var modality: ExerciseModality = .dynamicStrength

        var body: some View {
            VStack(alignment: .leading, spacing: Space.lg) {
                CustomExerciseChoiceRow(
                    title: "Exercise type",
                    value: modality.displayName,
                    selection: $modality,
                    options: ExerciseModality.customExerciseChoices,
                    label: { $0.displayName }
                )
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
