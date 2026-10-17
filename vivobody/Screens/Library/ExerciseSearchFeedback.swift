//
//  ExerciseSearchFeedback.swift
//  vivobody
//
//  Shared search feedback for Library and exercise pickers. The note
//  above the results names a typo-corrected query, or says the results
//  are closest matches, so neither change is silent. The hidden-matches card says when the selected filter
//  hides every match and offers one action that selects All. It is a
//  compact card below the filters, not a centered empty state, because
//  at large text sizes the keyboard would cover a centered button.
//

import SwiftUI
import VivoKit

struct ExerciseSearchNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(Ink.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xs)
            .padding(.bottom, Space.sm)
            .accessibilityIdentifier("exerciseSearchCorrection")
    }
}

struct ExerciseSearchHiddenMatchesState: View {
    let filter: ExerciseCatalogFilter
    let matchCount: Int
    let onShowAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("No matches in \(filter.displayName)")
                .font(Typography.sectionHeading)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Haptics.selection()
                onShowAll()
            } label: {
                Text(matchCount == 1 ? "Show 1 Match in All" : "Show \(matchCount) Matches in All")
            }
            .primaryButtonStyle(compact: true)
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentCard()
    }
}
