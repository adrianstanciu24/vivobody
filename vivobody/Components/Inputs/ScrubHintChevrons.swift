//
//  ScrubHintChevrons.swift
//  vivobody
//
//  Reduce-Motion-aware visual affordance for BareScrubber's first use.
//

import SwiftUI
import VivoKit

struct ScrubHintChevrons: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let travel: CGFloat = 5
    private static let cycle: Animation = .easeInOut(duration: 1.1)

    var body: some View {
        PhaseAnimator(reduceMotion ? [false] : [false, true]) { phase in
            VStack(spacing: 2) {
                Image(systemName: "chevron.up")
                    .offset(y: reduceMotion ? 0 : (phase ? 0 : -Self.travel))
                    .opacity(reduceMotion ? 1.0 : (phase ? Opacity.faint : 1.0))

                Image(systemName: "chevron.down")
                    .offset(y: reduceMotion ? 0 : (phase ? Self.travel : 0))
                    .opacity(reduceMotion ? 1.0 : (phase ? 1.0 : Opacity.faint))
            }
        } animation: { _ in
            reduceMotion ? nil : Self.cycle
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Ink.tertiary)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
