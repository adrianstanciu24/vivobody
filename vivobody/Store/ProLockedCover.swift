//
//  ProLockedCover.swift
//  vivobody
//
//  The free version's locked preview for Exercise Detail sections: the
//  real section frozen beneath the same blur as the Insights page, the
//  whole area one button. Accessibility sees only the locked section,
//  never the numbers beneath it. The floating unlock pill, shared with
//  the Insights page, carries the purchase request.
//

import SwiftUI
import VivoKit

extension View {
    /// Freezes this view beneath the Pro blur while `isLocked`. A nil
    /// `onUnlock` keeps the section inert, for hosts that must not offer
    /// a purchase, such as the live-workout add flow.
    @ViewBuilder
    func proLocked(
        _ isLocked: Bool,
        title: String,
        onUnlock: (() -> Void)? = nil
    ) -> some View {
        if isLocked {
            ProLockedCover(title: title, onUnlock: onUnlock) { self }
        } else {
            self
        }
    }
}

struct ProLockedCover<Content: View>: View {
    let title: String
    let onUnlock: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if let onUnlock {
            Button(action: onUnlock) {
                frozen.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(title), locked")
            .accessibilityHint("Unlocks with Vivobody Pro")
            .accessibilityIdentifier("proLockedCover")
        } else {
            frozen
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title), locked")
                .accessibilityIdentifier("proLockedCover")
        }
    }

    private var frozen: some View {
        content()
            .blur(radius: reduceTransparency ? 0 : 8)
            .opacity(reduceTransparency ? 0 : 0.90)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The floating "Unlock Vivobody Pro" pill shown below a locked screen.
struct ProUnlockButton: View {
    let price: String?
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.md) {
                Text("Unlock Vivobody Pro")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let price {
                    Text("· \(price)")
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .font(compact ? Typography.headline : Typography.title)
            .foregroundStyle(Tint.onAccent)
            .frame(minHeight: compact ? Space.tapMin : Space.rowMin)
            .padding(.horizontal, compact ? Space.xl : Space.xxl)
            .coloredGlassControl(cornerRadius: Radius.pill, fill: Tint.primary)
            .softElevation(radius: 14, y: 7, opacity: 0.42)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("proUnlockButton")
        .accessibilityLabel(price.map { "Unlock Vivobody Pro, \($0)" } ?? "Unlock Vivobody Pro")
        .accessibilityHint("Opens the Vivobody Pro purchase sheet")
    }
}
