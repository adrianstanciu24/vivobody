//
//  CatalogEditorFields.swift
//  vivobody
//
//  Reusable segmented, plane, and choice controls for catalog authorship.
//

import SwiftUI
import VivoKit

struct CatalogSegmentedField<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    @Namespace private var selectionThumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    optionButton(option)
                }
            }
            .padding(2)
            .background { Capsule().fill(Surface.cardTintBright) }
            .overlay { Capsule().stroke(Surface.edge, lineWidth: 1) }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85),
            value: selection
        )
    }

    private func optionButton(_ option: Option) -> some View {
        let selected = option == selection
        return Button {
            guard !selected else { return }
            selection = option
        } label: {
            HStack(spacing: Space.xs) {
                if selected, differentiateWithoutColor {
                    Image(systemName: "checkmark").accessibilityHidden(true)
                }
                Text(label(option))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .font(Typography.body)
            .fontWeight(selected ? .semibold : .regular)
            .foregroundStyle(selected ? Tint.onAccent : Ink.primary)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
            .background {
                if selected {
                    Capsule()
                        .fill(Tint.inProgress)
                        .matchedGeometryEffect(id: "selection", in: selectionThumb)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(option))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
                    let selected = selection.contains(plane)
                    Button {
                        var updated = Set(selection)
                        if selected {
                            guard updated.count > 1 else {
                                Haptics.rigid()
                                return
                            }
                            updated.remove(plane)
                        } else {
                            updated.insert(plane)
                        }
                        Haptics.selection()
                        selection = MovementPlane.allCases.filter(updated.contains)
                    } label: {
                        Text(plane.displayName)
                            .font(Typography.body)
                            .fontWeight(selected ? .semibold : .regular)
                            .foregroundStyle(selected ? Tint.onAccent : Ink.primary)
                            .frame(maxWidth: .infinity, minHeight: Space.tapMin)
                            .background(
                                Capsule().fill(selected ? Tint.inProgress : Surface.cardTintBright)
                            )
                            .overlay(Capsule().stroke(Surface.edge, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(plane.displayName)
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

struct CatalogChoiceSheet<Option: Hashable>: View {
    let title: String
    let options: [Option]
    let label: (Option) -> String
    let isSelected: (Option) -> Bool
    let onSelect: (Option) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        choiceRow(option)
                        if option != options.last {
                            SectionDivider().padding(.horizontal, Space.lg)
                        }
                    }
                }
                .contentCard()
                .padding(.vertical, Space.md)
            }
            .contentMargins(.horizontal, Space.gutter, for: .scrollContent)
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func choiceRow(_ option: Option) -> some View {
        let selected = isSelected(option)
        return Button {
            Haptics.selection()
            onSelect(option)
            dismiss()
        } label: {
            HStack(spacing: Space.md) {
                Text(label(option))
                    .font(Typography.body)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Space.sm)
                if selected {
                    Image(systemName: "checkmark")
                        .font(Typography.headline)
                        .foregroundStyle(Tint.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.lg)
            .frame(minHeight: Space.rowMin)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(option))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
