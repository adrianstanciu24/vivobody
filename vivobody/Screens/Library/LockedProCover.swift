//
//  LockedProCover.swift
//  vivobody
//
//  The shared frozen-blur Pro cover for Exercise Detail sections: the
//  real card frozen beneath a blur, the whole area one button that
//  opens the screen's local paywall sheet. Accessibility sees only the
//  locked section, never the numbers beneath it. Used by the
//  load-cadence and this-week sections; the Insights tab keeps its own
//  larger locked preview, and the progress chart its inline variant.
//

import SwiftUI
import VivoKit

struct LockedProCover<Content: View>: View {
    /// The section's display name, used for the locked accessibility
    /// label ("This week, locked").
    let title: String
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency)
    private var reduceTransparency

    var body: some View {
        Button(action: action) {
            content()
                .blur(radius: reduceTransparency ? 0 : 8)
                .opacity(reduceTransparency ? 0 : 0.90)
                .accessibilityHidden(true)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(title), locked")
        .accessibilityHint("Unlocks with Vivobody Pro")
    }
}
