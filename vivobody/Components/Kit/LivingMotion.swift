//
//  LivingMotion.swift
//  vivobody
//
//  Entrance + presence motion for the static tabs — the "instrument
//  powering on." Sections rise and fade into place with a short
//  staggered spring so a screen assembles itself the moment you arrive,
//  instead of blinking in fully formed. It reuses the same spring
//  vocabulary the active-workout card uses, so the tabs feel cut from
//  the same kinetic cloth. Honors Reduce Motion by showing content at
//  rest with no animation.
//

import SwiftUI

extension View {
    /// Settle this section into place on appear. `order` is its position
    /// from the top (0 = hero); each step adds a small delay so sections
    /// cascade in rather than arriving all at once.
    func settleIn(_ order: Int) -> some View {
        modifier(SettleInModifier(order: order))
    }
}

private struct SettleInModifier: ViewModifier {
    let order: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                guard !shown else { return }
                if reduceMotion {
                    shown = true
                    return
                }
                withAnimation(
                    .spring(response: 0.55, dampingFraction: 0.86)
                        .delay(Double(order) * 0.06)
                ) {
                    shown = true
                }
            }
    }
}
