//
//  CustomExerciseSearchSection.swift
//  vivobody
//
//  Search-alias section for custom exercises, preserving free-form typing and
//  showing namespace validation only after the user attempts to save.
//

import SwiftUI
import VivoKit

struct CustomExerciseSearchSection: View {
    @Binding var draft: CatalogDraft
    let validation: CatalogDraftValidation
    let showsValidationErrors: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            SectionHeader(title: "Search")
            aliasesField
                .id(CatalogDraftValidation.Anchor.aliases)
        }
    }

    private var aliasesField: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Aliases")
                    .sectionLabelStyle(Opacity.medium)
                Spacer()
                Text("comma-separated")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.quaternary)
            }

            TextField("", text: $draft.aliasesInput, prompt: Text("e.g. BP, Flat Bench")
                .foregroundStyle(Ink.quaternary))
                .font(Typography.body)
                .foregroundStyle(Ink.primary)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .padding(.vertical, Space.sm)
                .accessibilityLabel("Aliases")

            Rectangle()
                .fill(Surface.edge)
                .frame(height: 1)
                .accessibilityHidden(true)

            if showsValidationErrors,
               !validation.isNameEmpty,
               !validation.hasUniqueSearchTerms
            {
                CustomExerciseValidationMessage(
                    message: "Name and aliases must be unique across the exercise catalog."
                )
            }
        }
    }
}
