//
//  CatalogEditorFields.swift
//  vivobody
//
//  Titled segmented and plane fields for catalog authorship. Segmented
//  fields use the shared SegmentedPicker; plane chips are native button
//  toggles.
//

import SwiftUI
import VivoKit

struct CatalogSegmentedField<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)
            SegmentedPicker(
                selection: $selection,
                options: options,
                font: Typography.body,
                // Callers' selection setters already play feedback.
                feedback: { _ in },
                label: label
            )
        }
    }
}

struct CatalogPlaneField: View {
    let title: String
    @Binding var selection: [MovementPlane]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)
            HStack(spacing: Space.sm) {
                ForEach(MovementPlane.allCases, id: \.self) { plane in
                    planeToggle(plane)
                }
            }
        }
    }

    private func planeToggle(_ plane: MovementPlane) -> some View {
        let selected = selection.contains(plane)
        return Toggle(isOn: planeBinding(plane)) {
            Text(plane.displayName)
                .font(Typography.body)
                .fontWeight(selected ? .semibold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
        }
        .toggleStyle(.button)
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .tint(Tint.inProgress)
        .frame(minHeight: Space.tapMin)
        .accessibilityLabel(plane.displayName)
    }

    /// At least one plane must stay selected; turning off the last one is
    /// refused with a rigid haptic, and the toggle stays on.
    private func planeBinding(_ plane: MovementPlane) -> Binding<Bool> {
        Binding(
            get: { selection.contains(plane) },
            set: { isOn in
                var updated = Set(selection)
                if isOn {
                    updated.insert(plane)
                } else {
                    guard updated.count > 1 else {
                        Haptics.rigid()
                        return
                    }
                    updated.remove(plane)
                }
                Haptics.selection()
                selection = MovementPlane.allCases.filter(updated.contains)
            }
        )
    }
}
