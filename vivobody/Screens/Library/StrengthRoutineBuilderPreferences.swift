//
//  StrengthRoutineBuilderPreferences.swift
//  vivobody
//
//  Optional compact preferences for routine planning. Defaults remain useful;
//  emphasis, familiarity, and explicit exercise choices stay disclosed until
//  the user asks for more control.
//

import SwiftUI
import VivoKit

struct StrengthRoutineBuilderPreferences: View {
    @Binding var emphasis: MuscleGroup?
    @Binding var preferFamiliar: Bool

    let includedItems: [ExerciseCatalogItem]
    let excludedItems: [ExerciseCatalogItem]
    let onAddIncluded: () -> Void
    let onRemoveIncluded: (String) -> Void
    let onAddExcluded: () -> Void
    let onRemoveExcluded: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            emphasisSection

            Toggle("Prefer familiar exercises", isOn: $preferFamiliar)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .tint(Tint.primary)
                .frame(minHeight: Space.tapMin)

            exercisePreferenceSection(
                title: "Include",
                items: includedItems,
                addLabel: "Include exercise",
                onAdd: onAddIncluded,
                onRemove: onRemoveIncluded
            )

            exercisePreferenceSection(
                title: "Avoid",
                items: excludedItems,
                addLabel: "Add exercise to avoid",
                onAdd: onAddExcluded,
                onRemove: onRemoveExcluded
            )
        }
    }

    private var emphasisSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Emphasis")
                .sectionLabelStyle(Opacity.medium)

            ScrollView(.horizontal) {
                HStack(spacing: Space.sm) {
                    StrengthRoutineChoiceChip(
                        label: "None",
                        isSelected: emphasis == nil,
                        action: { emphasis = nil }
                    )
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        StrengthRoutineChoiceChip(
                            label: group.displayName,
                            isSelected: emphasis == group,
                            action: { emphasis = group }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func exercisePreferenceSection(
        title: String,
        items: [ExerciseCatalogItem],
        addLabel: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title)
                .sectionLabelStyle(Opacity.medium)

            if !items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { SectionDivider() }
                        HStack(spacing: Space.md) {
                            Text(item.name)
                                .font(Typography.body)
                                .foregroundStyle(Ink.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button {
                                guard let catalogID = item.catalogID else { return }
                                onRemove(catalogID)
                                Haptics.soft()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(Typography.caption)
                                    .foregroundStyle(Ink.tertiary)
                                    .frame(width: Space.tapMin, height: Space.tapMin)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item.name)")
                        }
                        .padding(.leading, Space.lg)
                        .padding(.trailing, Space.sm)
                    }
                }
                .contentCard()
            }

            Button(action: onAdd) {
                Label(addLabel, systemImage: "plus")
                    .font(Typography.sectionHeading)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, minHeight: Space.tapMin, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
    #Preview("Routine preferences") {
        @Previewable @State var emphasis: MuscleGroup? = .back
        @Previewable @State var preferFamiliar = true

        StrengthRoutineBuilderPreferences(
            emphasis: $emphasis,
            preferFamiliar: $preferFamiliar,
            includedItems: [],
            excludedItems: [],
            onAddIncluded: {},
            onRemoveIncluded: { _ in },
            onAddExcluded: {},
            onRemoveExcluded: { _ in }
        )
        .padding(Space.gutter)
        .screenBackground()
        .preferredColorScheme(.dark)
    }
#endif
